package com.studyos.studyos_agent

import android.Manifest
import android.content.ComponentCallbacks2
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.example.studyOS.Memory.FileIO
import com.example.studyOS.Reminder.ReminderManager
import com.example.studyOS.Sensors.WorldStateProvider
import com.example.studyOS.System.RuntimeEnvironment
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.GenAiException
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val calendarPermissionRequestCode = 7302
    private val aiCoreModelExecutor = Executors.newSingleThreadExecutor()
    private var eventSink: EventChannel.EventSink? = null
    private var nativeInitialized = false
    private var localPromptClient: AndroidLocalPromptClient? = null
    private var localModelStore: AndroidLocalModelStore? = null
    private var nativeToolExecutor: AndroidNativeToolExecutor? = null
    private var pdfPreview: AndroidPdfPreview? = null
    private var pendingCalendarOperation: (() -> Unit)? = null
    private lateinit var intentBridge: AndroidIntentBridge

    // Idle-unload timer: releases the on-device model after a stretch of no
    // activity so it does not hold RAM indefinitely on mid-range devices.
    private val idleUnloadHandler = Handler(Looper.getMainLooper())
    private val idleUnloadRunnable = Runnable { localPromptClient?.close() }
    private val idleUnloadDelayMs = 5 * 60 * 1000L

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

    override fun onStop() {
        // Backgrounded: release the on-device model so the OS is less likely to
        // reclaim the app under memory pressure. The next message rebuilds it.
        cancelIdleUnload()
        localPromptClient?.close()
        super.onStop()
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (level >= ComponentCallbacks2.TRIM_MEMORY_RUNNING_MODERATE) {
            localPromptClient?.close()
        }
    }

    override fun onDestroy() {
        cancelIdleUnload()
        localPromptClient?.close()
        aiCoreModelExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun scheduleIdleUnload() {
        idleUnloadHandler.removeCallbacks(idleUnloadRunnable)
        idleUnloadHandler.postDelayed(idleUnloadRunnable, idleUnloadDelayMs)
    }

    private fun cancelIdleUnload() {
        idleUnloadHandler.removeCallbacks(idleUnloadRunnable)
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
            "getNativeToolCapabilities" -> result.success(nativeToolCapabilities())
            "executeNativeTool" -> executeNativeTool(call, result)
            "syncScheduleToCalendar" -> syncScheduleToCalendar(call, result)
            "listDeviceCalendarEvents" -> listDeviceCalendarEvents(call, result)
            "previewPdf" -> pdfPreview().open(call, result)
            "listLocalModels" -> result.success(localModelStore().listModels())
            "listAndroidAiCoreModels" -> listAndroidAiCoreModels(result)
            "downloadAndroidAiCoreModel" -> downloadAndroidAiCoreModel(call, result)
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
                    systemInstruction = call.argument<String>("systemInstruction").orEmpty(),
                    localModelId = call.argument<String>("localModelId").orEmpty(),
                    localModelPath = call.argument<String>("localModelPath").orEmpty(),
                    localBackend = call.argument<String>("localBackend").orEmpty(),
                    result = result,
                )
            }
            "cancelMessage" -> {
                localPromptClient?.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun pdfPreview(): AndroidPdfPreview =
        pdfPreview ?: AndroidPdfPreview(this).also { pdfPreview = it }

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
        systemInstruction: String,
        localModelId: String,
        localModelPath: String,
        localBackend: String,
        result: MethodChannel.Result,
    ) {
        if (!nativeInitialized) {
            initializeNativeLayer()
        }
        scheduleIdleUnload()

        try {
            localPromptClient().generate(
                prompt = text,
                systemInstruction = systemInstruction,
                modelId = localModelId,
                modelPath = localModelPath,
                backend = localBackend,
                onDelta = { token ->
                    emitAssistantDelta(token)
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
                    scheduleIdleUnload()
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
                    scheduleIdleUnload()
                },
            )
        } catch (error: Throwable) {
            val message = "Native message handling failed: ${error.message}"
            emitStatus(message)
            result.error("android_native_error", message, null)
        }
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

    private fun listAndroidAiCoreModels(result: MethodChannel.Result) {
        aiCoreModelExecutor.execute {
            try {
                val models = AndroidAiCoreModelCatalog.listModels()
                Handler(Looper.getMainLooper()).post { result.success(models) }
            } catch (error: Throwable) {
                Handler(Looper.getMainLooper()).post {
                    result.error(
                        "aicore_model_list_failed",
                        "Could not check Android built-in AI: ${error.message}",
                        null,
                    )
                }
            }
        }
    }

    private fun downloadAndroidAiCoreModel(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val modelId = call.argument<String>("modelId").orEmpty()
        try {
            AndroidAiCoreModelCatalog.clientFor(modelId).download(
                object : DownloadCallback {
                    override fun onDownloadStarted(bytesToDownload: Long) {
                        emitStatus("Android built-in AI download started.")
                    }

                    override fun onDownloadProgress(totalBytesDownloaded: Long) {
                        emitStatus(
                            "Android built-in AI downloaded $totalBytesDownloaded bytes.",
                        )
                    }

                    override fun onDownloadCompleted() {
                        emitStatus("Android built-in AI download completed.")
                        Handler(Looper.getMainLooper()).post { result.success(null) }
                    }

                    override fun onDownloadFailed(error: GenAiException) {
                        Handler(Looper.getMainLooper()).post {
                            result.error(
                                "aicore_model_download_failed",
                                "Android built-in AI download failed: ${error.message}",
                                null,
                            )
                        }
                    }
                },
            )
        } catch (error: Throwable) {
            result.error(
                "aicore_model_download_failed",
                "Android built-in AI download failed: ${error.message}",
                null,
            )
        }
    }

    private fun nativeToolExecutor(): AndroidNativeToolExecutor {
        val existing = nativeToolExecutor
        if (existing != null) return existing
        return AndroidNativeToolExecutor(applicationContext).also {
            nativeToolExecutor = it
        }
    }


    private fun executeNativeTool(call: MethodCall, result: MethodChannel.Result) {
        val name = call.argument<String>("name")?.trim().orEmpty()
        val arguments = call.argument<Map<*, *>>("arguments") ?: emptyMap<String, Any?>()
        if (name.isBlank()) {
            result.error("native_tool_missing_name", "Native tool name is required.", null)
            return
        }
        if (name == "list_calendar_events" || name == "create_calendar_event") {
            runWithCalendarPermission(
                result = result,
                needsWrite = name == "create_calendar_event",
            ) {
                executeNativeToolAfterPermission(name, arguments, result)
            }
            return
        }
        executeNativeToolAfterPermission(name, arguments, result)
    }

    private fun executeNativeToolAfterPermission(
        name: String,
        arguments: Map<*, *>,
        result: MethodChannel.Result,
    ) {
        if (name == "list_calendar_events") {
            val executor = nativeToolExecutor()
            runCalendarReadInBackground(
                result = result,
                errorCode = "native_tool_failed",
                fallbackMessage = "Native tool failed.",
            ) {
                executor.execute(name, arguments)
            }
            return
        }
        try {
            result.success(nativeToolExecutor().execute(name, arguments))
        } catch (error: Throwable) {
            result.error(
                "native_tool_failed",
                error.message ?: "Native tool failed.",
                null,
            )
        }
    }

    private fun syncScheduleToCalendar(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        runWithCalendarPermission(result, needsWrite = true) {
            try {
                result.success(nativeToolExecutor().syncScheduleToCalendar(arguments))
            } catch (error: Throwable) {
                result.error(
                    "calendar_sync_failed",
                    error.message ?: "Calendar sync failed.",
                    null,
                )
            }
        }
    }

    private fun listDeviceCalendarEvents(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        runWithCalendarPermission(result, needsWrite = false) {
            val executor = nativeToolExecutor()
            runCalendarReadInBackground(
                result = result,
                errorCode = "calendar_read_failed",
                fallbackMessage = "Calendar events could not be read.",
            ) {
                executor.listDeviceCalendarEvents(arguments)
            }
        }
    }

    private fun runCalendarReadInBackground(
        result: MethodChannel.Result,
        errorCode: String,
        fallbackMessage: String,
        operation: () -> Any?,
    ) {
        Thread {
            try {
                val value = operation()
                Handler(Looper.getMainLooper()).post {
                    result.success(value)
                }
            } catch (error: Throwable) {
                Handler(Looper.getMainLooper()).post {
                    result.error(errorCode, error.message ?: fallbackMessage, null)
                }
            }
        }.start()
    }

    private fun runWithCalendarPermission(
        result: MethodChannel.Result,
        needsWrite: Boolean,
        operation: () -> Unit,
    ) {
        if (hasCalendarPermission(needsWrite)) {
            operation()
            return
        }
        if (pendingCalendarOperation != null) {
            result.error(
                "calendar_permission_pending",
                "Another calendar permission request is already in progress.",
                null,
            )
            return
        }
        pendingCalendarOperation = {
            if (hasCalendarPermission(needsWrite)) {
                operation()
            } else {
                result.error(
                    "calendar_permission_denied",
                    "Calendar permission was denied.",
                    null,
                )
            }
        }
        requestPermissions(
            if (needsWrite) {
                arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR)
            } else {
                arrayOf(Manifest.permission.READ_CALENDAR)
            },
            calendarPermissionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == calendarPermissionRequestCode) {
            val operation = pendingCalendarOperation
            pendingCalendarOperation = null
            operation?.invoke()
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
            "canCreateExactAlarm" to nativeToolExecutor().canScheduleExactAlarms(),
            "canCreateLocalReminder" to nativeToolExecutor().canCreateReminder(),
            "canOpenInstalledApps" to true,
            "canReadCalendar" to nativeToolExecutor().canReadCalendar(),
            "canCreateCalendarEvents" to nativeToolExecutor().canWriteCalendar(),
            "canSyncScheduleToCalendar" to hasCalendarPermission(needsWrite = true),
            "canUseOfflineLiteRtModel" to true,
            "canManageDownloadedLiteRtModels" to true,
            "canUseAndroidGeminiNanoPrompt" to true,
            "canControlFlashlight" to nativeToolExecutor().canControlFlashlight(),
            "canStartPhoneCall" to hasPermission(Manifest.permission.CALL_PHONE),
            "nativeToolContractVersion" to 1,
            "nativeTools" to nativeToolExecutor().capabilities(),
            "androidAssistantSnapshot" to intentBridge.snapshotStatus(),
            "iosParity" to "limited by iOS background execution and app-control policies",
            "webDesktopParity" to "limited shell only until adapters are implemented",
        ) + localPromptClient().capabilities()
    }

    private fun nativeToolCapabilities(): Map<String, Any?> {
        return mapOf(
            "platform" to "android",
            "nativeToolContractVersion" to 1,
            "nativeTools" to nativeToolExecutor().capabilities(),
        )
    }

    private fun hasLocationPermission(): Boolean {
        return hasPermission(Manifest.permission.ACCESS_FINE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
    }

    private fun hasCalendarPermission(needsWrite: Boolean): Boolean {
        return nativeToolExecutor().canReadCalendar() &&
            (!needsWrite || nativeToolExecutor().canWriteCalendar())
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

    private fun emitAssistantDelta(text: String) {
        val payload = mapOf(
            "type" to "assistantDelta",
            "message" to text,
            "reset" to false,
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
