import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';
import 'feed_detail_sheet.dart';

class ProactiveFeedSection extends StatelessWidget {
  const ProactiveFeedSection({
    required this.snapshot,
    required this.onRefresh,
    required this.onAskAssistant,
    super.key,
  });

  final HomeFeedSnapshot snapshot;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onAskAssistant;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.text.withValues(alpha: 0.045),
      borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'For you',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 28,
                height: 1.05,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: StudyOsSpacing.sm),
            _AssistantBrief(brief: snapshot.assistantBrief),
            const SizedBox(height: StudyOsSpacing.lg),
            _FeedSectionTitle(
              title: 'Today’s Schedule',
              trailing: snapshot.isStale ? 'stale' : snapshot.generatedAtLabel,
            ),
            const SizedBox(height: StudyOsSpacing.sm),
            _ScheduleSection(
              items: snapshot.todaySchedule,
              onAskAssistant: onAskAssistant,
            ),
            const SizedBox(height: StudyOsSpacing.xl),
            const _FeedSectionTitle(title: 'Highlights Tübingen'),
            const SizedBox(height: StudyOsSpacing.sm),
            _ArticleSection(
              articles: snapshot.highlights,
              emptyText: 'News could not be loaded.',
              onAskAssistant: onAskAssistant,
            ),
            const SizedBox(height: StudyOsSpacing.xl),
            const _FeedSectionTitle(title: 'Emails'),
            const SizedBox(height: StudyOsSpacing.sm),
            _EmailSection(
              emails: snapshot.emails,
              onRefresh: onRefresh,
              onAskAssistant: onAskAssistant,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantBrief extends StatelessWidget {
  const _AssistantBrief({required this.brief});

  final ForYouAssistantBrief brief;

  @override
  Widget build(BuildContext context) {
    final llmText = brief.llmSummary?.trim();
    final text = llmText == null || llmText.isEmpty ? brief.text : llmText;

    return Row(
      children: <Widget>[
        Icon(
          brief.isGenerating
              ? Icons.auto_awesome_outlined
              : Icons.check_circle_outline_rounded,
          color: StudyOsColors.accent,
          size: 18,
        ),
        const SizedBox(width: StudyOsSpacing.sm),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: StudyOsColors.text,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedSectionTitle extends StatelessWidget {
  const _FeedSectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: StudyOsColors.textMuted,
              fontSize: 13,
            ),
          ),
      ],
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({required this.items, required this.onAskAssistant});

  final List<FeedScheduleCard> items;
  final ValueChanged<String> onAskAssistant;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyDayText();
    }
    final visibleItems = items.take(1);
    return Column(
      children: <Widget>[
        for (final item in visibleItems) ...<Widget>[
          _ScheduleTile(item: item, onAskAssistant: onAskAssistant),
          const SizedBox(height: StudyOsSpacing.sm),
        ],
      ],
    );
  }
}

class _EmptyDayText extends StatelessWidget {
  const _EmptyDayText();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        'No lectures today, have a great day',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 24,
          height: 1.1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({required this.item, required this.onAskAssistant});

  final FeedScheduleCard item;
  final ValueChanged<String> onAskAssistant;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.text.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(StudyOsRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        onTap: () => showScheduleFeedDetails(context, item, onAskAssistant),
        child: Padding(
          padding: const EdgeInsets.all(StudyOsSpacing.md),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (item.type != null) ...<Widget>[
                const SizedBox(width: StudyOsSpacing.sm),
                _CompactPill(label: item.type!),
              ],
              const SizedBox(width: StudyOsSpacing.sm),
              Text(
                item.timeToNextLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: StudyOsColors.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArticleSection extends StatelessWidget {
  const _ArticleSection({
    required this.articles,
    required this.emptyText,
    required this.onAskAssistant,
  });

  final List<FeedArticleCard> articles;
  final String emptyText;
  final ValueChanged<String> onAskAssistant;

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return _UnavailableText(text: emptyText);
    }
    return Column(
      children: <Widget>[
        for (final article in articles) ...<Widget>[
          _ArticleTile(article: article, onAskAssistant: onAskAssistant),
          const SizedBox(height: StudyOsSpacing.sm),
        ],
      ],
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({required this.article, required this.onAskAssistant});

  final FeedArticleCard article;
  final ValueChanged<String> onAskAssistant;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.surface,
      borderRadius: BorderRadius.circular(StudyOsRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        onTap: () => showArticleFeedDetails(context, article, onAskAssistant),
        child: Padding(
          padding: const EdgeInsets.all(StudyOsSpacing.md),
          child: Row(
            children: <Widget>[
              _ArticleImage(imageUrl: article.imageUrl),
              const SizedBox(width: StudyOsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: StudyOsSpacing.xs),
                    Text(
                      article.sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailSection extends StatelessWidget {
  const _EmailSection({
    required this.emails,
    required this.onRefresh,
    required this.onAskAssistant,
  });

  final List<FeedEmailCard> emails;
  final Future<void> Function() onRefresh;
  final ValueChanged<String> onAskAssistant;

  @override
  Widget build(BuildContext context) {
    if (emails.isEmpty) {
      return _UnavailableText(
        text: 'Email highlights could not be loaded.',
        actionIcon: Icons.refresh_rounded,
        actionTooltip: 'Refresh',
        onAction: onRefresh,
      );
    }
    return Column(
      children: <Widget>[
        for (final email in emails) ...<Widget>[
          _EmailTile(email: email, onAskAssistant: onAskAssistant),
          const SizedBox(height: StudyOsSpacing.sm),
        ],
      ],
    );
  }
}

class _EmailTile extends StatelessWidget {
  const _EmailTile({required this.email, required this.onAskAssistant});

  final FeedEmailCard email;
  final ValueChanged<String> onAskAssistant;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudyOsColors.surface,
      borderRadius: BorderRadius.circular(StudyOsRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        onTap: () => showEmailFeedDetails(context, email, onAskAssistant),
        child: Padding(
          padding: const EdgeInsets.all(StudyOsSpacing.md),
          child: Row(
            children: <Widget>[
              Icon(
                email.isUnread
                    ? Icons.mark_email_unread_outlined
                    : Icons.mail_outline_rounded,
                color: StudyOsColors.accent,
              ),
              const SizedBox(width: StudyOsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      email.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: StudyOsSpacing.xs),
                    Text(
                      email.sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableText extends StatelessWidget {
  const _UnavailableText({
    required this.text,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  final String text;
  final IconData? actionIcon;
  final String? actionTooltip;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: StudyOsColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (actionIcon != null && onAction != null)
            IconButton(
              tooltip: actionTooltip,
              onPressed: () => onAction!(),
              icon: Icon(actionIcon, color: StudyOsColors.accent),
            ),
        ],
      ),
    );
  }
}

class _ArticleImage extends StatelessWidget {
  const _ArticleImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(StudyOsRadii.sm),
      child: SizedBox(
        width: 88,
        height: 72,
        child: url == null || url.isEmpty
            ? ColoredBox(
                color: StudyOsColors.accent.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.article_outlined,
                  color: StudyOsColors.accent,
                ),
              )
            : Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}

class _CompactPill extends StatelessWidget {
  const _CompactPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudyOsColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: StudyOsSpacing.sm,
          vertical: StudyOsSpacing.xs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            color: StudyOsColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
