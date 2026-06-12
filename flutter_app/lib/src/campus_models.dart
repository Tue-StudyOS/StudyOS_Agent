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
