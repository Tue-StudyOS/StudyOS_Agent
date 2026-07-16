package com.studyos.studyos_agent

import android.content.ContentResolver
import android.database.Cursor
import android.provider.CalendarContract
import java.time.Instant
import java.time.LocalDateTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

internal data class AndroidCalendarLectureInput(
    val id: String,
    val sourceIds: List<String>,
    val title: String,
    val startMillis: Long,
    val endMillis: Long,
    val location: String?,
    val detail: String?,
) {
    val allSourceIds: List<String>
        get() = (listOf(id) + sourceIds).distinct()
}

internal fun androidCalendarLectureInput(item: Any?): AndroidCalendarLectureInput? {
    val values = item as? Map<*, *> ?: return null
    val title = androidCalendarOptionalString(values["title"]) ?: return null
    val start = androidCalendarParseMillis(
        androidCalendarOptionalString(values["start"]) ?: return null,
    )
    val end = androidCalendarOptionalString(values["end"])
        ?.let(::androidCalendarParseMillis) ?: start + 90 * 60 * 1_000
    val id = androidCalendarOptionalString(values["id"]) ?: "$title-$start"
    val sourceIds = (values["sourceIds"] as? List<*>)
        ?.mapNotNull(::androidCalendarOptionalString)
        .orEmpty()
    return AndroidCalendarLectureInput(
        id = id,
        sourceIds = sourceIds,
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

internal fun androidCalendarOccurrenceId(eventId: Long, beginMillis: Long): String {
    return "$eventId:$beginMillis"
}

internal fun androidCalendarIsoString(millis: Long, allDay: Boolean): String {
    if (!allDay) return Instant.ofEpochMilli(millis).toString()
    // CalendarContract stores all-day boundaries as UTC dates, not timed instants.
    val providerDate = Instant.ofEpochMilli(millis)
        .atZone(ZoneOffset.UTC)
        .toLocalDate()
    return providerDate.atStartOfDay().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
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

internal fun androidCalendarWritableCalendarId(resolver: ContentResolver): Long {
    val selection =
        "${CalendarContract.Calendars.VISIBLE} = 1 AND " +
            "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?"
    val args = arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString())
    resolver.query(
        CalendarContract.Calendars.CONTENT_URI,
        arrayOf(CalendarContract.Calendars._ID),
        selection,
        args,
        null,
    )?.use { cursor ->
        if (cursor.moveToFirst()) {
            return cursor.calendarLongValue(CalendarContract.Calendars._ID)
        }
    }
    throw IllegalStateException("No writable calendar is available.")
}

internal fun Cursor.calendarStringValue(column: String): String? {
    val index = getColumnIndex(column)
    return if (index >= 0 && !isNull(index)) getString(index) else null
}

internal fun Cursor.calendarLongValue(column: String): Long {
    return getLong(getColumnIndexOrThrow(column))
}
