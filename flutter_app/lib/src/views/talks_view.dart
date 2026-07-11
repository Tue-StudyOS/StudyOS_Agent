import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../studyos_theme.dart';
import '../talk_models.dart';
import '../talks_client.dart';

class TalksView extends StatefulWidget {
  const TalksView({this.client, super.key});

  final TalksClient? client;

  @override
  State<TalksView> createState() => _TalksViewState();
}

class _TalksViewState extends State<TalksView> {
  final TextEditingController _searchController = TextEditingController();
  late Future<List<Talk>> _talks;

  @override
  void initState() {
    super.initState();
    _talks = _fetch();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    if (widget.client == null) {
      // The view owns the default client, which is created once in [_fetch].
      _ownedClient?.close();
    }
    super.dispose();
  }

  TalksClient? _ownedClient;

  TalksClient get _client => widget.client ?? (_ownedClient ??= TalksClient());

  Future<List<Talk>> _fetch() => _client.fetchUpcoming();

  void _onSearchChanged() => setState(() {});

  void _refresh() => setState(() => _talks = _fetch());

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(StudyOsSpacing.xl),
        children: <Widget>[
          _Header(onRefresh: _refresh),
          const SizedBox(height: StudyOsSpacing.sm),
          Text(
            'Upcoming public talks and guest lectures from the University of Tübingen talks calendar.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: StudyOsSpacing.xl),
          TextField(
            key: const ValueKey<String>('talks-search'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search topic, speaker, or location',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: StudyOsSpacing.lg),
          FutureBuilder<List<Talk>>(
            future: _talks,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.only(top: StudyOsSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _Message(
                  title: 'Talks unavailable',
                  body: snapshot.error.toString(),
                  onRetry: _refresh,
                );
              }
              final query = _searchController.text;
              final talks = (snapshot.data ?? const <Talk>[])
                  .where((talk) => talk.matches(query))
                  .toList();
              if (talks.isEmpty) {
                return _Message(
                  title: query.trim().isEmpty
                      ? 'No upcoming talks'
                      : 'No matching talks',
                  body: query.trim().isEmpty
                      ? 'The public calendar does not list any upcoming talks.'
                      : 'Try another topic, speaker, or location.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${talks.length} upcoming ${talks.length == 1 ? 'talk' : 'talks'}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: StudyOsSpacing.sm),
                  Material(
                    color: StudyOsColors.surface,
                    borderRadius: BorderRadius.circular(StudyOsRadii.md),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: <Widget>[
                        for (var index = 0; index < talks.length; index++) ...[
                          _TalkRow(talk: talks[index]),
                          if (index != talks.length - 1) const Divider(),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
      ),
      const SizedBox(width: StudyOsSpacing.xs),
      Expanded(
        child: Text(
          'Tübingen Talks',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      IconButton(
        tooltip: 'Refresh talks',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );
}

class _TalkRow extends StatelessWidget {
  const _TalkRow({required this.talk});

  final Talk talk;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => _openSource(context),
    child: Padding(
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DateBadge(date: talk.start),
          const SizedBox(width: StudyOsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(talk.title, style: Theme.of(context).textTheme.labelLarge),
                if (talk.speakerName != null) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    talk.speakerName!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: StudyOsSpacing.sm),
                Text(
                  _metadata(talk),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: StudyOsColors.text,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.open_in_new_rounded,
            size: 17,
            color: StudyOsColors.textMuted,
          ),
        ],
      ),
    ),
  );

  Future<void> _openSource(BuildContext context) async {
    if (await launchUrl(talk.sourceUri, mode: LaunchMode.externalApplication)) {
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the original talk.')),
      );
    }
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final resolved = date;
    return SizedBox(
      width: 44,
      child: Column(
        children: <Widget>[
          Text(
            resolved == null ? 'TBA' : talkMonthAbbreviation(resolved.month),
            style: const TextStyle(
              color: StudyOsColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            resolved?.day.toString() ?? '—',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body, this.onRetry});

  final String title;
  final String body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: StudyOsSpacing.xl),
    child: Column(
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(body, textAlign: TextAlign.center),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.md),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ],
    ),
  );
}

String _metadata(Talk talk) {
  final parts = <String>[];
  final start = talk.start;
  if (start != null) {
    parts.add(
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
    );
  }
  if (talk.location != null) parts.add(talk.location!);
  return parts.isEmpty ? 'Time and location pending' : parts.join(' · ');
}
