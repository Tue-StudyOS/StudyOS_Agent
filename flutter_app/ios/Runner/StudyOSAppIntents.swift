import Foundation

#if canImport(AppIntents)
import AppIntents

@available(iOS 16.0, *)
struct StudyOSLectureEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Lecture"
  static var defaultQuery = StudyOSLectureQuery()

  let id: String
  let title: String
  let start: String
  let location: String?

  var displayRepresentation: DisplayRepresentation {
    let subtitle = location.flatMap { $0.isEmpty ? nil : "\($0) - \(start)" } ?? start
    return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
  }
}

@available(iOS 16.0, *)
struct StudyOSLectureQuery: EntityQuery {
  func entities(for identifiers: [StudyOSLectureEntity.ID]) async throws -> [StudyOSLectureEntity] {
    allLectures().filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [StudyOSLectureEntity] {
    Array(allLectures().prefix(12))
  }

  private func allLectures() -> [StudyOSLectureEntity] {
    let lectures = StudyOSIntentSnapshotStore.shared.readSnapshot()?.lectures ?? []
    return lectures.map {
      StudyOSLectureEntity(
        id: $0.id,
        title: $0.title,
        start: $0.start,
        location: $0.location
      )
    }
  }
}

@available(iOS 16.0, *)
struct AskStudyOSIntent: AppIntent {
  static var title: LocalizedStringResource = "Ask StudyOS"
  static var description = IntentDescription("Open StudyOS with a question ready for the assistant.")
  static var openAppWhenRun = true

  @Parameter(title: "Question")
  var question: String

  init() {}

  init(question: String) {
    self.question = question
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    try StudyOSIntentSnapshotStore.shared.savePendingPrompt(question)
    return .result(dialog: "Opening StudyOS with your question.")
  }
}

@available(iOS 16.0, *)
struct ShowNextLectureIntent: AppIntent {
  static var title: LocalizedStringResource = "Show Next Lecture"
  static var description = IntentDescription("Read the next synced StudyOS timetable entry.")

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let summary = StudyOSIntentSnapshotStore.shared.nextLectureSummary()
    return .result(dialog: "\(summary)")
  }
}

@available(iOS 16.0, *)
struct ShowLectureIntent: AppIntent {
  static var title: LocalizedStringResource = "Show Lecture"
  static var description = IntentDescription("Read one synced StudyOS lecture entry.")

  @Parameter(title: "Lecture")
  var lecture: StudyOSLectureEntity

  init() {}

  init(lecture: StudyOSLectureEntity) {
    self.lecture = lecture
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let locationText = lecture.location.flatMap { $0.isEmpty ? nil : " at \($0)" } ?? ""
    return .result(dialog: "\(lecture.title) starts \(lecture.start)\(locationText).")
  }
}

@available(iOS 16.0, *)
struct SaveStudyMemoryIntent: AppIntent {
  static var title: LocalizedStringResource = "Save Study Memory"
  static var description = IntentDescription("Save a local StudyOS memory note.")

  @Parameter(title: "Memory")
  var memory: String

  init() {}

  init(memory: String) {
    self.memory = memory
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    try StudyOSIntentSnapshotStore.shared.appendMemory(memory)
    return .result(dialog: "Saved to StudyOS memory.")
  }
}

@available(iOS 16.0, *)
struct OpenStudyOSScheduleIntent: AppIntent {
  static var title: LocalizedStringResource = "Open StudyOS Schedule"
  static var description = IntentDescription("Open StudyOS to review the schedule.")
  static var openAppWhenRun = true

  func perform() async throws -> some IntentResult & ProvidesDialog {
    return .result(dialog: "Opening StudyOS schedule.")
  }
}

@available(iOS 16.0, *)
struct StudyOSAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AskStudyOSIntent(),
      phrases: [
        "Ask \(.applicationName)"
      ],
      shortTitle: "Ask StudyOS",
      systemImageName: "sparkles"
    )
    AppShortcut(
      intent: ShowNextLectureIntent(),
      phrases: [
        "What's my next lecture in \(.applicationName)"
      ],
      shortTitle: "Next Lecture",
      systemImageName: "calendar"
    )
    AppShortcut(
      intent: SaveStudyMemoryIntent(),
      phrases: [
        "Remember this in \(.applicationName)"
      ],
      shortTitle: "Save Memory",
      systemImageName: "brain.head.profile"
    )
    AppShortcut(
      intent: OpenStudyOSScheduleIntent(),
      phrases: [
        "Show \(.applicationName) schedule"
      ],
      shortTitle: "Schedule",
      systemImageName: "calendar.day.timeline.left"
    )
  }
}
#endif
