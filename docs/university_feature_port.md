# University Feature Port Notes

## Sources Checked

- `lecture-pilot` login delegates to `tue-api-wrapper` and turns ALMA timetable
  assignments into course cards.
- `tue-api-wrapper` has Python, Swift/iOS, Next.js, ChatGPT, and MCP surfaces
  for ALMA, ILIAS, Moodle, mail, campus food, campus seats, TIMMS, and course
  discovery.
- The wrapper iOS app stores university credentials in Keychain, refreshes
  upcoming lectures, caches a lecture snapshot for widgets, fetches ILIAS tasks
  and Moodle deadlines on device, and exposes Today, Schedule, Study, Inbox,
  and Discover tabs.

## Live Contract Notes

- ALMA study planner title currently returns a title shaped like
  `Studienplaner Master Informatik / Computer Science (H-2021-7) - Eberhard Karls Universität Tübingen`.
- Timetable controls expose available terms, with `Sommer 2026` selected in the
  live account tested locally.
- `current_lectures` is a public/current-day ALMA surface and can return broad
  university-wide lectures, not only the student's personal schedule.
- `study_planner` returns the degree title plus semester rows and module
  progress including credits.
- `enrollments` returns registered/cancelled course rows with schedule text.
- ILIAS tasks and Moodle deadlines can validly return empty lists.
- A confirmed canonical email source was not found in these code paths. Mail
  login uses the ZDV ID account; do not guess an email domain.

## Port Sequence

1. Keep login native to the Flutter app and store credentials with platform
   secure storage.
2. Replace ad hoc ALMA parsing with a small StudyOS university data layer that
   mirrors the proven wrapper contracts: profile, study planner, timetable,
   enrollments, tasks, deadlines.
3. Add a Schedule view backed by the student's ALMA timetable/enrollments, not
   the public current-lectures page.
4. Add tool catalog entries for `get_schedule`, `get_tasks`, `get_deadlines`,
   and `get_study_planner`; implement them for cloud and iOS local where tool
   calling is available.
5. Inject only compact profile and memory by default. Let the agent call tools
   for schedule/tasks/deadlines so responses stay grounded and traceable.
6. Port high-signal app surfaces after schedule/tasks are stable: campus seats,
   mensa, mail inbox summary, credits/progress, and live lecture reminders.
7. Add native surfaces after the data layer is reliable: a Today home-screen
   widget, a lecture Live Activity, and deadline notifications. Prefer schedule
   and deadline alerts over room-change alerts unless a reliable source appears;
   rooms are more likely to change through email than through ALMA.
8. Expose only high-value native action tools to the agent: create calendar
   events, create reminders/notifications, open maps, and draft email. Avoid
   low-value tools such as `refresh_schedule` or `open_course` unless real usage
   shows they save meaningful work.
9. Consider opt-in location-aware campus nudges once mensa/campus data is
   cached locally: when the user is near a Mensa, surface today's meal details or
   favorite dishes; when near campus facilities, surface relevant capacity or
   opening-hour context. These should be quiet, thresholded, and permission-gated
   so they provide value without feeling like tracking or spam.
10. Add campus credential quick access such as scanning/storing a KuF card. Keep
    setup in Settings with secure local storage and expose only a compact Home
    shortcut once configured, so the card is useful without taking over the main
    app navigation.
11. Add feedback without a database or GitHub account requirement for students.
    The app creates GitHub issues directly with a user-provided fine-grained
    token for `Tue-StudyOS/StudyOS_Agent` with `Issues: write`; store that token
    in platform secure storage and never hardcode it in the mobile binary.

## UX Shape

- Chat remains the agent surface.
- Memories remains the editable long-term memory document.
- Schedule should be a first-class view with upcoming lectures, rooms, and
  refresh state.
- Tasks should show ILIAS tasks plus Moodle deadlines together.
- Settings should own credentials, provider settings, and sync status.
- The Chat view should feel dedicated: no bottom navigation while chatting, a
  burger menu for sessions, a drawer action back to Home, and a header action for
  starting a new empty chat.
- Campus credentials such as KuF card access should live in Settings first, then
  appear as compact Home quick actions after setup.
