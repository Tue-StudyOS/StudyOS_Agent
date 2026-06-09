package com.studyos.studyos_agent

import android.os.Handler
import android.os.Looper
import com.example.studyOS.DataStructures.MemoryEntry
import com.example.studyOS.DataStructures.Message
import com.example.studyOS.DataStructures.Speaker
import com.example.studyOS.Memory.FileIO
import com.example.studyOS.Memory.StorageFiles
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
            "sendMessage" -> {
                val text = call.argument<String>("text")?.trim().orEmpty()
                if (text.isBlank()) {
                    result.error("empty_message", "Message text must not be empty.", null)
                    return
                }
                result.success(sendMessageToNativeLayer(text))
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
            WorldStateProvider.init(applicationContext, 5_000)
            nativeInitialized = true
            emitStatus("Native Android bridge initialized.")
            mapOf(
                "status" to "Native Android bridge initialized.",
                "mode" to RuntimeEnvironment.getInstance().mode.name,
            )
        } catch (error: Throwable) {
            nativeInitialized = false
            val message = "Native initialization failed: ${error.message}"
            emitStatus(message)
            mapOf("status" to message)
        }
    }

    private fun sendMessageToNativeLayer(text: String): String {
        if (!nativeInitialized) {
            initializeNativeLayer()
        }

        return try {
            val worldState = runCatching {
                WorldStateProvider.getInstance().worldState
            }.getOrNull()

            FileIO.getInstance().appendMemory(
                StorageFiles.MEMORY,
                MemoryEntry(Speaker.BOSS, text, worldState, "flutter", true)
            )

            val received = Message(text, Speaker.BOSS)
            emitStatus("Native Android bridge received: ${received.text()}")

            "Message forwarded to Android native layer. Agent processing can now be wired from JarvisController into this bridge without changing the Flutter UI."
        } catch (error: Throwable) {
            val message = "Native message handling failed: ${error.message}"
            emitStatus(message)
            message
        }
    }

    private fun worldStateMap(): Map<String, Any?> {
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
            "canUseBackgroundLocation" to true,
            "canCreateExactAlarm" to true,
            "canOpenInstalledApps" to true,
            "canReadCalendar" to true,
            "canUseOfflineLiteRtModel" to true,
            "canControlFlashlight" to true,
            "canStartPhoneCall" to true,
            "iosParity" to "limited by iOS background execution and app-control policies",
            "webDesktopParity" to "limited shell only until adapters are implemented",
        )
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
