import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../campus_client.dart';
import '../campus_models.dart';
import '../models.dart';
import '../studyos_theme.dart';

class CampusView extends StatefulWidget {
  const CampusView({required this.profile, this.client, super.key});

  final OnboardingProfile? profile;
  final CampusClient? client;

  @override
  State<CampusView> createState() => _CampusViewState();
}

class _CampusViewState extends State<CampusView> {
  late Future<List<CampusCanteen>> _canteens;

  FoodPreference get _preference =>
      widget.profile?.foodPreference ?? FoodPreference.noPreference;

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
                    'Campus',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(
                    preference == FoodPreference.noPreference
                        ? 'Mensa menus for Tübingen.'
                        : '${preference.label} Mensa options for Tübingen.',
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
                for (final entry in sortedCampusMenuEntries(canteens))
                  _CanteenCard(entry: entry),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CanteenCard extends StatelessWidget {
  const _CanteenCard({required this.entry});

  final CampusMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    final canteen = entry.canteen;
    final menu = entry.menu;
    final action = actionForCanteen(canteen);
    final foodName = menu.items.first;
    final additionalItems = menu.items.skip(1).toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: StudyOsSpacing.md),
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      decoration: BoxDecoration(
        color: StudyOsColors.surface,
        border: Border.all(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            canteen.name,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: StudyOsColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: StudyOsSpacing.xs),
          Text(
            _headline(foodName: foodName, menu: menu),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          if (additionalItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.sm),
            Text(
              additionalItems.join('\n'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: StudyOsSpacing.sm),
          Text(
            menu.date,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: StudyOsColors.textMuted),
          ),
          if (menu.icons.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            Wrap(
              spacing: StudyOsSpacing.sm,
              runSpacing: StudyOsSpacing.sm,
              children: <Widget>[
                for (final icon in menu.icons.take(4))
                  Chip(label: Text(icon), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
          if (action != null) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: StudyOsSpacing.xs,
                children: <Widget>[
                  IconButton(
                    tooltip: 'Open Mensa website',
                    onPressed: () => _open(action.website),
                    icon: const Icon(Icons.public_rounded),
                  ),
                  IconButton(
                    tooltip: 'Share menu',
                    onPressed: () => _share(entry, action.website),
                    icon: const Icon(Icons.share_rounded),
                  ),
                  IconButton(
                    tooltip: 'Navigate to Mensa',
                    onPressed: () => _open(action.navigation),
                    icon: const Icon(Icons.navigation_rounded),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _headline({required String foodName, required CampusMenu menu}) {
    return [
      foodName,
      menu.line,
      _priceLabel(menu),
    ].where((part) => part.isNotEmpty).join(' - ');
  }

  static String _priceLabel(CampusMenu menu) {
    final price = menu.studentPrice;
    if (price == null || price.isEmpty) return '';
    return '$price €';
  }

  static Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> _share(CampusMenuEntry entry, Uri website) async {
    final menu = entry.menu;
    final foodName = menu.items.first;
    final additionalItems = menu.items.skip(1).toList();
    final lines = <String>[
      entry.canteen.name,
      [
        menu.date,
        foodName,
        menu.line,
        _priceLabel(menu),
      ].where((part) => part.isNotEmpty).join(' - '),
      if (additionalItems.isNotEmpty) additionalItems.join(', '),
      website.toString(),
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
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
        border: Border.all(color: StudyOsColors.border),
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
