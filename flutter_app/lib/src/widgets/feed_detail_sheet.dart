import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';
import '../studyos_theme.dart';

Future<void> showScheduleFeedDetails(
  BuildContext context,
  FeedScheduleCard item,
  ValueChanged<String> onAskAssistant,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FeedDetailSheet(
      title: item.courseName,
      subtitle: [
        if (item.type != null) item.type!,
        item.timeRange,
        item.timeToNextLabel,
      ].join(' · '),
      headerColor: StudyOsColors.accent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _AddressMapPanel(address: item.address),
          if (item.llmSummary?.trim().isNotEmpty == true) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            Text(
              item.llmSummary!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ],
      ),
      actions: <_FeedAction>[
        _FeedAction(
          icon: Icons.auto_awesome_rounded,
          label: 'Ask AI',
          onTap: () {
            Navigator.of(context).pop();
            onAskAssistant('Help me prepare for ${item.courseName}.');
          },
        ),
        _FeedAction(
          icon: Icons.send_rounded,
          label: 'Send',
          onTap: () {
            Navigator.of(context).pop();
            onAskAssistant('Summarize this lecture card: ${item.courseName}.');
          },
        ),
        _FeedAction(
          icon: Icons.navigation_rounded,
          label: 'Navigate',
          onTap: () {
            Navigator.of(context).pop();
            _openNavigation(item.address ?? item.courseName);
          },
        ),
      ],
    ),
  );
}

Future<void> showArticleFeedDetails(
  BuildContext context,
  FeedArticleCard article,
  ValueChanged<String> onAskAssistant,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FeedDetailSheet(
      title: article.title,
      subtitle: article.sourceLabel,
      headerColor: StudyOsColors.text,
      body: Text(article.body, style: Theme.of(context).textTheme.bodyLarge),
      actions: <_FeedAction>[
        _FeedAction(
          icon: Icons.auto_awesome_rounded,
          label: 'Ask AI',
          onTap: () {
            Navigator.of(context).pop();
            onAskAssistant(
              'Summarize this Tübingen highlight: ${article.title}',
            );
          },
        ),
        _FeedAction(
          icon: Icons.send_rounded,
          label: 'Send',
          onTap: () {
            Navigator.of(context).pop();
            onAskAssistant('Draft a short share text for: ${article.title}');
          },
        ),
      ],
    ),
  );
}

Future<void> showEmailFeedDetails(
  BuildContext context,
  FeedEmailCard email,
  ValueChanged<String> onAskAssistant,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _FeedDetailSheet(
      title: email.subject,
      subtitle: email.sender,
      headerColor: StudyOsColors.warning,
      body: Text(email.preview, style: Theme.of(context).textTheme.bodyLarge),
      actions: <_FeedAction>[
        _FeedAction(
          icon: Icons.auto_awesome_rounded,
          label: 'Ask AI',
          onTap: () {
            Navigator.of(context).pop();
            onAskAssistant(
              'Extract action items from this email: ${email.subject}',
            );
          },
        ),
        _FeedAction(
          icon: Icons.send_rounded,
          label: 'Send',
          onTap: () {
            Navigator.of(context).pop();
            onAskAssistant('Draft a reply for this email: ${email.subject}');
          },
        ),
      ],
    ),
  );
}

class _FeedDetailSheet extends StatelessWidget {
  const _FeedDetailSheet({
    required this.title,
    required this.subtitle,
    required this.headerColor,
    required this.body,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final Color headerColor;
  final Widget body;
  final List<_FeedAction> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.md),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(StudyOsRadii.lg),
          child: Material(
            color: StudyOsColors.surface,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _FeedDetailHeader(
                  title: title,
                  subtitle: subtitle,
                  color: headerColor,
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(StudyOsSpacing.xl),
                    child: body,
                  ),
                ),
                _FeedDetailActions(actions: actions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedDetailHeader extends StatelessWidget {
  const _FeedDetailHeader({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: color,
      padding: const EdgeInsets.all(StudyOsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: StudyOsSpacing.xs),
          Text(subtitle, style: const TextStyle(color: Color(0xFFE5E5EA))),
        ],
      ),
    );
  }
}

class _FeedDetailActions extends StatelessWidget {
  const _FeedDetailActions({required this.actions});

  final List<_FeedAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        StudyOsSpacing.xl,
        0,
        StudyOsSpacing.xl,
        StudyOsSpacing.xl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          for (final action in actions) ...<Widget>[
            IconButton.filledTonal(
              tooltip: action.label,
              onPressed: action.onTap,
              icon: Icon(action.icon),
            ),
            const SizedBox(width: StudyOsSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _AddressMapPanel extends StatelessWidget {
  const _AddressMapPanel({required this.address});

  final String? address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: StudyOsColors.background,
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        border: Border.all(color: StudyOsColors.border),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: CustomPaint(painter: _MapGridPainter())),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.location_on_rounded,
                  size: 36,
                  color: StudyOsColors.accent,
                ),
                const SizedBox(height: StudyOsSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StudyOsSpacing.lg,
                  ),
                  child: Text(
                    address?.trim().isNotEmpty == true
                        ? address!
                        : 'No address available yet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StudyOsColors.border.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x + 42, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 24), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeedAction {
  const _FeedAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

Future<void> _openNavigation(String destination) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', <String, String>{
    'api': '1',
    'destination': destination,
  });
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
