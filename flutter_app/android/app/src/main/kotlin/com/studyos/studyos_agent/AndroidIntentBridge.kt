package com.studyostue.app

import android.content.Context
import android.content.Intent
import android.speech.RecognizerIntent
import org.json.JSONArray
import org.json.JSONObject

class AndroidIntentBridge(context: Context) {
    private val appContext = context.applicationContext
    private val preferences =
        appContext.getSharedPreferences("studyos_android_bridge", Context.MODE_PRIVATE)

    fun captureIntent(intent: Intent?) {
        val prompt = promptFromIntent(intent) ?: return
        preferences.edit().putString(PENDING_PROMPT_KEY, prompt).apply()
    }

    fun consumePendingPrompt(): String? {
        val prompt = preferences.getString(PENDING_PROMPT_KEY, null)
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
        preferences.edit().remove(PENDING_PROMPT_KEY).apply()
        return prompt
    }

    fun publishSnapshot(arguments: Any?): String {
        val snapshot = JSONObject()
        val payload = arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
        snapshot.put("updatedAt", payload["updatedAt"]?.toString().orEmpty())
        snapshot.put("memoryPreview", payload["memoryPreview"]?.toString().orEmpty())
        snapshot.put("lectures", lecturesFrom(payload["lectures"]))
        preferences.edit().putString(INTENT_SNAPSHOT_KEY, snapshot.toString()).apply()
        return "Android assistant snapshot published."
    }

    fun snapshotStatus(): String {
        val raw = preferences.getString(INTENT_SNAPSHOT_KEY, null) ?: return "not_synced"
        return runCatching {
            val snapshot = JSONObject(raw)
            val lectureCount = snapshot.optJSONArray("lectures")?.length() ?: 0
            val updatedAt = snapshot.optString("updatedAt").ifBlank { "unknown" }
            "synced:$lectureCount lectures:$updatedAt"
        }.getOrDefault("unreadable")
    }

    private fun promptFromIntent(intent: Intent?): String? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
            Intent.ACTION_PROCESS_TEXT -> intent.getCharSequenceExtra(
                Intent.EXTRA_PROCESS_TEXT,
            )?.toString()
            RecognizerIntent.ACTION_RECOGNIZE_SPEECH,
            RecognizerIntent.ACTION_VOICE_SEARCH_HANDS_FREE,
            Intent.ACTION_VOICE_COMMAND
            -> intent.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                ?.firstOrNull()
            else -> intent.getStringExtra(Intent.EXTRA_TEXT)
                ?: intent.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                    ?.firstOrNull()
        }?.trim()?.takeIf { it.isNotEmpty() }
    }

    private fun lecturesFrom(value: Any?): JSONArray {
        val lectures = JSONArray()
        val items = value as? Iterable<*> ?: return lectures
        for (item in items) {
            val map = item as? Map<*, *> ?: continue
            lectures.put(
                JSONObject()
                    .put("id", map["id"]?.toString().orEmpty())
                    .put("title", map["title"]?.toString().orEmpty())
                    .put("start", map["start"]?.toString().orEmpty())
                    .put("end", map["end"]?.toString().orEmpty())
                    .put("location", map["location"]?.toString().orEmpty())
                    .put("detail", map["detail"]?.toString().orEmpty()),
            )
        }
        return lectures
    }

    private companion object {
        const val INTENT_SNAPSHOT_KEY = "intent_snapshot"
        const val PENDING_PROMPT_KEY = "pending_prompt"
    }
}
