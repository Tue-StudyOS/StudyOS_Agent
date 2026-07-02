import 'student_profile.dart';

class CampusCanteen {
  const CampusCanteen({
    required this.id,
    required this.name,
    required this.menus,
  });

  final String id;
  final String name;
  final List<CampusMenu> menus;

  CampusCanteen filteredFor(FoodPreference preference) {
    if (preference == FoodPreference.noPreference) return this;
    return CampusCanteen(
      id: id,
      name: name,
      menus: menus.where((menu) => menu.matches(preference)).toList(),
    );
  }
}

class CampusMenuEntry {
  const CampusMenuEntry({required this.canteen, required this.menu});

  final CampusCanteen canteen;
  final CampusMenu menu;
}

class CampusMenu {
  const CampusMenu({
    required this.id,
    required this.line,
    required this.date,
    required this.items,
    required this.icons,
    required this.studentPrice,
  });

  final String id;
  final String line;
  final String date;
  final List<String> items;
  final List<String> icons;
  final String? studentPrice;

  DateTime? get parsedDate => DateTime.tryParse(date);

  bool matches(FoodPreference preference) {
    final normalized = icons.map((icon) => icon.toLowerCase()).toSet();
    return switch (preference) {
      FoodPreference.noPreference => true,
      FoodPreference.vegetarian =>
        normalized.contains('vegetarisch') ||
            normalized.contains('vegetarian') ||
            normalized.contains('vegan'),
      FoodPreference.vegan => normalized.contains('vegan'),
    };
  }
}

List<CampusMenuEntry> sortedCampusMenuEntries(List<CampusCanteen> canteens) {
  final entries = <CampusMenuEntry>[
    for (final canteen in canteens)
      for (final menu in canteen.menus)
        CampusMenuEntry(canteen: canteen, menu: menu),
  ];
  entries.sort((a, b) {
    final aDate = a.menu.parsedDate;
    final bDate = b.menu.parsedDate;
    if (aDate == null && bDate != null) return 1;
    if (aDate != null && bDate == null) return -1;
    if (aDate != null && bDate != null) {
      final dateCompare = aDate.compareTo(bDate);
      if (dateCompare != 0) return dateCompare;
    }
    final canteenCompare = a.canteen.name.compareTo(b.canteen.name);
    if (canteenCompare != 0) return canteenCompare;
    return a.menu.line.compareTo(b.menu.line);
  });
  return entries;
}

class CampusCanteenAction {
  const CampusCanteenAction({required this.website, required this.navigation});

  final Uri website;
  final Uri navigation;
}

CampusCanteenAction? actionForCanteen(CampusCanteen canteen) {
  final normalized = canteen.name.toLowerCase();
  if (normalized.contains('wilhelm')) {
    return _action(
      website: 'https://www.my-stuwe.de/mensa/mensa-wilhelmstrasse-tuebingen/',
      destination: 'Mensa Wilhelmstraße Tübingen',
    );
  }
  if (normalized.contains('morgenstelle')) {
    return _action(
      website: 'https://www.my-stuwe.de/mensa/mensa-morgenstelle-tuebingen/',
      destination: 'Mensa Morgenstelle Tübingen',
    );
  }
  if (normalized.contains('prinz')) {
    return _action(
      website: 'https://www.my-stuwe.de/mensa/mensa-prinz-karl-tuebingen/',
      destination: 'Mensa Prinz Karl Tübingen',
    );
  }
  return null;
}

CampusCanteenAction _action({
  required String website,
  required String destination,
}) {
  return CampusCanteenAction(
    website: Uri.parse(website),
    navigation: Uri.https('www.google.com', '/maps/dir/', <String, String>{
      'api': '1',
      'destination': destination,
    }),
  );
}
