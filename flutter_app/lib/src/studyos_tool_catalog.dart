import 'native_tool_router.dart';

class StudyOsToolSpec {
  const StudyOsToolSpec({
    required this.name,
    required this.description,
    required this.traceSummary,
    required this.properties,
    required this.required,
  });

  final String name;
  final String description;
  final String traceSummary;
  final Map<String, Object?> properties;
  final List<String> required;
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

const studyOsTools = <StudyOsToolSpec>[
  appendMemoryTool,
  readMemoriesTool,
  getStudyContextTool,
  getScheduleTool,
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
];

StudyOsToolSpec? studyOsToolByName(String name) {
  for (final tool in studyOsTools) {
    if (tool.name == name) return tool;
  }
  return null;
}
