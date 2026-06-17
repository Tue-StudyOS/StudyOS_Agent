package com.studyos.studyos_agent

import android.content.Context
import com.example.studyOS.offline.Tools
import java.util.Locale
import java.util.UUID

class AndroidLiteRtToolExecutor(
    context: Context,
    private val emitToolTrace: (
        toolName: String,
        status: String,
        summary: String,
        callId: String,
    ) -> Unit,
) {
    private val appContext = context.applicationContext
    private val tools: Tools by lazy { Tools(appContext) }

    fun execute(
        toolName: String,
        argument: String,
        systemPrompt: String,
        memory: String,
    ): String {
        val normalized = normalizeToolName(toolName)
        val callId = "android-litert-${normalized.lowercase(Locale.US)}-${UUID.randomUUID()}"
        emitToolTrace(
            normalized,
            "running",
            "Running Android LiteRT local tool.",
            callId,
        )

        return try {
            val output = when (normalized) {
                "GET_STUDY_CONTEXT" -> systemPrompt.ifBlank {
                    "No StudyOS context was provided."
                }
                "READ_MEMORIES" -> memory.trim().ifBlank {
                    "No saved StudyOS memories were provided."
                }
                "GET_SCHEDULE" -> scheduleContext(systemPrompt)
                "GET_STATUS" -> tools.getDeviceStatus()
                "LIGHT_CONTROL" -> tools.toggleFlashlight(
                    argument.uppercase(Locale.US).contains("ON") ||
                        argument.uppercase(Locale.US).contains("AN") ||
                        argument.equals("true", ignoreCase = true),
                )
                "OPEN_APP" -> if (argument.isBlank()) {
                    "App name was not provided."
                } else {
                    tools.openApp(argument)
                }
                "SEARCH_YOUTUBE" -> {
                    val query = argument.ifBlank { "StudyOS" }
                    tools.searchYoutube(query)
                    "Opened YouTube search for '$query'."
                }
                else -> "Tool is not available: $toolName"
            }
            emitToolTrace(normalized, "done", "Returned ${output.length} chars.", callId)
            output
        } catch (error: Throwable) {
            val message = "Android LiteRT tool failed: ${error.message}"
            emitToolTrace(normalized, "failed", message, callId)
            message
        }
    }

    private fun normalizeToolName(toolName: String): String {
        return when (toolName.trim().lowercase(Locale.US)) {
            "get_study_context" -> "GET_STUDY_CONTEXT"
            "read_memories" -> "READ_MEMORIES"
            "get_schedule" -> "GET_SCHEDULE"
            "get_status" -> "GET_STATUS"
            "light_control" -> "LIGHT_CONTROL"
            "open_app" -> "OPEN_APP"
            "search_youtube" -> "SEARCH_YOUTUBE"
            else -> toolName.trim().uppercase(Locale.US)
        }
    }

    private fun scheduleContext(systemPrompt: String): String {
        val marker = "Cached timetable summary:"
        val index = systemPrompt.indexOf(marker)
        if (index < 0) {
            return "No cached timetable summary was provided."
        }
        return systemPrompt.substring(index).trim()
    }
}
