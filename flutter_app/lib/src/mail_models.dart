class MailApprovalNotice {
  const MailApprovalNotice({required this.title, required this.message});

  final String title;
  final String message;

  Map<String, Object?> toJson() {
    return <String, Object?>{'title': title, 'message': message};
  }
}

class MailMessageSummary {
  const MailMessageSummary({
    required this.uid,
    required this.subject,
    required this.fromName,
    required this.fromAddress,
    required this.receivedAt,
    required this.preview,
    required this.isUnread,
    this.approvalNotice,
  });

  final String uid;
  final String subject;
  final String? fromName;
  final String? fromAddress;
  final String? receivedAt;
  final String? preview;
  final bool isUnread;
  final MailApprovalNotice? approvalNotice;

  String get senderLabel => fromName ?? fromAddress ?? 'Unknown sender';

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'uid': uid,
      'subject': subject,
      'from_name': fromName,
      'from_address': fromAddress,
      'received_at': receivedAt,
      'preview': preview,
      'is_unread': isUnread,
      'is_approved_broadcast': approvalNotice != null,
      if (approvalNotice != null)
        'university_approval_notice': approvalNotice!.toJson(),
    };
  }
}

class MailboxSummary {
  const MailboxSummary({
    required this.name,
    required this.label,
    required this.specialUse,
    required this.messageCount,
    required this.unreadCount,
  });

  final String name;
  final String label;
  final String? specialUse;
  final int? messageCount;
  final int? unreadCount;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'name': name,
      'label': label,
      'special_use': specialUse,
      'message_count': messageCount,
      'unread_count': unreadCount,
    };
  }
}

class MailInboxSummary {
  const MailInboxSummary({
    required this.account,
    required this.mailbox,
    required this.unreadCount,
    required this.messages,
  });

  final String account;
  final String mailbox;
  final int unreadCount;
  final List<MailMessageSummary> messages;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'account': account,
      'mailbox': mailbox,
      'unread_count': unreadCount,
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }
}

class MailMessageDetail extends MailMessageSummary {
  const MailMessageDetail({
    required super.uid,
    required this.mailbox,
    required super.subject,
    required super.fromName,
    required super.fromAddress,
    required this.toRecipients,
    required this.ccRecipients,
    required super.receivedAt,
    required super.preview,
    required this.bodyText,
    required this.attachmentNames,
    required super.isUnread,
    super.approvalNotice,
  });

  final String mailbox;
  final List<String> toRecipients;
  final List<String> ccRecipients;
  final String? bodyText;
  final List<String> attachmentNames;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      ...super.toJson(),
      'mailbox': mailbox,
      'to_recipients': toRecipients,
      'cc_recipients': ccRecipients,
      'body_text': bodyText,
      'attachment_names': attachmentNames,
    };
  }
}

class MailException implements Exception {
  const MailException(this.message);

  final String message;

  @override
  String toString() => message;
}
