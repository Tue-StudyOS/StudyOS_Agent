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
        result: MethodChannel.Result,
    ) {
        if (!nativeInitialized) {
            initializeNativeLayer()
        }

        try {
            localPromptClient().generate(
                prompt = localPrompt(systemPrompt, memory, text),
                onSuccess = { response ->
                    emitStatus("Android Gemini Nano response received.")
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
    ): String {
        return buildString {
            appendLine(systemPrompt.ifBlank { "You are StudyOS Agent." })
            appendLine()
            appendLine(
                "Runtime note: Android local mode uses ML Kit Prompt API. " +
                    "It cannot execute StudyOS tool calls in this app, so only " +
                    "answer from provided context and say what is missing.",
            )
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
}
