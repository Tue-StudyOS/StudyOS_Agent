class FeedbackSubmission {
  const FeedbackSubmission({
    required this.id,
    required this.serviceId,
    required this.rating,
    required this.comment,
    required this.commentState,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String serviceId;
  final int rating;
  final String? comment;
  final String commentState;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get commentIsPending => commentState == 'pending';

  String? get commentStatusMessage => switch (commentState) {
    'pending' => 'Your comment is awaiting moderator review.',
    'published' => 'Your comment is published.',
    'rejected' => 'Your comment was not published after review.',
    'deleted' => 'Your comment was removed; your rating is still counted.',
    _ => null,
  };

  factory FeedbackSubmission.fromJson(Map<String, Object?> json) {
    return FeedbackSubmission(
      id: json['id']?.toString() ?? '',
      serviceId: json['service_id']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: _optionalText(json['comment']),
      commentState: json['comment_state']?.toString() ?? 'none',
      createdAt: _dateTime(json['created_at']),
      updatedAt: _dateTime(json['updated_at']),
    );
  }
}

class PublishedFeedbackComment {
  const PublishedFeedbackComment({
    required this.id,
    required this.rating,
    required this.comment,
    required this.publishedAt,
  });

  final String id;
  final int rating;
  final String comment;
  final DateTime publishedAt;

  factory PublishedFeedbackComment.fromJson(Map<String, Object?> json) {
    return PublishedFeedbackComment(
      id: json['id']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment']?.toString() ?? '',
      publishedAt: _dateTime(json['published_at']),
    );
  }
}

class FeedbackPublicSnapshot {
  const FeedbackPublicSnapshot({
    required this.serviceId,
    required this.ratingCount,
    required this.averageRating,
    required this.comments,
  });

  const FeedbackPublicSnapshot.empty(String serviceId)
    : this(
        serviceId: serviceId,
        ratingCount: 0,
        averageRating: null,
        comments: const <PublishedFeedbackComment>[],
      );

  final String serviceId;
  final int ratingCount;
  final double? averageRating;
  final List<PublishedFeedbackComment> comments;

  factory FeedbackPublicSnapshot.fromJson(Map<String, Object?> json) {
    final rawRating = json['rating'];
    final rating = rawRating is Map
        ? Map<String, Object?>.from(rawRating)
        : const <String, Object?>{};
    final rawComments = json['comments'];
    return FeedbackPublicSnapshot(
      serviceId: json['service_id']?.toString() ?? '',
      ratingCount: (rating['count'] as num?)?.toInt() ?? 0,
      averageRating: (rating['average'] as num?)?.toDouble(),
      comments: rawComments is List
          ? rawComments
                .whereType<Map>()
                .map(
                  (item) => PublishedFeedbackComment.fromJson(
                    Map<String, Object?>.from(item),
                  ),
                )
                .where((item) => item.id.isNotEmpty && item.comment.isNotEmpty)
                .toList(growable: false)
          : const <PublishedFeedbackComment>[],
    );
  }
}

String? _optionalText(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

DateTime _dateTime(Object? value) {
  return DateTime.tryParse(value?.toString() ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
