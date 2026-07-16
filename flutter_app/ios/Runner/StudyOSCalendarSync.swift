import EventKit
import Foundation

func studyOSSyncLectures(
  in eventStore: EKEventStore,
  calendar: EKCalendar,
  lectures: [StudyOSCalendarLecture],
  sourceTerm: String,
  markerPrefix: String,
  windowStart: Date,
  windowEnd: Date
) throws -> String {
  let predicate = eventStore.predicateForEvents(
    withStart: windowStart,
    end: windowEnd,
    calendars: nil
  )
  var existingById: [String: [EKEvent]] = [:]
  for event in eventStore.events(matching: predicate) {
    if let id = studyOSCalendarLectureId(
      in: event.notes,
      markerPrefix: markerPrefix
    ) {
      existingById[id, default: []].append(event)
    }
  }

  var removed = 0
  let activeSourceIds = Set(lectures.flatMap(\.allSourceIds))
  for (sourceId, events) in existingById where !activeSourceIds.contains(sourceId) {
    for event in events {
      try eventStore.remove(event, span: .thisEvent, commit: true)
      removed += 1
    }
  }

  var created = 0
  var updated = 0
  for lecture in lectures {
    let existing = lecture.allSourceIds.flatMap { existingById[$0] ?? [] }
    let event = existing.first {
      studyOSCalendarLectureId(in: $0.notes, markerPrefix: markerPrefix) == lecture.id
    } ?? existing.first ?? EKEvent(eventStore: eventStore)
    if existing.isEmpty {
      event.calendar = calendar
      created += 1
    } else {
      updated += 1
    }
    for duplicate in existing where duplicate !== event {
      try eventStore.remove(duplicate, span: .thisEvent, commit: true)
      removed += 1
    }
    event.title = lecture.title
    event.startDate = lecture.start
    event.endDate = lecture.end
    event.location = lecture.location
    event.notes = studyOSCalendarLectureNotes(
      lecture,
      sourceTerm: sourceTerm,
      markerPrefix: markerPrefix
    )
    try eventStore.save(event, span: .thisEvent)
  }

  let cleanup = removed == 0 ? "" : ", \(removed) managed events removed"
  return "Synced \(lectures.count) lecture events to \(calendar.title) (\(created) new, \(updated) updated\(cleanup))."
}
