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

    fun generate(
        prompt: String,
        modelId: String,
        modelPath: String,
        backend: String,
        canExecuteTool: (String) -> Boolean,
        onToolRequest: (String, String) -> String,
        onDelta: (String) -> Unit,
        onReset: () -> Unit,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit,
    ) {
        // Locals so the anonymous StreamListener can call the lambdas without
        // shadowing its own onReset() override.
        val deltaSink = onDelta
        val resetSink = onReset
        executor.execute {
            try {
                if (modelPath.isNotBlank()) {
                    liteRtClient.setBackendPreference(backend)
                    val response = liteRtClient.generateWithToolsStreaming(
                        modelPath,
                        prompt,
                        appContext.cacheDir.absolutePath,
                        object : LiteRtLocalPromptClient.ToolExecutor {
                            override fun canExecute(toolName: String): Boolean {
                                return canExecuteTool(toolName)
                            }

                            override fun execute(toolName: String, argument: String): String {
                                return onToolRequest(toolName, argument)
                            }
                        },
                        object : LiteRtLocalPromptClient.StreamListener {
                            override fun onToken(token: String) {
                                deltaSink(token)
                            }

                            override fun onReset() {
                                resetSink()
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

                val model = AndroidAiCoreModelCatalog.clientFor(modelId)
                when (val status = model.checkStatus().get(2, TimeUnit.SECONDS)) {
                    FeatureStatus.AVAILABLE -> {
                        val future = model.generateContent(
                            prompt,
                            StreamingCallback { text -> deltaSink(text) },
                        )
                        activeNanoFuture = future
                        val response = try {
                            future.get()
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

    fun capabilities(): Map<String, Any?> {
        return mapOf(
            "androidLocalModelProvider" to
                "ML Kit Prompt API, Gemini Nano through AICore",
            "androidLocalModelDefault" to AndroidAiCoreModelCatalog.DEFAULT_MODEL_ID,
            "androidLocalModelListing" to
                "AICore does not expose a general installed-model list. " +
                    "Apps initialize a desired Gemini Nano configuration and check its status.",
            "androidLocalToolCalling" to
                "ML Kit Prompt API does not expose native function calling. " +
                    "Downloaded LiteRT-LM models can use StudyOS bracketed " +
                    "[TOOL:NAME:ARG] calls executed by the Android bridge.",
            "androidLocalModelContext" to appContext.packageName,
        )
    }
}
