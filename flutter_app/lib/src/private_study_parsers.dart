import 'dart:convert';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'private_study_models.dart';

List<PortalTask> parseIliasTasks(String html, Uri pageUrl) {
  final document = html_parser.parse(html);
  final tasks = <PortalTask>[];
  for (final item in document.querySelectorAll('.il-item.il-std-item')) {
    final action = item.querySelector(
      '.il-item-title a[href], .il-item-title button[data-action]',
    );
    final rawUrl =
        action?.attributes['href'] ?? action?.attributes['data-action'];
    final title = _text(action?.text);
    if (rawUrl == null || title == null) {
      continue;
    }
    final properties = _properties(item);
    final url = pageUrl.resolve(rawUrl).toString();
    tasks.add(
      PortalTask(
        source: StudyPortalSource.ilias,
        id: _stableId(url),
        title: title,
        url: url,
        courseTitle: properties['Kurs'],
        itemType: properties['Übung'] ?? properties['Typ'],
        startAt: parsePortalDate(properties['Beginn']),
        dueAt: parsePortalDate(properties['Ende']),
        rawStartHint: properties['Beginn'],
        rawDueHint: properties['Ende'],
      ),
    );
  }
  if (tasks.isEmpty && _looksUnauthenticated(html)) {
    throw const PortalAuthenticationException();
  }
  return tasks;
}

List<PortalDeadline> parseIliasAssignments(String html, Uri pageUrl) {
  final document = html_parser.parse(html);
  final deadlines = <PortalDeadline>[];
  for (final item in document.querySelectorAll('.il-item.il-std-item')) {
    final link = item.querySelector('.il-item-title a[href]');
    final rawUrl = link?.attributes['href'];
    final title = _text(link?.text);
    if (rawUrl == null || title == null) {
      continue;
    }
    final properties = _properties(item);
    final dueHint =
        properties['Abgabetermin'] ??
        _text(item.querySelector('.col-sm-3')?.text);
    final dueAt = parsePortalDate(dueHint);
    if (dueAt == null) continue;
    final url = pageUrl.resolve(rawUrl).toString();
    deadlines.add(
      PortalDeadline(
        source: StudyPortalSource.ilias,
        id: _stableId(url),
        title: title,
        dueAt: dueAt,
        url: url,
        dueHint: dueHint,
        requirement: properties['Anforderung'],
        status: properties['Status'],
      ),
    );
  }
  if (deadlines.isEmpty && _looksUnauthenticated(html)) {
    throw const PortalAuthenticationException();
  }
  return deadlines;
}

String parseMoodleSesskey(String html) {
  final match = RegExp(
    r'M\.cfg\s*=\s*(\{.*?\});',
    dotAll: true,
  ).firstMatch(html);
  if (match == null) {
    throw const PortalException('Could not find Moodle sesskey.');
  }
  final value = jsonDecode(match.group(1)!);
  if (value is! Map || value['sesskey']?.toString().isEmpty != false) {
    throw const PortalException('Could not find Moodle sesskey.');
  }
  return value['sesskey'].toString();
}

List<PortalTask> parseMoodleEvents(String body, Uri baseUrl) {
  Object? payload = jsonDecode(body);
  if (payload is List && payload.isNotEmpty && payload.first is Map) {
    final envelope = Map<Object?, Object?>.from(payload.first as Map);
    if (_truthy(envelope['error'])) {
      throw PortalException(
        envelope['exception']?.toString() ??
            envelope['message']?.toString() ??
            'Moodle request failed.',
      );
    }
    payload = envelope['data'];
  }
  final events = payload is Map ? payload['events'] : payload;
  if (events is! List) return const <PortalTask>[];
  return events
      .whereType<Map>()
      .map((raw) {
        final item = Map<Object?, Object?>.from(raw);
        final course = item['course'] is Map
            ? Map<Object?, Object?>.from(item['course'] as Map)
            : const <Object?, Object?>{};
        final action = item['action'] is Map
            ? Map<Object?, Object?>.from(item['action'] as Map)
            : const <Object?, Object?>{};
        final rawUrl = action['url'] ?? item['url'] ?? item['viewurl'];
        final url = rawUrl == null
            ? baseUrl
            : baseUrl.resolve(rawUrl.toString());
        final timestamp = _integer(item['timesort']);
        return PortalTask(
          source: StudyPortalSource.moodle,
          id: item['id']?.toString() ?? _stableId(url.toString()),
          title:
              _text(item['name']?.toString()) ??
              _text(item['title']?.toString()) ??
              'Untitled event',
          url: url.toString(),
          courseTitle:
              _text(course['fullname']?.toString()) ??
              _text(course['shortname']?.toString()),
          itemType: 'calendar_event',
          dueAt: timestamp == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  timestamp * 1000,
                  isUtc: true,
                ),
          rawDueHint: _text(item['formattedtime']?.toString()),
          actionable: rawUrl != null,
        );
      })
      .toList(growable: false);
}

DateTime? parsePortalDate(String? value) {
  final text = _text(value);
  if (text == null) return null;
  final iso = DateTime.tryParse(text);
  if (iso != null) return iso;
  final match = RegExp(
    r'\b(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[, ]+\s*(\d{1,2}):(\d{2}))?',
  ).firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match.group(3)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(1)!);
  final hour = int.tryParse(match.group(4) ?? '') ?? 0;
  final minute = int.tryParse(match.group(5) ?? '') ?? 0;
  final offset = _berlinUtcOffset(year, month, day, hour);
  return DateTime.utc(year, month, day, hour - offset, minute);
}

int _berlinUtcOffset(int year, int month, int day, int hour) {
  if (month < 3 || month > 10) return 1;
  if (month > 3 && month < 10) return 2;
  final current = DateTime.utc(year, month, day, hour);
  final transitionDay = _lastSunday(year, month);
  final transitionHour = month == 3 ? 2 : 3;
  final transition = DateTime.utc(year, month, transitionDay, transitionHour);
  return month == 3
      ? (current.isBefore(transition) ? 1 : 2)
      : (current.isBefore(transition) ? 2 : 1);
}

int _lastSunday(int year, int month) {
  final last = DateTime.utc(year, month + 1, 0);
  return last.day - (last.weekday % 7);
}

Map<String, String> _properties(Element item) {
  final result = <String, String>{};
  for (final name in item.querySelectorAll('.il-item-property-name')) {
    final value = name.nextElementSibling;
    if (value?.classes.contains('il-item-property-value') != true) continue;
    final key = _text(name.text);
    final content = _text(value!.text);
    if (key != null && content != null) result[key] = content;
  }
  return result;
}

String? _text(String? value) {
  final cleaned = value?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  return cleaned.isEmpty ? null : cleaned;
}

int? _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

bool _truthy(Object? value) =>
    value == true || value == 1 || value?.toString().toLowerCase() == 'true';

bool _looksUnauthenticated(String html) =>
    html.contains('SAMLResponse') ||
    html.contains('j_username') ||
    html.contains('j_password') ||
    html.contains('shib_login.php');

String _stableId(String value) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(value)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
