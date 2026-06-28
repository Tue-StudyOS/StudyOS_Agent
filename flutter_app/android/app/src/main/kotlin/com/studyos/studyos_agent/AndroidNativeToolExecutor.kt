package com.studyos.studyos_agent

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import com.example.studyOS.offline.Tools

class AndroidNativeToolExecutor(context: Context) {
    private val appContext = context.applicationContext
    private val tools: Tools by lazy { Tools(appContext) }

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
            mapOf(
                "name" to "create_reminder",
                "supported" to false,
                "reason" to "Reminder scheduling is reserved for the reminder PR.",
            ),
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
            else -> throw IllegalArgumentException("Native tool is not available: $name")
        }
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
}
