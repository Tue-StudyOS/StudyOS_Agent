package com.studyostue.app

import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerationConfig
import com.google.mlkit.genai.prompt.ModelPreference
import com.google.mlkit.genai.prompt.ModelReleaseStage
import com.google.mlkit.genai.prompt.generationConfig
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures
import com.google.mlkit.genai.prompt.modelConfig
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit

object AndroidAiCoreModelCatalog {
    const val DEFAULT_MODEL_ID = "android-aicore-stable-full"

    private data class ModelSpec(
        val id: String,
        val label: String,
        val releaseStage: Int,
        val releaseStageName: String,
        val preference: Int,
        val preferenceName: String,
    )

    private val specs = listOf(
        ModelSpec(
            DEFAULT_MODEL_ID,
            "Gemini Nano · Stable · Full",
            ModelReleaseStage.STABLE,
            "stable",
            ModelPreference.FULL,
            "full",
        ),
        ModelSpec(
            "android-aicore-stable-fast",
            "Gemini Nano · Stable · Fast",
            ModelReleaseStage.STABLE,
            "stable",
            ModelPreference.FAST,
            "fast",
        ),
        ModelSpec(
            "android-aicore-preview-full",
            "Gemini Nano · Preview · Full",
            ModelReleaseStage.PREVIEW,
            "preview",
            ModelPreference.FULL,
            "full",
        ),
        ModelSpec(
            "android-aicore-preview-fast",
            "Gemini Nano · Preview · Fast",
            ModelReleaseStage.PREVIEW,
            "preview",
            ModelPreference.FAST,
            "fast",
        ),
    )
    private val clients = ConcurrentHashMap<String, GenerativeModelFutures>()

    fun clientFor(modelId: String): GenerativeModelFutures {
        val spec = specFor(modelId)
        return clients.computeIfAbsent(spec.id) {
            GenerativeModelFutures.from(Generation.getClient(configFor(spec)))
        }
    }

    fun listModels(): List<Map<String, Any?>> {
        val pending = specs.map { spec ->
            val client = clientFor(spec.id)
            Triple(spec, client, client.checkStatus())
        }
        val resolved = pending.map { (spec, client, statusFuture) ->
            val status = runCatching {
                statusFuture.get(5, TimeUnit.SECONDS)
            }.getOrDefault(FeatureStatus.UNAVAILABLE)
            Triple(spec, status, client)
        }
        val baseModelNames = resolved.map { (_, status, client) ->
            runCatching {
                if (status == FeatureStatus.UNAVAILABLE) null else client.getBaseModelName()
            }.getOrNull()
        }
        return resolved.mapIndexed { index, (spec, status, _) ->
            val baseModelName = runCatching {
                baseModelNames[index]?.get(2, TimeUnit.SECONDS).orEmpty()
            }.getOrDefault("")
            mapOf(
                "id" to spec.id,
                "label" to spec.label,
                "releaseStage" to spec.releaseStageName,
                "preference" to spec.preferenceName,
                "status" to statusName(status),
                "baseModelName" to baseModelName,
            )
        }
    }

    private fun specFor(modelId: String): ModelSpec {
        return specs.firstOrNull { it.id == modelId } ?: specs.first()
    }

    private fun configFor(spec: ModelSpec): GenerationConfig {
        return generationConfig {
            modelConfig = modelConfig {
                releaseStage = spec.releaseStage
                preference = spec.preference
            }
        }
    }

    private fun statusName(status: Int): String {
        return when (status) {
            FeatureStatus.AVAILABLE -> "available"
            FeatureStatus.DOWNLOADABLE -> "downloadable"
            FeatureStatus.DOWNLOADING -> "downloading"
            else -> "unavailable"
        }
    }
}
