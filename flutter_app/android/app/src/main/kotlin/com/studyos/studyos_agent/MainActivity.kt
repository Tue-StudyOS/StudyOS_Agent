package com.studyos.studyos_agent

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.example.studyOS.Memory.FileIO
import com.example.studyOS.Reminder.ReminderManager
import com.example.studyOS.Sensors.WorldStateProvider
import com.example.studyOS.System.RuntimeEnvironment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null
    private var nativeInitialized = false
    private var localPromptClient: AndroidLocalPromptClient? = null
    private var localModelStore: AndroidLocalModelStore? = null
    private var liteRtToolExecutor: AndroidLiteRtToolExecutor? = null
    private lateinit var intentBridge: AndroidIntentBridge

    override fun onCreate(savedInstanceState: Bundle?) {
        intentBridge = AndroidIntentBridge(applicationContext)
        intentBridge.captureIntent(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intentBridge.captureIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "studyos/native"
        ).setMethodCallHandler(::handleMethodCall)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "studyos/events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                emitStatus("Native Android event channel connected.")
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> result.success(initializeNativeLayer())
            "getWorldState" -> result.success(worldStateMap())
            "getCapabilities" -> result.success(capabilities())
            "listLocalModels" -> result.success(localModelStore().listModels())
            "downloadLocalModel" -> downloadLocalModel(call, result)
            "cancelLocalModelDownload" -> {
                localModelStore().cancelDownload()
                result.success(null)
            }
            "deleteLocalModel" -> deleteLocalModel(call, result)
            "publishIntentSnapshot" -> result.success(
                intentBridge.publishSnapshot(call.arguments),
            )
            "consumePendingIntentPrompt" -> result.success(
                intentBridge.consumePendingPrompt(),
            )
            "sendMessage" -> {
                val text = call.argument<String>("text")?.trim().orEmpty()
                if (text.isBlank()) {
                    result.error("empty_message", "Message text must not be empty.", null)
                    return
                }
                sendMessageToNativeLayer(
                    text = text,
                    systemPrompt = call.argument<String>("systemPrompt").orEmpty(),
                    memory = call.argument<String>("memory").orEmpty(),
                    localModelPath = call.argument<String>("localModelPath").orEmpty(),
                    result = result,
                )
            }
            else -> result.notImplemented()
        }
    }

    private fun initializeNativeLayer(): Map<String, Any?> {
        if (nativeInitialized) {
            return mapOf("status" to "Native Android bridge already initialized.")
        }

        return try {
            RuntimeEnvironment.init(applicationContext)
            FileIO.init(applicationContext)
            ReminderManager.get().init(applicationContext)
            if (hasLocationPermission()) {
                WorldStateProvider.init(applicationContext, 5_000)
            }
            nativeInitialized = true
            val status = if (hasLocationPermission()) {
                "Native Android bridge initialized."
            } else {
                "Native Android bridge initialized without location access."
            }
            emitStatus(status)
            mapOf(
                "status" to status,
                "mode" to RuntimeEnvironment.getInstance().mode.name,
            )
        } catch (error: Throwable) {
            nativeInitialized = false
            val message = "Native initialization failed: ${error.message}"
            emitStatus(message)
            mapOf("status" to message)
        }
    }

    private fun sendMessageToNativeLayer(
        text: String,
        systemPrompt: String,
        memory: String,
        localModelPath: String,
        result: MethodChannel.Result,
    ) {
        if (!nativeInitialized) {
            initializeNativeLayer()
        }

        try {
            val prompt = localPrompt(
                systemPrompt = systemPrompt,
                memory = memory,
                userText = text,
                supportsLiteRtTools = localModelPath.isNotBlank(),
            )
            localPromptClient().generate(
                prompt = prompt,
                modelPath = localModelPath,
                onToolRequest = { toolName, argument ->
                    liteRtToolExecutor().execute(
                        toolName = toolName,
                        argument = argument,
                        systemPrompt = systemPrompt,
                        memory = memory,
                    )
                },
                onSuccess = { response ->
                    emitStatus(
                        if (localModelPath.isBlank()) {
                            "Android Gemini Nano response received."
                        } else {
                            "LiteRT-LM local model response received."
                        },
                    )
                    Handler(Looper.getMainLooper()).post {
                        result.success(response)
                    }
                },
                onError = { message ->
                    emitStatus(message)
                    Handler(Looper.getMainLooper()).post {
                        result.error(
                            "android_local_model_unavailable",
                            message,
                            null,
                        )
                    }
                },
            )
        } catch (error: Throwable) {
            val message = "Native message handling failed: ${error.message}"
            emitStatus(message)
            result.error("android_native_error", message, null)
        }
    }

    private fun localPrompt(
        systemPrompt: String,
        memory: String,
        userText: String,
        supportsLiteRtTools: Boolean,
    ): String {
        return buildString {
            appendLine(systemPrompt.ifBlank { "You are StudyOS Agent." })
            appendLine()
            if (supportsLiteRtTools) {
                appendLine("Android LiteRT local tool protocol:")
                appendLine(
                    "Use tools only when they are helpful. For normal questions, " +
                        "answer directly from the provided context.",
                )
                appendLine(
                    "To call tools, respond only with one or more directives " +
                        "in this exact form: [TOOL:TOOL_NAME:ARGUMENT].",
                )
                appendLine(
                    "After the app returns tool results, answer naturally. " +
                        "Do not show raw tool directives to the user in the final answer.",
                )
                appendLine("Available Android LiteRT tools:")
                appendLine("- [TOOL:GET_STUDY_CONTEXT:] reads the current StudyOS context.")
                appendLine("- [TOOL:READ_MEMORIES:] reads provided local StudyOS memories.")
                appendLine("- [TOOL:GET_SCHEDULE:] reads cached timetable context when available.")
                appendLine("- [TOOL:GET_STATUS:] reads Android device status.")
                appendLine("- [TOOL:LIGHT_CONTROL:ON] or [TOOL:LIGHT_CONTROL:OFF] toggles flashlight.")
                appendLine("- [TOOL:OPEN_APP:Camera] opens an installed app by name.")
                appendLine("- [TOOL:SEARCH_YOUTUBE:query] opens a YouTube search.")
            } else {
                appendLine(
                    "Runtime note: Android Gemini Nano through ML Kit Prompt API " +
                        "does not expose tool calling in this app. Answer from " +
                        "provided context and say what is missing.",
                )
            }
            if (memory.isNotBlank()) {
                appendLine()
                appendLine("Local StudyOS memory:")
                appendLine(memory.trim())
            }
            appendLine()
            appendLine("User request:")
            appendLine(userText)
        }.trim()
    }

    private fun localPromptClient(): AndroidLocalPromptClient {
        val existing = localPromptClient
        if (existing != null) return existing
        return AndroidLocalPromptClient(applicationContext).also {
            localPromptClient = it
        }
    }

    private fun localModelStore(): AndroidLocalModelStore {
        val existing = localModelStore
        if (existing != null) return existing
        return AndroidLocalModelStore(applicationContext).also {
            localModelStore = it
        }
    }

    private fun liteRtToolExecutor(): AndroidLiteRtToolExecutor {
        val existing = liteRtToolExecutor
        if (existing != null) return existing
        return AndroidLiteRtToolExecutor(applicationContext, ::emitToolTrace).also {
            liteRtToolExecutor = it
        }
    }

    private fun downloadLocalModel(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id").orEmpty()
        val label = call.argument<String>("label").orEmpty()
        val fileName = call.argument<String>("fileName").orEmpty()
        val url = call.argument<String>("url").orEmpty()
        Thread {
            try {
                val model = localModelStore().downloadModel(
                    id = id,
                    label = label,
                    fileName = fileName,
                    url = url,
                    onProgress = { receivedBytes, totalBytes ->
                        emitDownloadProgress(id, label, receivedBytes, totalBytes)
                    },
                )
                emitStatus("Downloaded local model: $label.")
                Handler(Looper.getMainLooper()).post {
                    result.success(model)
                }
            } catch (error: Throwable) {
                val message = "Local model download failed: ${error.message}"
                emitStatus(message)
                Handler(Looper.getMainLooper()).post {
                    result.error("local_model_download_failed", message, null)
                }
            }
        }.start()
    }

    private fun deleteLocalModel(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id").orEmpty()
        Thread {
            try {
                val deleted = localModelStore().deleteModel(id)
                emitStatus("Deleted local model storage for $id.")
                Handler(Looper.getMainLooper()).post {
                    result.success(deleted)
                }
            } catch (error: Throwable) {
                val message = "Local model delete failed: ${error.message}"
                emitStatus(message)
                Handler(Looper.getMainLooper()).post {
                    result.error("local_model_delete_failed", message, null)
                }
            }
        }.start()
    }

    private fun worldStateMap(): Map<String, Any?> {
        if (!hasLocationPermission()) {
            return mapOf(
                "status" to "Location access is not enabled.",
                "platform" to "android",
                "date" to SimpleDateFormat("dd.MM.yyyy", Locale.getDefault()).format(Date()),
                "time" to SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(Date()),
                "weekday" to SimpleDateFormat("EEEE", Locale.getDefault()).format(Date()),
            )
        }

        val worldState = runCatching {
            if (!nativeInitialized) initializeNativeLayer()
            WorldStateProvider.getInstance().worldState
        }.getOrNull()

        if (worldState == null) {
            return mapOf(
                "status" to "World state is not ready yet.",
                "platform" to "android",
            )
        }

        return mapOf(
            "platform" to "android",
            "date" to worldState.date(),
            "time" to worldState.time(),
            "weekday" to worldState.weekday(),
            "gps" to "${worldState.gps()?.lat()}, ${worldState.gps()?.lon()}",
            "geocoded" to worldState.geocoded(),
            "deviceStatus" to worldState.deviceStatus().toString(),
            "motion" to worldState.motionData().toString(),
        )
    }

    private fun capabilities(): Map<String, Any?> {
        return mapOf(
            "platform" to "android",
            "canUseAlwaysListeningService" to true,
            "canUseLocationWorldState" to hasLocationPermission(),
            "canUseBackgroundLocation" to hasPermission(
                Manifest.permission.ACCESS_BACKGROUND_LOCATION,
            ),
            "canCreateExactAlarm" to true,
            "canOpenInstalledApps" to true,
            "canReadCalendar" to hasPermission(Manifest.permission.READ_CALENDAR),
            "canUseOfflineLiteRtModel" to true,
            "canManageDownloadedLiteRtModels" to true,
            "canUseAndroidGeminiNanoPrompt" to true,
            "canControlFlashlight" to true,
            "canStartPhoneCall" to hasPermission(Manifest.permission.CALL_PHONE),
            "androidAssistantSnapshot" to intentBridge.snapshotStatus(),
            "iosParity" to "limited by iOS background execution and app-control policies",
            "webDesktopParity" to "limited shell only until adapters are implemented",
        ) + localPromptClient().capabilities()
    }

    private fun hasLocationPermission(): Boolean {
        return hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
    }

    private fun hasPermission(permission: String): Boolean {
        return checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun emitStatus(message: String) {
        val payload = mapOf(
            "type" to "status",
            "message" to message,
            "timestamp" to SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss",
                Locale.US
            ).format(Date()),
        )

        Handler(Looper.getMainLooper()).post {
            eventSink?.success(payload)
        }
    }

    private fun emitToolTrace(
        toolName: String,
        status: String,
        summary: String,
        callId: String,
    ) {
        val payload = mapOf(
            "type" to "toolTrace",
            "message" to summary,
            "trace" to mapOf(
                "toolName" to toolName,
                "status" to status,
                "summary" to summary,
                "callId" to callId,
            ),
            "timestamp" to SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss",
                Locale.US
            ).format(Date()),
        )

        Handler(Looper.getMainLooper()).post {
            eventSink?.success(payload)
        }
    }

    private fun emitDownloadProgress(
        id: String,
        label: String,
        receivedBytes: Long,
        totalBytes: Long,
    ) {
        val payload = mapOf(
            "type" to "localModelDownloadProgress",
            "message" to "Downloading $label",
            "modelId" to id,
            "bytesReceived" to receivedBytes,
            "totalBytes" to totalBytes,
            "progress" to if (totalBytes > 0) {
                receivedBytes.toDouble() / totalBytes.toDouble()
            } else {
                null
            },
            "timestamp" to SimpleDateFormat(
                "yyyy-MM-dd'T'HH:mm:ss",
                Locale.US
            ).format(Date()),
        )

        Handler(Looper.getMainLooper()).post {
            eventSink?.success(payload)
        }
    }
}
