import 'package:flutter/material.dart';

import '../feedback_models.dart';

class FeedbackRatingSummary extends StatelessWidget {
  const FeedbackRatingSummary({required this.snapshot, super.key});

  final FeedbackPublicSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final count = snapshot?.ratingCount ?? 0;
    final average = snapshot?.averageRating;
    return Text(
      count == 0
          ? 'No ratings yet.'
          : '${average?.toStringAsFixed(1) ?? '–'} / 5 from $count ${count == 1 ? 'rating' : 'ratings'}',
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class FeedbackStarSelector extends StatelessWidget {
  const FeedbackStarSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    label: value == 0 ? 'No rating selected' : '$value out of 5 stars selected',
    child: Row(
      children: List<Widget>.generate(5, (index) {
        final rating = index + 1;
        return IconButton(
          tooltip: '$rating ${rating == 1 ? 'star' : 'stars'}',
          onPressed: () => onChanged(rating),
          icon: Icon(
            rating <= value ? Icons.star_rounded : Icons.star_outline_rounded,
            color: rating <= value ? Colors.amber.shade700 : null,
          ),
        );
      }),
    ),
  );
}

class PublishedFeedbackComments extends StatelessWidget {
  const PublishedFeedbackComments({
    required this.comments,
    required this.reportingId,
    required this.onReport,
    super.key,
  });

  final List<PublishedFeedbackComment> comments;
  final String? reportingId;
  final ValueChanged<PublishedFeedbackComment> onReport;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text('Published comments', style: Theme.of(context).textTheme.titleSmall),
      ...comments.map(
        (comment) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(comment.comment),
          subtitle: Text('${comment.rating} / 5 stars'),
          trailing: IconButton(
            tooltip: 'Report comment',
            onPressed: reportingId == null ? () => onReport(comment) : null,
            icon: reportingId == comment.id
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.flag_outlined),
          ),
        ),
      ),
    ],
  );
}
