package com.studyos.studyos_agent

import android.content.Context
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class AndroidLocalPromptClient(context: Context) {
    private val appContext = context.applicationContext
    private val executor = Executors.newSingleThreadExecutor()

    fun generate(
        prompt: String,
        onSuccess: (String) -> Unit,
        onError: (String) -> Unit,
    ) {
        executor.execute {
            try {
                val model = GenerativeModelFutures.from(Generation.getClient())
                when (val status = model.checkStatus().get(2, TimeUnit.SECONDS)) {
                    FeatureStatus.AVAILABLE -> {
                        val response = model.generateContent(prompt).get()
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
                onError("Android Gemini Nano failed: ${error.message}")
            }
        }
    }

    fun capabilities(): Map<String, Any?> {
        return mapOf(
            "androidLocalModelProvider" to
                "ML Kit Prompt API, Gemini Nano through AICore",
            "androidLocalModelStatus" to runCatching {
                GenerativeModelFutures
                    .from(Generation.getClient())
                    .checkStatus()
                    .get(2, TimeUnit.SECONDS)
                    .toString()
            }.getOrElse { "unavailable: ${it.message}" },
            "androidLocalToolCalling" to
                "ML Kit Prompt API does not expose native function calling. Google AI Edge function calling requires a shipped or downloaded model and physical-device validation.",
            "androidLocalModelContext" to appContext.packageName,
        )
    }
}
