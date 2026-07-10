import 'package:flutter/material.dart';

import '../campus_client.dart';
import '../campus_models.dart';
import '../models.dart';
import '../studyos_theme.dart';

class CampusView extends StatefulWidget {
  const CampusView({required this.profile, this.client, this.today, super.key});

  final OnboardingProfile? profile;
  final CampusClient? client;
  final DateTime? today;

  @override
  State<CampusView> createState() => _CampusViewState();
}

class _CampusViewState extends State<CampusView> {
  late Future<List<CampusCanteen>> _canteens;

  FoodPreference get _preference =>
      widget.profile?.foodPreference ?? FoodPreference.noPreference;
  DateTime get _today => widget.today ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _canteens = _fetch();
  }

  Future<List<CampusCanteen>> _fetch() async {
    final client = widget.client ?? CampusClient();
    try {
      return (await client.fetchTuebingenCanteens())
          .map((canteen) => canteen.filteredFor(_preference))
          .map((canteen) => canteen.forWeek(_today))
          .where((canteen) => canteen.menus.isNotEmpty)
          .toList();
    } finally {
      if (widget.client == null) client.close();
    }
  }

  void _refresh() => setState(() => _canteens = _fetch());

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(
      top: StudyOsSpacing.xl,
      bottom: StudyOsSpacing.xxl,
    ),
    children: <Widget>[
      Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Mensa', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: StudyOsSpacing.xs),
                Text(_subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh Mensa',
            onPressed: _refresh,
            style: IconButton.styleFrom(
              backgroundColor: StudyOsColors.surface,
              foregroundColor: StudyOsColors.accent,
            ),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      const SizedBox(height: StudyOsSpacing.xxl),
      FutureBuilder<List<CampusCanteen>>(
        future: _canteens,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MensaMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Couldn’t load today’s meals',
              body: snapshot.error.toString(),
            );
          }
          final canteens = snapshot.data ?? const <CampusCanteen>[];
          if (canteens.isEmpty) {
            return const _MensaMessage(
              icon: Icons.restaurant_outlined,
              title: 'Nothing matching today',
              body: 'Try refreshing later or adjust your Mensa preference.',
            );
          }
          return _MensaContent(canteens: canteens);
        },
      ),
    ],
  );

  String get _subtitle {
    if (_preference == FoodPreference.noPreference) {
      return 'Today’s menus in Tübingen';
    }
    return 'Today’s ${_preference.label.toLowerCase()} options in Tübingen';
  }
}

class _MensaContent extends StatelessWidget {
  const _MensaContent({required this.canteens});

  final List<CampusCanteen> canteens;

  @override
  Widget build(BuildContext context) {
    final featured = canteens.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Pick for today', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: StudyOsSpacing.sm),
        _FeaturedMeal(canteen: featured),
        if (canteens.length > 1) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.xxl),
          Text('More places', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StudyOsSpacing.sm),
          Material(
            color: StudyOsColors.surface,
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(StudyOsRadii.md),
              child: Column(
                children: <Widget>[
                  for (
                    var index = 1;
                    index < canteens.length;
                    index++
                  ) ...<Widget>[
                    _CanteenRow(canteen: canteens[index]),
                    if (index < canteens.length - 1)
                      const Padding(
                        padding: EdgeInsets.only(left: StudyOsSpacing.xl),
                        child: Divider(),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedMeal extends StatelessWidget {
  const _FeaturedMeal({required this.canteen});

  final CampusCanteen canteen;

  @override
  Widget build(BuildContext context) {
    final menu = canteen.menus.first;
    return Material(
      color: StudyOsColors.text,
      borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      child: Padding(
        padding: const EdgeInsets.all(StudyOsSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              canteen.name,
              style: const TextStyle(
                color: Color(0xFFAEAEB2),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: StudyOsSpacing.md),
            Text(
              menu.items.join('\n'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: StudyOsSpacing.lg),
            Row(
              children: <Widget>[
                if (menu.line.isNotEmpty)
                  Text(
                    menu.line,
                    style: const TextStyle(color: Color(0xFFD1D1D6)),
                  ),
                const Spacer(),
                if (menu.studentPrice?.isNotEmpty == true)
                  Text(
                    '${menu.studentPrice} €',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CanteenRow extends StatelessWidget {
  const _CanteenRow({required this.canteen});

  final CampusCanteen canteen;

  @override
  Widget build(BuildContext context) {
    final menu = canteen.menus.first;
    return Padding(
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: StudyOsColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.restaurant_outlined,
              color: StudyOsColors.accent,
              size: 19,
            ),
          ),
          const SizedBox(width: StudyOsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  canteen.name,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  menu.items.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (menu.studentPrice?.isNotEmpty == true)
            Text(
              '${menu.studentPrice} €',
              style: Theme.of(context).textTheme.labelLarge,
            ),
        ],
      ),
    );
  }
}

class _MensaMessage extends StatelessWidget {
  const _MensaMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Material(
    color: StudyOsColors.surface,
    borderRadius: BorderRadius.circular(StudyOsRadii.md),
    child: Padding(
      padding: const EdgeInsets.all(StudyOsSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: StudyOsColors.accent),
          const SizedBox(height: StudyOsSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StudyOsSpacing.xs),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}
