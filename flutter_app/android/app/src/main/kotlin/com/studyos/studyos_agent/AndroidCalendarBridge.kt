package com.studyos.studyos_agent

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager.PERMISSION_GRANTED
import android.provider.CalendarContract
import java.time.ZoneId

class AndroidCalendarBridge(context: Context) {
    private val appContext = context.applicationContext
    private val resolver = appContext.contentResolver
    private val markerPrefix = "StudyOS lecture id:"

    fun canReadCalendar(): Boolean = hasPermission(Manifest.permission.READ_CALENDAR)

    fun canWriteCalendar(): Boolean = hasPermission(Manifest.permission.WRITE_CALENDAR)

    fun listEvents(arguments: Map<*, *>): String {
        requireCalendarPermissions(read = true, write = false)
        val start = androidCalendarMillisArgument(arguments, "start")
        val end = androidCalendarMillisArgument(arguments, "end")
        require(end > start) { "Calendar end must be after start." }
        val limit = androidCalendarIntArgument(arguments, "limit", 25).coerceIn(1, 50)
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, start)
            ContentUris.appendId(it, end)
        }.build()
        val projection = arrayOf(
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.EVENT_LOCATION,
        )
        val events = mutableListOf<String>()
        resolver.query(uri, projection, null, null, "${CalendarContract.Instances.BEGIN} ASC")
            ?.use { cursor ->
                while (cursor.moveToNext() && events.size < limit) {
                    val title = cursor.calendarStringValue(CalendarContract.Instances.TITLE)
                        ?: "Untitled"
                    val begin = cursor.calendarLongValue(CalendarContract.Instances.BEGIN)
                    val finish = cursor.calendarLongValue(CalendarContract.Instances.END)
                    val location = cursor.calendarStringValue(
                        CalendarContract.Instances.EVENT_LOCATION,
                    )
                    events += "- $title, ${androidCalendarDateLabel(begin)}-" +
                        "${androidCalendarTimeLabel(finish)}${androidCalendarLocationSuffix(location)}"
                }
            }
        return if (events.isEmpty()) {
            "No calendar events found in that time window."
        } else {
            events.joinToString("\n")
        }
    }

    fun createEvent(arguments: Map<*, *>): String {
        requireCalendarPermissions(read = true, write = true)
        val title = androidCalendarStringArgument(arguments, "title")
        val start = androidCalendarMillisArgument(arguments, "start")
        val end = androidCalendarMillisArgument(arguments, "end")
        require(end > start) { "Calendar end must be after start." }
        val id = insertEvent(
            calendarId = writableCalendarId(),
            title = title,
            start = start,
            end = end,
            location = androidCalendarOptionalString(arguments["location"]),
            description = androidCalendarOptionalString(arguments["notes"]),
        )
        return "Created calendar event '$title' for ${androidCalendarDateLabel(start)} with id $id."
    }

    fun syncSchedule(arguments: Map<*, *>): String {
        requireCalendarPermissions(read = true, write = true)
        val rawLectures = arguments["lectures"] as? List<*>
            ?: throw IllegalArgumentException("Expected lecture schedule arguments.")
        val sourceTerm = androidCalendarOptionalString(arguments["sourceTerm"]) ?: "ALMA"
        val lectures = rawLectures.mapNotNull(::androidCalendarLectureInput)
        require(lectures.isNotEmpty()) { "No lectures were available to sync." }

        val calendarId = writableCalendarId()
        val minStart = lectures.minOf { it.startMillis } - STUDYOS_CALENDAR_DAY_MILLIS
        val maxEnd = lectures.maxOf { it.endMillis } + STUDYOS_CALENDAR_DAY_MILLIS
        val existingById = existingStudyOsEvents(minStart, maxEnd)
        var created = 0
        var updated = 0

        for (lecture in lectures) {
            val description = lectureNotes(lecture, sourceTerm)
            val existingEventId = existingById[lecture.id]
            if (existingEventId == null) {
                insertEvent(
                    calendarId = calendarId,
                    title = lecture.title,
                    start = lecture.startMillis,
                    end = lecture.endMillis,
                    location = lecture.location,
                    description = description,
                )
                created += 1
            } else {
                updateEvent(
                    eventId = existingEventId,
                    calendarId = calendarId,
                    title = lecture.title,
                    start = lecture.startMillis,
                    end = lecture.endMillis,
                    location = lecture.location,
                    description = description,
                )
                updated += 1
            }
        }

        return "Synced ${lectures.size} lecture events to Calendar ($created new, $updated updated)."
    }

    private fun insertEvent(
        calendarId: Long,
        title: String,
        start: Long,
        end: Long,
        location: String?,
        description: String?,
    ): Long {
        val uri = resolver.insert(
            CalendarContract.Events.CONTENT_URI,
            eventValues(calendarId, title, start, end, location, description),
        ) ?: throw IllegalStateException("Calendar event insert failed.")
        return ContentUris.parseId(uri)
    }

    private fun updateEvent(
        eventId: Long,
        calendarId: Long,
        title: String,
        start: Long,
        end: Long,
        location: String?,
        description: String?,
    ) {
        val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
        val updated = resolver.update(
            uri,
            eventValues(calendarId, title, start, end, location, description),
            null,
            null,
        )
        require(updated > 0) { "Calendar event update failed." }
    }

    private fun eventValues(
        calendarId: Long,
        title: String,
        start: Long,
        end: Long,
        location: String?,
        description: String?,
    ) = ContentValues().apply {
        put(CalendarContract.Events.CALENDAR_ID, calendarId)
        put(CalendarContract.Events.TITLE, title)
        put(CalendarContract.Events.DTSTART, start)
        put(CalendarContract.Events.DTEND, end)
        put(CalendarContract.Events.EVENT_TIMEZONE, ZoneId.systemDefault().id)
        if (location == null) remove(CalendarContract.Events.EVENT_LOCATION) else {
            put(CalendarContract.Events.EVENT_LOCATION, location)
        }
        if (description == null) remove(CalendarContract.Events.DESCRIPTION) else {
            put(CalendarContract.Events.DESCRIPTION, description)
        }
    }

    private fun existingStudyOsEvents(start: Long, end: Long): Map<String, Long> {
        val projection = arrayOf(
            CalendarContract.Events._ID,
            CalendarContract.Events.DESCRIPTION,
        )
        val selection =
            "${CalendarContract.Events.DTSTART} >= ? AND " +
                "${CalendarContract.Events.DTSTART} <= ? AND " +
                "${CalendarContract.Events.DESCRIPTION} LIKE ?"
        val args = arrayOf(start.toString(), end.toString(), "%$markerPrefix%")
        val events = mutableMapOf<String, Long>()
        resolver.query(
            CalendarContract.Events.CONTENT_URI,
            projection,
            selection,
            args,
            "${CalendarContract.Events.DTSTART} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.calendarLongValue(CalendarContract.Events._ID)
                val lectureId = androidCalendarLectureId(
                    cursor.calendarStringValue(CalendarContract.Events.DESCRIPTION),
                    markerPrefix,
                )
                if (lectureId != null) events[lectureId] = id
            }
        }
        return events
    }

    private fun writableCalendarId(): Long {
        val projection = arrayOf(CalendarContract.Calendars._ID)
        val selection =
            "${CalendarContract.Calendars.VISIBLE} = 1 AND " +
                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ?"
        val args = arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString())
        resolver.query(CalendarContract.Calendars.CONTENT_URI, projection, selection, args, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    return cursor.calendarLongValue(CalendarContract.Calendars._ID)
                }
            }
        throw IllegalStateException("No writable calendar is available.")
    }

    private fun lectureNotes(
        lecture: AndroidCalendarLectureInput,
        sourceTerm: String,
    ): String {
        return listOfNotNull(
            "$markerPrefix ${lecture.id}",
            "StudyOS term: $sourceTerm",
            lecture.detail?.let { "\n$it" },
        ).joinToString("\n")
    }

    private fun requireCalendarPermissions(read: Boolean, write: Boolean) {
        if (read && !canReadCalendar()) {
            throw SecurityException("Calendar read permission is required.")
        }
        if (write && !canWriteCalendar()) {
            throw SecurityException("Calendar write permission is required.")
        }
    }

    private fun hasPermission(permission: String): Boolean {
        return appContext.checkSelfPermission(permission) == PERMISSION_GRANTED
    }

}
