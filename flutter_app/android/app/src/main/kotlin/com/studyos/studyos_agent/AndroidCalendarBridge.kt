package com.studyostue.app

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
        val events = queryEvents(arguments, maximumLimit = 50)
        return if (events.isEmpty()) {
            "No calendar events found in that time window."
        } else {
            events.joinToString("\n") { event ->
                val begin = androidCalendarParseMillis(event.getValue("start").toString())
                val finish = androidCalendarParseMillis(event.getValue("end").toString())
                val location = androidCalendarOptionalString(event["location"])
                "- ${event["title"]}, ${androidCalendarDateLabel(begin)}-" +
                    "${androidCalendarTimeLabel(finish)}" +
                    androidCalendarLocationSuffix(location)
            }
        }
    }

    fun listStructuredEvents(arguments: Map<*, *>): List<Map<String, Any?>> {
        return queryEvents(arguments, maximumLimit = 500)
    }

    private fun queryEvents(
        arguments: Map<*, *>,
        maximumLimit: Int,
    ): List<Map<String, Any?>> {
        requireCalendarPermissions(read = true, write = false)
        val start = androidCalendarMillisArgument(arguments, "start")
        val end = androidCalendarMillisArgument(arguments, "end")
        require(end > start) { "Calendar end must be after start." }
        val limit = androidCalendarIntArgument(arguments, "limit", 25)
            .coerceIn(1, maximumLimit)
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, start)
            ContentUris.appendId(it, end)
        }.build()
        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.DESCRIPTION,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
            CalendarContract.Instances.ALL_DAY,
        )
        val events = mutableListOf<Map<String, Any?>>()
        resolver.query(uri, projection, null, null, "${CalendarContract.Instances.BEGIN} ASC")
            ?.use { cursor ->
                while (cursor.moveToNext() && events.size < limit) {
                    val title = cursor.calendarStringValue(CalendarContract.Instances.TITLE)
                        ?: "Untitled"
                    val eventId = cursor.calendarLongValue(CalendarContract.Instances.EVENT_ID)
                    val begin = cursor.calendarLongValue(CalendarContract.Instances.BEGIN)
                    val finish = cursor.calendarLongValue(CalendarContract.Instances.END)
                    val allDay =
                        cursor.calendarLongValue(CalendarContract.Instances.ALL_DAY) != 0L
                    events += mapOf(
                        "id" to androidCalendarOccurrenceId(eventId, begin),
                        "title" to title,
                        "start" to androidCalendarIsoString(begin, allDay),
                        "end" to androidCalendarIsoString(finish, allDay),
                        "location" to cursor.calendarStringValue(
                            CalendarContract.Instances.EVENT_LOCATION,
                        ),
                        "notes" to cursor.calendarStringValue(
                            CalendarContract.Instances.DESCRIPTION,
                        ),
                        "calendarName" to (
                            cursor.calendarStringValue(
                                CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
                            ) ?: "Calendar"
                        ),
                        "allDay" to allDay,
                    )
                }
            }
        return events
    }

    fun createEvent(arguments: Map<*, *>): String {
        requireCalendarPermissions(read = true, write = true)
        val title = androidCalendarStringArgument(arguments, "title")
        val start = androidCalendarMillisArgument(arguments, "start")
        val end = androidCalendarMillisArgument(arguments, "end")
        require(end > start) { "Calendar end must be after start." }
        val id = insertEvent(
            calendarId = androidCalendarWritableCalendarId(resolver),
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
        val windowStart = androidCalendarMillisArgument(arguments, "windowStart")
        val windowEnd = androidCalendarMillisArgument(arguments, "windowEnd")
        require(windowEnd > windowStart) { "Calendar sync window end must be after start." }
        val sourceTerm = androidCalendarOptionalString(arguments["sourceTerm"]) ?: "ALMA"
        val lectures = rawLectures.mapNotNull(::androidCalendarLectureInput)
        require(lectures.size == rawLectures.size) { "One or more lectures were invalid." }

        val calendarId = androidCalendarWritableCalendarId(resolver)
        val existingById = existingStudyOsEvents(windowStart, windowEnd)
        var created = 0
        var updated = 0
        var removed = 0
        val activeSourceIds = lectures.flatMap { it.allSourceIds }.toSet()

        for ((sourceId, eventIds) in existingById) {
            if (sourceId in activeSourceIds) continue
            for (eventId in eventIds) {
                removed += deleteEvent(eventId)
            }
        }

        for (lecture in lectures) {
            val description = lectureNotes(lecture, sourceTerm)
            val existingEventIds = lecture.allSourceIds
                .flatMap { existingById[it].orEmpty() }
                .distinct()
            val existingEventId = existingById[lecture.id]?.firstOrNull()
                ?: existingEventIds.firstOrNull()
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
                    title = lecture.title,
                    start = lecture.startMillis,
                    end = lecture.endMillis,
                    location = lecture.location,
                    description = description,
                )
                updated += 1
            }
            for (duplicateId in existingEventIds.filter { it != existingEventId }) {
                removed += deleteEvent(duplicateId)
            }
        }

        val cleanup = if (removed == 0) "" else ", $removed managed events removed"
        return "Synced ${lectures.size} lecture events to Calendar " +
            "($created new, $updated updated$cleanup)."
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
        title: String,
        start: Long,
        end: Long,
        location: String?,
        description: String?,
    ) {
        val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
        val updated = resolver.update(
            uri,
            eventValues(null, title, start, end, location, description),
            null,
            null,
        )
        require(updated > 0) { "Calendar event update failed." }
    }

    private fun deleteEvent(eventId: Long): Int {
        val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
        return if (resolver.delete(uri, null, null) > 0) 1 else 0
    }

    private fun eventValues(
        calendarId: Long?,
        title: String,
        start: Long,
        end: Long,
        location: String?,
        description: String?,
    ) = ContentValues().apply {
        if (calendarId != null) put(CalendarContract.Events.CALENDAR_ID, calendarId)
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

    private fun existingStudyOsEvents(
        start: Long,
        end: Long,
    ): Map<String, List<Long>> {
        val projection = arrayOf(
            CalendarContract.Events._ID,
            CalendarContract.Events.DESCRIPTION,
        )
        val selection =
            "${CalendarContract.Events.DTSTART} <= ? AND " +
                "${CalendarContract.Events.DTEND} >= ? AND " +
                "${CalendarContract.Events.DESCRIPTION} LIKE ?"
        val args = arrayOf(
            end.toString(),
            start.toString(),
            "%$markerPrefix%",
        )
        val events = mutableMapOf<String, MutableList<Long>>()
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
                if (lectureId != null) events.getOrPut(lectureId, ::mutableListOf).add(id)
            }
        }
        return events
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
