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
      final canteens = await client.fetchTuebingenCanteens();
      return canteens
          .map((canteen) => canteen.filteredFor(_preference))
          .map((canteen) => canteen.forWeek(_today))
          .where((canteen) => canteen.menus.isNotEmpty)
          .toList();
    } finally {
      if (widget.client == null) client.close();
    }
  }

  void _refresh() {
    setState(() => _canteens = _fetch());
  }

  @override
  Widget build(BuildContext context) {
    final preference = _preference;
    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Mensa',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    preference == FoodPreference.noPreference
                        ? 'This week\'s Mensa menus for Tübingen.'
                        : 'This week\'s ${preference.label} Mensa options for Tübingen.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh Mensa',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        FutureBuilder<List<CampusCanteen>>(
          future: _canteens,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _CampusMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load Mensa',
                body: snapshot.error.toString(),
              );
            }
            final canteens = snapshot.data ?? const <CampusCanteen>[];
            if (canteens.isEmpty) {
              return const _CampusMessage(
                icon: Icons.restaurant_outlined,
                title: 'No meals found',
                body: 'No matching Mensa options are available right now.',
              );
            }
            return Column(
              children: <Widget>[
                Material(
                  color: StudyOsColors.surface,
                  borderRadius: BorderRadius.circular(StudyOsRadii.md),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(StudyOsRadii.md),
                    child: Column(
                      children: <Widget>[
                        for (
                          var index = 0;
                          index < canteens.length;
                          index++
                        ) ...<Widget>[
                          _CanteenCard(canteen: canteens[index]),
                          if (index < canteens.length - 1)
                            const Padding(
                              padding: EdgeInsets.only(left: StudyOsSpacing.lg),
                              child: Divider(),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CanteenCard extends StatelessWidget {
  const _CanteenCard({required this.canteen});

  final CampusCanteen canteen;

  @override
  Widget build(BuildContext context) {
    final menu = canteen.menus.first;
    return Padding(
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(canteen.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StudyOsSpacing.xs),
          Text(
            [
              menu.date,
              menu.line,
              _priceLabel(menu),
            ].where((part) => part.isNotEmpty).join(' · '),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: StudyOsSpacing.md),
          Text(
            menu.items.join('\n'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (menu.icons.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            Text(
              menu.icons.take(4).join(' · '),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  String _priceLabel(CampusMenu menu) {
    final price = menu.studentPrice;
    if (price == null || price.isEmpty) return '';
    return '$price Euro';
  }
}

class _CampusMessage extends StatelessWidget {
  const _CampusMessage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      decoration: BoxDecoration(
        color: StudyOsColors.surface,
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: StudyOsColors.textMuted),
          const SizedBox(height: StudyOsSpacing.md),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StudyOsSpacing.xs),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
