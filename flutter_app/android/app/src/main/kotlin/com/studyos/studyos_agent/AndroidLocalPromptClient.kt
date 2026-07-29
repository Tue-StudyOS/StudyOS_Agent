package com.studyos.studyos_agent

import android.content.Context
import com.example.studyOS.offline.LiteRtLocalPromptClient
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.StreamingCallback
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit

class AndroidLocalPromptClient(context: Context) {
    private val appContext = context.applicationContext
    private val executor = Executors.newSingleThreadExecutor()
    private val liteRtClient = LiteRtLocalPromptClient()

    @Volatile
    private var activeNanoFuture: Future<*>? = null

    /** Best-effort cancel of the in-flight generation (Stop button). */
    fun cancel() {
        activeNanoFuture?.cancel(true)
        liteRtClient.cancel()
    }

    /**
     * Releases the LiteRT engine and its KV cache. Posted to the same single
     * worker so it serializes behind any in-flight generation rather than
     * blocking the caller (e.g. the main thread during onTrimMemory). The next
     * generate() call transparently rebuilds the engine.
     */
    fun close() {
        executor.execute { liteRtClient.close() }
    }

    /**
     * Generates a reply for [prompt]. Tool routing is owned entirely by the Dart
     * layer; this only produces text and streams tokens through [onDelta].
     *
     * [systemInstruction] is the stable system prompt: on the LiteRT path it is
     * installed once as the conversation's system instruction (reused across
     * turns); the stateless Gemini Nano path folds it into the prompt.
     */
    fun generate(
        prompt: String,
        systemInstruction: String,
        modelId: String,
        modelPath: String,
        backend: String,
        onDelta: (String) -> Unit,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit,
    ) {
        val deltaSink = onDelta
        executor.execute {
            try {
                if (modelPath.isNotBlank()) {
                    liteRtClient.setBackendPreference(backend)
                    val response = liteRtClient.generateStreaming(
                        modelPath,
                        prompt,
                        appContext.cacheDir.absolutePath,
                        systemInstruction,
                        object : LiteRtLocalPromptClient.StreamListener {
                            override fun onToken(token: String) {
                                deltaSink(token)
                            }
                        },
                    )
                    if (response.isBlank()) {
                        onError("LiteRT-LM returned an empty response.")
                    } else {
                        onSuccess(response)
                    }
                    return@execute
                }

                // Gemini Nano through ML Kit is stateless per call, so fold the
                // system instruction into the one-shot prompt.
                val nanoPrompt = if (systemInstruction.isBlank()) {
                    prompt
                } else {
                    "$systemInstruction\n\n$prompt"
                }
                val model = AndroidAiCoreModelCatalog.clientFor(modelId)
                when (val status = model.checkStatus().get(2, TimeUnit.SECONDS)) {
                    FeatureStatus.AVAILABLE -> {
                        val future = model.generateContent(
                            nanoPrompt,
                            StreamingCallback { text -> deltaSink(text) },
                        )
                        activeNanoFuture = future
                        val response = try {
                            future.get(NANO_GENERATION_TIMEOUT_SECONDS, TimeUnit.SECONDS)
                        } finally {
                            activeNanoFuture = null
                        }
                        val text = response.candidates.firstOrNull()?.text.orEmpty()
                        if (text.isBlank()) {
                            onError("Android Gemini Nano returned an empty response.")
                        } else {
                            onSuccess(text)
                        }
                    }
                    FeatureStatus.DOWNLOADABLE -> {
                        onError(
                            "Android Gemini Nano is supported but not downloaded on this device.",
                        )
                    }
                    FeatureStatus.DOWNLOADING -> {
                        onError("Android Gemini Nano is still downloading on this device.")
                    }
                    FeatureStatus.UNAVAILABLE -> {
                        onError("Android Gemini Nano Prompt API is unavailable on this device.")
                    }
                    else -> {
                        onError("Android Gemini Nano status is unsupported: $status.")
                    }
                }
            } catch (error: Throwable) {
                val provider = if (modelPath.isBlank()) {
                    "Android Gemini Nano"
                } else {
                    "LiteRT-LM"
                }
                onError("$provider failed: ${error.message}")
            }
        }
    }

    /**
     * Native function-calling first turn (flag-gated). Only the LiteRT-LM path
     * supports structured tools; Gemini Nano via ML Kit does not, so a blank
     * [modelPath] is surfaced as an error. Text of a plain-answer turn streams
     * through [onDelta] as it is generated; the structured turn map
     * ({@code tool_calls} or {@code text}) is returned via [onResult].
     */
    fun generateWithTools(
        prompt: String,
        systemInstruction: String,
        modelId: String,
        modelPath: String,
        backend: String,
        toolSchemas: List<String>,
        onDelta: (String) -> Unit,
        onResult: (Map<String, Any?>) -> Unit,
        onError: (String) -> Unit,
    ) {
        executor.execute {
            try {
                if (modelPath.isBlank()) {
                    onError(
                        "Native function calling requires a downloaded LiteRT-LM model.",
                    )
                    return@execute
                }
                liteRtClient.setBackendPreference(backend)
                onResult(
                    liteRtClient.generateWithTools(
                        modelPath,
                        prompt,
                        appContext.cacheDir.absolutePath,
                        systemInstruction,
                        toolSchemas,
                        object : LiteRtLocalPromptClient.StreamListener {
                            override fun onToken(token: String) {
                                onDelta(token)
                            }
                        },
                    ),
                )
            } catch (error: Throwable) {
                onError("LiteRT-LM function calling failed: ${error.message}")
            }
        }
    }

    /**
     * Feeds executed tool results back into the active native tool conversation,
     * streaming the next turn's text through [onDelta] and returning the
     * structured turn map via [onResult].
     */
    fun continueWithToolResults(
        results: List<Map<String, Any?>>,
        onDelta: (String) -> Unit,
        onResult: (Map<String, Any?>) -> Unit,
        onError: (String) -> Unit,
    ) {
        executor.execute {
            try {
                @Suppress("UNCHECKED_CAST")
                onResult(
                    liteRtClient.continueWithToolResults(
                        results as List<Map<String, Any>>,
                        object : LiteRtLocalPromptClient.StreamListener {
                            override fun onToken(token: String) {
                                onDelta(token)
                            }
                        },
                    ),
                )
            } catch (error: Throwable) {
                onError("LiteRT-LM tool result handling failed: ${error.message}")
            }
        }
    }

    /**
     * Debug spike: runs the LiteRT-LM native (manual) tool-calling probe against
     * [modelPath] and returns a diagnostic report. Isolated from the production
     * generate() path; only meaningful for a downloaded .litertlm model.
     */
    fun probeToolCall(
        modelPath: String,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit,
    ) {
        executor.execute {
            try {
                onSuccess(
                    liteRtClient.probeToolCall(modelPath, appContext.cacheDir.absolutePath),
                )
            } catch (error: Throwable) {
                onError("Native tool-calling probe failed: ${error.message}")
            }
        }
    }

    fun capabilities(): Map<String, Any?> {
        return mapOf(
            "androidLocalModelProvider" to
                "ML Kit Prompt API, Gemini Nano through AICore",
            "androidLocalModelDefault" to AndroidAiCoreModelCatalog.DEFAULT_MODEL_ID,
            "androidLocalModelListing" to
                "AICore does not expose a general installed-model list. " +
                    "Apps initialize a desired Gemini Nano configuration and check its status.",
            "androidLocalToolCalling" to
                "Tool routing is handled by the StudyOS Dart layer via bracketed " +
                    "[TOOL:NAME:ARG] directives parsed from the model's output; the " +
                    "native model only generates text.",
            "androidLocalModelContext" to appContext.packageName,
        )
    }

    private companion object {
        const val NANO_GENERATION_TIMEOUT_SECONDS = 120L
    }
}
