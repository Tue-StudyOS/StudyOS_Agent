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

  CampusCanteen forWeek(DateTime day) {
    final start = _weekStart(day);
    final end = start.add(const Duration(days: 7));
    final weekMenus = menus.where((menu) {
      final date = menu.parsedDate;
      return date != null && !date.isBefore(start) && date.isBefore(end);
    }).toList();
    weekMenus.sort((first, second) {
      return first.parsedDate!.compareTo(second.parsedDate!);
    });
    return CampusCanteen(id: id, name: name, menus: weekMenus);
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

  DateTime? get parsedDate {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

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

DateTime _weekStart(DateTime day) {
  final date = DateTime(day.year, day.month, day.day);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
}
