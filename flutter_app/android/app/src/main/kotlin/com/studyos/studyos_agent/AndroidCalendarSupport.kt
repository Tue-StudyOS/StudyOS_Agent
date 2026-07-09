package com.studyos.studyos_agent

import android.database.Cursor
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

internal const val STUDYOS_CALENDAR_DAY_MILLIS = 86_400_000L

internal data class AndroidCalendarLectureInput(
    val id: String,
    val title: String,
    val startMillis: Long,
    val endMillis: Long,
    val location: String?,
    val detail: String?,
)

internal fun androidCalendarLectureInput(item: Any?): AndroidCalendarLectureInput? {
    val values = item as? Map<*, *> ?: return null
    val title = androidCalendarOptionalString(values["title"]) ?: return null
    val start = androidCalendarParseMillis(
        androidCalendarOptionalString(values["start"]) ?: return null,
    )
    val end = androidCalendarOptionalString(values["end"])
        ?.let(::androidCalendarParseMillis) ?: start + 90 * 60 * 1_000
    val id = androidCalendarOptionalString(values["id"]) ?: "$title-$start"
    return AndroidCalendarLectureInput(
        id = id,
        title = title,
        startMillis = start,
        endMillis = end,
        location = androidCalendarOptionalString(values["location"]),
        detail = androidCalendarOptionalString(values["detail"]),
    )
}

internal fun androidCalendarStringArgument(arguments: Map<*, *>, key: String): String {
    return androidCalendarOptionalString(arguments[key])
        ?: throw IllegalArgumentException("Missing required '$key' argument.")
}

internal fun androidCalendarMillisArgument(arguments: Map<*, *>, key: String): Long {
    return androidCalendarParseMillis(androidCalendarStringArgument(arguments, key))
}

internal fun androidCalendarIntArgument(
    arguments: Map<*, *>,
    key: String,
    defaultValue: Int,
): Int {
    return when (val value = arguments[key]) {
        null -> defaultValue
        is Number -> value.toInt()
        else -> value.toString().trim().toIntOrNull() ?: defaultValue
    }
}

internal fun androidCalendarParseMillis(value: String): Long {
    return runCatching {
        OffsetDateTime.parse(value).toInstant().toEpochMilli()
    }.getOrElse {
        runCatching {
            Instant.parse(value).toEpochMilli()
        }.getOrElse {
            runCatching {
                LocalDateTime.parse(value)
                    .atZone(ZoneId.systemDefault())
                    .toInstant()
                    .toEpochMilli()
            }.getOrElse {
                throw IllegalArgumentException("Expected ISO-8601 timestamp: $value")
            }
        }
    }
}

internal fun androidCalendarOptionalString(value: Any?): String? {
    return value?.toString()?.trim()?.takeIf { it.isNotEmpty() }
}

internal fun androidCalendarDateLabel(millis: Long): String {
    val formatter = DateTimeFormatter.ofPattern("EEE d MMM HH:mm")
    return Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).format(formatter)
}

internal fun androidCalendarTimeLabel(millis: Long): String {
    val formatter = DateTimeFormatter.ofPattern("HH:mm")
    return Instant.ofEpochMilli(millis).atZone(ZoneId.systemDefault()).format(formatter)
}

internal fun androidCalendarLocationSuffix(location: String?): String {
    val value = androidCalendarOptionalString(location) ?: return ""
    return " @ $value"
}

internal fun androidCalendarLectureId(description: String?, markerPrefix: String): String? {
    return description
        ?.lineSequence()
        ?.firstOrNull { it.startsWith(markerPrefix) }
        ?.removePrefix(markerPrefix)
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
}

internal fun Cursor.calendarStringValue(column: String): String? {
    val index = getColumnIndex(column)
    return if (index >= 0 && !isNull(index)) getString(index) else null
}

internal fun Cursor.calendarLongValue(column: String): Long {
    return getLong(getColumnIndexOrThrow(column))
}
