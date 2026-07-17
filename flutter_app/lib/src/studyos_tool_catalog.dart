import 'native_tool_router.dart';
import 'private_study_tools.dart';
import 'public_study_tools.dart';

class StudyOsToolSpec {
  const StudyOsToolSpec({
    required this.name,
    required this.description,
    required this.traceSummary,
    required this.properties,
    required this.required,
    this.cloudAllowed = true,
  });

  final String name;
  final String description;
  final String traceSummary;
  final Map<String, Object?> properties;
  final List<String> required;
  final bool cloudAllowed;
}

const appendMemoryTool = StudyOsToolSpec(
  name: 'append_memory',
  description: 'Append a durable student memory to local device storage.',
  traceSummary: 'Writing a durable student memory on this device.',
  properties: <String, Object?>{
    'text': <String, Object?>{
      'type': 'string',
      'description': 'A concise memory worth keeping for future chats.',
    },
  },
  required: <String>['text'],
);

const readMemoriesTool = StudyOsToolSpec(
  name: 'read_memories',
  description: 'Read the local long-term memory document.',
  traceSummary: 'Reading the local memory document.',
  properties: <String, Object?>{},
  required: <String>[],
);

const getStudyContextTool = StudyOsToolSpec(
  name: 'get_study_context',
  description: 'Read current profile, memory, and local study context.',
  traceSummary: 'Reading profile, memory, and device context.',
  properties: <String, Object?>{},
  required: <String>[],
);

const getScheduleTool = StudyOsToolSpec(
  name: 'get_schedule',
  description: 'Read the locally cached ALMA timetable and upcoming lectures.',
  traceSummary: 'Reading the cached ALMA timetable.',
  properties: <String, Object?>{},
  required: <String>[],
);

const getAcademicStatusTool = StudyOsToolSpec(
  name: 'get_academic_status',
  description:
      'Read the latest ALMA course and exam registration overview. This is read-only and may indicate when the official registration report should be checked.',
  traceSummary: 'Reading your ALMA academic status.',
  properties: <String, Object?>{},
  required: <String>[],
);

const searchTalksTool = StudyOsToolSpec(
  name: 'search_talks',
  description:
      'List or search upcoming public Tübingen talks by topic, speaker, or location.',
  traceSummary: 'Searching the live Tübingen talks calendar.',
  properties: <String, Object?>{
    'query': <String, Object?>{
      'type': 'string',
      'description': 'Optional topic, speaker, or location search.',
    },
    'limit': <String, Object?>{
      'type': 'integer',
      'description': 'Maximum talks to return. Capped at 20.',
    },
  },
  required: <String>[],
);

const getMensaOptionsTool = StudyOsToolSpec(
  name: getMensaOptionsToolName,
  description:
      'Get live Tübingen Mensa meal options, optionally filtered by date, canteen, and dietary preference.',
  traceSummary: 'Loading live Tübingen Mensa options.',
  properties: <String, Object?>{
    'date': <String, Object?>{
      'type': 'string',
      'description': 'Optional date in YYYY-MM-DD format.',
    },
    'canteen': <String, Object?>{
      'type': 'string',
      'description': 'Optional canteen ID or name filter.',
    },
    'preference': <String, Object?>{
      'type': 'string',
      'enum': <String>['any', 'vegetarian', 'vegan'],
      'description': 'Optional dietary filter. Defaults to any.',
    },
    'limit': <String, Object?>{
      'type': 'integer',
      'description': 'Maximum menu entries to return. Capped at 30.',
    },
  },
  required: <String>[],
);

const searchCampusLocationsTool = StudyOsToolSpec(
  name: searchCampusLocationsToolName,
  description:
      'Search public OpenStreetMap place data bounded to Tübingen without using the device location.',
  traceSummary: 'Searching public Tübingen campus locations.',
  properties: <String, Object?>{
    'query': <String, Object?>{
      'type': 'string',
      'description': 'Campus building, facility, street, or place to find.',
    },
    'limit': <String, Object?>{
      'type': 'integer',
      'description': 'Maximum locations to return. Capped at 8.',
    },
  },
  required: <String>['query'],
);

const getTasksTool = StudyOsToolSpec(
  name: getTasksToolName,
  description:
      'Read private ILIAS and Moodle tasks locally. Results never leave the device through cloud tools.',
  traceSummary: 'Loading local ILIAS and Moodle tasks.',
  properties: <String, Object?>{
    'sources': <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': 'string',
        'enum': <String>['ilias', 'moodle'],
      },
      'description': 'Optional portal subset; defaults to both.',
    },
    'limit': <String, Object?>{
      'type': 'integer',
      'description': 'Maximum tasks to return. Capped at 50.',
    },
  },
  required: <String>[],
  cloudAllowed: false,
);

const getDeadlinesTool = StudyOsToolSpec(
  name: getDeadlinesToolName,
  description:
      'Read confirmed private ILIAS and Moodle deadlines locally within a bounded window.',
  traceSummary: 'Loading local ILIAS and Moodle deadlines.',
  properties: <String, Object?>{
    'days': <String, Object?>{
      'type': 'integer',
      'description': 'Upcoming window in days, from 1 to 180. Defaults to 30.',
    },
    'sources': <String, Object?>{
      'type': 'array',
      'items': <String, Object?>{
        'type': 'string',
        'enum': <String>['ilias', 'moodle'],
      },
      'description': 'Optional portal subset; defaults to both.',
    },
    'limit': <String, Object?>{
      'type': 'integer',
      'description': 'Maximum deadlines to return. Capped at 100.',
    },
  },
  required: <String>[],
  cloudAllowed: false,
);

const listMailboxesTool = StudyOsToolSpec(
  name: 'list_mailboxes',
  description: 'List local university mail folders and unread counts.',
  traceSummary: 'Listing local university mailboxes.',
  properties: <String, Object?>{},
  required: <String>[],
);

const getRecentMailTool = StudyOsToolSpec(
  name: 'get_recent_mail',
  description: 'Read recent university mail summaries without full bodies.',
  traceSummary: 'Reading recent university mail summaries.',
  properties: <String, Object?>{
    'mailbox': <String, Object?>{
      'type': 'string',
      'description': 'Mailbox name such as INBOX.',
    },
    'limit': <String, Object?>{
      'type': 'integer',
      'description': 'Maximum summaries to return. Capped at 10.',
    },
    'unread_only': <String, Object?>{
      'type': 'boolean',
      'description': 'Only return unread messages.',
    },
  },
  required: <String>[],
);

const searchMailTool = StudyOsToolSpec(
  name: 'search_mail',
  description:
      'Search recent university mail summaries by text, sender, mailbox, and unread state.',
  traceSummary: 'Searching university mail summaries.',
  properties: <String, Object?>{
    'query': <String, Object?>{
      'type': 'string',
      'description': 'Subject, preview, or keyword search.',
    },
    'sender': <String, Object?>{
      'type': 'string',
      'description': 'Sender name or address filter.',
    },
    'mailbox': <String, Object?>{
      'type': 'string',
      'description': 'Mailbox name such as INBOX.',
    },
    'since': <String, Object?>{
      'type': 'string',
      'description': 'Optional lower date bound, for example 2026-06-16.',
    },
    'unread_only': <String, Object?>{'type': 'boolean'},
    'limit': <String, Object?>{
      'type': 'integer',
      'description': 'Maximum summaries to return. Capped at 10.',
    },
    'scan_limit': <String, Object?>{
      'type': 'integer',
      'description': 'Recent messages to scan. Capped at 300.',
    },
  },
  required: <String>[],
);

const getMailMessageTool = StudyOsToolSpec(
  name: 'get_mail_message',
  description:
      'Read one university mail body by mailbox and UID after the user asks for the message content.',
  traceSummary: 'Reading one university mail message.',
  properties: <String, Object?>{
    'uid': <String, Object?>{
      'type': 'string',
      'description': 'IMAP UID from a mail summary result.',
    },
    'mailbox': <String, Object?>{
      'type': 'string',
      'description': 'Mailbox containing the UID.',
    },
  },
  required: <String>['uid'],
);

const findMailDeadlinesTool = StudyOsToolSpec(
  name: 'find_mail_deadlines',
  description:
      'Heuristically find deadline-like mentions in recent university mail summaries.',
  traceSummary: 'Looking for deadline mentions in university mail.',
  properties: <String, Object?>{
    'query': <String, Object?>{
      'type': 'string',
      'description': 'Optional keyword such as exam, deadline, or course name.',
    },
    'sender': <String, Object?>{'type': 'string'},
    'mailbox': <String, Object?>{'type': 'string'},
    'since': <String, Object?>{'type': 'string'},
    'limit': <String, Object?>{'type': 'integer'},
    'scan_limit': <String, Object?>{'type': 'integer'},
  },
  required: <String>[],
);

const getDeviceStatusTool = StudyOsToolSpec(
  name: nativeDeviceStatusToolName,
  description:
      'Read native device status when the platform supports this local action.',
  traceSummary: 'Reading native device status.',
  properties: <String, Object?>{},
  required: <String>[],
);

const setFlashlightTool = StudyOsToolSpec(
  name: nativeSetFlashlightToolName,
  description:
      'Turn the device flashlight on or off when the platform allows it.',
  traceSummary: 'Setting the native flashlight state.',
  properties: <String, Object?>{
    'enabled': <String, Object?>{
      'type': 'boolean',
      'description': 'True to turn the flashlight on, false to turn it off.',
    },
  },
  required: <String>['enabled'],
);

const openInstalledAppTool = StudyOsToolSpec(
  name: nativeOpenInstalledAppToolName,
  description:
      'Open an installed Android app by display name after the user asks for it.',
  traceSummary: 'Opening an installed app.',
  properties: <String, Object?>{
    'name': <String, Object?>{
      'type': 'string',
      'description': 'Display name of the app to open.',
    },
  },
  required: <String>['name'],
);

const searchYoutubeTool = StudyOsToolSpec(
  name: nativeSearchYoutubeToolName,
  description: 'Open YouTube search results for a user-requested query.',
  traceSummary: 'Opening YouTube search.',
  properties: <String, Object?>{
    'query': <String, Object?>{
      'type': 'string',
      'description': 'Search query to open in YouTube or the browser.',
    },
  },
  required: <String>['query'],
);

const openSystemSettingTool = StudyOsToolSpec(
  name: nativeOpenSystemSettingToolName,
  description:
      'Open a native settings panel for Wi-Fi, Bluetooth, location, or mobile data; does not claim direct toggle control.',
  traceSummary: 'Opening a native settings panel.',
  properties: <String, Object?>{
    'setting': <String, Object?>{
      'type': 'string',
      'enum': <String>['wifi', 'bluetooth', 'location', 'mobile_data'],
      'description': 'The settings panel to open.',
    },
  },
  required: <String>['setting'],
);

const createReminderTool = StudyOsToolSpec(
  name: nativeCreateReminderToolName,
  description:
      'Create a local reminder from an ISO-8601 timestamp. Android supports reminders, alarms, and morning routines where permitted; iOS supports one-time reminder notifications.',
  traceSummary: 'Creating a native reminder.',
  properties: <String, Object?>{
    'title': <String, Object?>{
      'type': 'string',
      'description': 'Short reminder title shown to the user.',
    },
    'time': <String, Object?>{
      'type': 'string',
      'description':
          'ISO-8601 timestamp for the reminder, for example 2026-06-24T18:30:00+02:00.',
    },
    'type': <String, Object?>{
      'type': 'string',
      'enum': <String>['REMINDER', 'ALARM', 'MORNING_ROUTINE'],
      'description': 'Optional Android reminder type. Defaults to REMINDER.',
    },
    'repeat': <String, Object?>{
      'type': 'string',
      'enum': <String>['ONCE', 'DAILY', 'WEEKLY'],
      'description': 'Optional repeat cadence. Defaults to ONCE.',
    },
  },
  required: <String>['title', 'time'],
);

const listCalendarEventsTool = StudyOsToolSpec(
  name: nativeListCalendarEventsToolName,
  description:
      'List native calendar events in an ISO-8601 time window after the user asks to inspect their calendar.',
  traceSummary: 'Reading native calendar events.',
  properties: <String, Object?>{
    'start': <String, Object?>{
      'type': 'string',
      'description':
          'Inclusive ISO-8601 window start, for example 2026-07-10T08:00:00+02:00.',
    },
    'end': <String, Object?>{
      'type': 'string',
      'description':
          'Exclusive ISO-8601 window end, for example 2026-07-10T18:00:00+02:00.',
    },
    'limit': <String, Object?>{
      'type': 'integer',
      'description': 'Maximum events to return. Capped at 50.',
    },
  },
  required: <String>['start', 'end'],
);

const createCalendarEventTool = StudyOsToolSpec(
  name: nativeCreateCalendarEventToolName,
  description:
      'Create a native calendar event after the user asks or confirms the event details.',
  traceSummary: 'Creating a native calendar event.',
  properties: <String, Object?>{
    'title': <String, Object?>{
      'type': 'string',
      'description': 'Calendar event title.',
    },
    'start': <String, Object?>{
      'type': 'string',
      'description':
          'ISO-8601 event start, for example 2026-07-10T14:00:00+02:00.',
    },
    'end': <String, Object?>{
      'type': 'string',
      'description':
          'ISO-8601 event end, for example 2026-07-10T16:00:00+02:00.',
    },
    'location': <String, Object?>{
      'type': 'string',
      'description': 'Optional event location.',
    },
    'notes': <String, Object?>{
      'type': 'string',
      'description': 'Optional event notes.',
    },
  },
  required: <String>['title', 'start', 'end'],
);

const studyOsTools = <StudyOsToolSpec>[
  appendMemoryTool,
  readMemoriesTool,
  getStudyContextTool,
  getScheduleTool,
  getAcademicStatusTool,
  searchTalksTool,
  getMensaOptionsTool,
  searchCampusLocationsTool,
  getTasksTool,
  getDeadlinesTool,
  listMailboxesTool,
  getRecentMailTool,
  searchMailTool,
  getMailMessageTool,
  findMailDeadlinesTool,
  getDeviceStatusTool,
  setFlashlightTool,
  openInstalledAppTool,
  searchYoutubeTool,
  openSystemSettingTool,
  createReminderTool,
  listCalendarEventsTool,
  createCalendarEventTool,
];

List<StudyOsToolSpec> studyOsToolsForNativeSupport(
  Set<String> supportedNativeToolNames,
) {
  return studyOsTools
      .where(
        (tool) =>
            !activeNativeToolNames.contains(tool.name) ||
            supportedNativeToolNames.contains(tool.name),
      )
      .toList();
}

List<StudyOsToolSpec> cloudStudyOsTools(Set<String> supportedNativeToolNames) =>
    studyOsToolsForNativeSupport(
      supportedNativeToolNames,
    ).where((tool) => tool.cloudAllowed).toList(growable: false);

StudyOsToolSpec? studyOsToolByName(String name) {
  for (final tool in studyOsTools) {
    if (tool.name == name) return tool;
  }
  return null;
}
