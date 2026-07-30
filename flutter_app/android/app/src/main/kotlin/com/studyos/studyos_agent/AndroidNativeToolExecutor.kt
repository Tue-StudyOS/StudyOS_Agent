package com.studyostue.app

import android.Manifest
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager.PERMISSION_GRANTED
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import com.example.studyOS.Reminder.ReminderManager
import com.example.studyOS.offline.Tools
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.util.Locale

class AndroidNativeToolExecutor(context: Context) {
    private val appContext = context.applicationContext
    private val tools: Tools by lazy { Tools(appContext) }
    private val calendarBridge: AndroidCalendarBridge by lazy {
        AndroidCalendarBridge(appContext)
    }

    fun canControlFlashlight(): Boolean {
        return appContext.packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)
    }

    fun capabilities(): List<Map<String, Any?>> {
        return listOf(
            supported("get_device_status"),
            supported(
                "set_flashlight",
                canControlFlashlight(),
                "This device does not report a camera flash.",
            ),
            supported("open_installed_app"),
            supported("search_youtube"),
            supported("open_system_setting"),
            supported(
                "create_reminder",
                canCreateReminder(),
                reminderUnsupportedReason(),
            ),
            supported("list_calendar_events"),
            supported("create_calendar_event"),
        )
    }

    fun execute(name: String, arguments: Map<*, *>): String {
        return when (name) {
            "get_device_status" -> tools.getDeviceStatus()
            "set_flashlight" -> tools.toggleFlashlight(booleanArgument(arguments, "enabled"))
            "open_installed_app" -> {
                val appName = stringArgument(arguments, "name")
                tools.openApp(appName)
            }
            "search_youtube" -> {
                val query = stringArgument(arguments, "query")
                tools.searchYoutube(query)
                "Opened YouTube search for '$query'."
            }
            "open_system_setting" -> openSystemSetting(stringArgument(arguments, "setting"))
            "create_reminder" -> createReminder(arguments)
            "list_calendar_events" -> calendarBridge.listEvents(arguments)
            "create_calendar_event" -> calendarBridge.createEvent(arguments)
            else -> throw IllegalArgumentException("Native tool is not available: $name")
        }
    }

    fun canCreateReminder(): Boolean {
        return hasNotificationPermission()
    }

    fun canReadCalendar(): Boolean = calendarBridge.canReadCalendar()

    fun canWriteCalendar(): Boolean = calendarBridge.canWriteCalendar()

    fun syncScheduleToCalendar(arguments: Map<*, *>): String {
        return calendarBridge.syncSchedule(arguments)
    }

    fun listDeviceCalendarEvents(arguments: Map<*, *>): List<Map<String, Any?>> {
        return calendarBridge.listStructuredEvents(arguments)
    }

    private fun openSystemSetting(setting: String): String {
        val normalized = setting.trim().lowercase()
        val action = when (normalized) {
            "wifi" -> Settings.ACTION_WIFI_SETTINGS
            "bluetooth" -> Settings.ACTION_BLUETOOTH_SETTINGS
            "location" -> Settings.ACTION_LOCATION_SOURCE_SETTINGS
            "mobile_data" -> Settings.ACTION_DATA_ROAMING_SETTINGS
            else -> throw IllegalArgumentException(
                "Unsupported setting '$setting'. Use wifi, bluetooth, location, or mobile_data.",
            )
        }
        val intent = Intent(action).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        appContext.startActivity(intent)
        return "Opened $normalized settings. Direct toggles are controlled by Android."
    }

    private fun createReminder(arguments: Map<*, *>): String {
        val title = stringArgument(arguments, "title")
        val time = localDateTimeArgument(arguments, "time")
        val type = enumArgument(
            arguments,
            "type",
            ReminderManager.Type.REMINDER,
        )
        val repeat = enumArgument(
            arguments,
            "repeat",
            ReminderManager.Repeat.ONCE,
        )
        ReminderManager.get().init(appContext)
        val id = ReminderManager.get().create(title, time, type, repeat)
        return "Created ${type.name.lowercase(Locale.US)} '$title' reminder ($repeat) with id $id."
    }

    private fun reminderUnsupportedReason(): String? {
        if (!hasNotificationPermission()) {
            return "Notification permission is required before reminders can be created."
        }
        return null
    }

    private fun hasNotificationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            appContext.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PERMISSION_GRANTED
    }

    fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        return alarmManager?.canScheduleExactAlarms() == true
    }

    private fun supported(
        name: String,
        supported: Boolean = true,
        reasonWhenUnsupported: String? = null,
    ): Map<String, Any?> {
        return mapOf(
            "name" to name,
            "supported" to supported,
            "reason" to if (supported) null else reasonWhenUnsupported,
        )
    }

    private fun stringArgument(arguments: Map<*, *>, key: String): String {
        val value = arguments[key]?.toString()?.trim().orEmpty()
        if (value.isBlank()) {
            throw IllegalArgumentException("Missing required '$key' argument.")
        }
        return value
    }

    private fun booleanArgument(arguments: Map<*, *>, key: String): Boolean {
        return when (val value = arguments[key]) {
            is Boolean -> value
            is String -> value.equals("true", ignoreCase = true)
            else -> throw IllegalArgumentException("Missing required boolean '$key' argument.")
        }
    }

    private fun localDateTimeArgument(arguments: Map<*, *>, key: String): LocalDateTime {
        val value = stringArgument(arguments, key)
        return runCatching {
            OffsetDateTime.parse(value)
                .atZoneSameInstant(ZoneId.systemDefault())
                .toLocalDateTime()
        }.getOrElse {
            runCatching {
                Instant.parse(value)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDateTime()
            }.getOrElse {
                runCatching {
                    LocalDateTime.parse(value)
                }.getOrElse {
                    throw IllegalArgumentException(
                        "Reminder '$key' must be an ISO-8601 timestamp.",
                    )
                }
            }
        }
    }

    private inline fun <reified T : Enum<T>> enumArgument(
        arguments: Map<*, *>,
        key: String,
        defaultValue: T,
    ): T {
        val value = arguments[key]?.toString()?.trim()
        if (value.isNullOrEmpty()) return defaultValue
        return runCatching {
            enumValueOf<T>(value.uppercase(Locale.US))
        }.getOrElse {
            throw IllegalArgumentException(
                "Unsupported '$key' value '$value'.",
            )
        }
    }
}
