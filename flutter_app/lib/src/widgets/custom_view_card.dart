import 'package:flutter/material.dart';

import '../models.dart';
import '../studyos_theme.dart';

/// Renders a `custom_view` generative-UI component: a model-composed card built
/// from a small, whitelisted vocabulary of primitive nodes rather than a
/// purpose-built widget. This is the general path for replies that don't map to
/// a fixed card kind (comparisons, checklists, step guides, stat rows).
///
/// The renderer is deliberately *tolerant*: any node it doesn't recognise, or
/// that is missing the data it needs, is skipped rather than failing the whole
/// card — a weak model that gets one node wrong still gets a useful result. The
/// structural bounds (node count, depth, children-per-container) are enforced up
/// front by [GenerativeUiRegistry]; recursion here is depth-guarded again as
/// defence in depth. Buttons can only emit the existing sealed
/// [GeneratedComponentAction] set, so the safety model (a tap is the user's
/// authorization) is preserved.
class CustomViewCard extends StatelessWidget {
  const CustomViewCard({
    required this.component,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final GeneratedUiComponent component;
  final ValueChanged<GeneratedComponentAction>? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = component.body.trim();
    final blocks = _buildBlocks(
      component.arguments['blocks'],
      depth: 1,
      context: context,
    );
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.symmetric(vertical: compact ? 5 : 8),
        child: Material(
          color: StudyOsColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: StudyOsColors.border),
            borderRadius: BorderRadius.circular(StudyOsRadii.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(StudyOsSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.dashboard_customize_outlined,
                      size: 18,
                      color: StudyOsColors.accent,
                    ),
                    const SizedBox(width: StudyOsSpacing.sm),
                    Expanded(
                      child: Text(
                        component.title,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  ],
                ),
                if (body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.xs),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
                if (blocks.isNotEmpty) ...<Widget>[
                  const SizedBox(height: StudyOsSpacing.sm),
                  ...blocks,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the renderable children of a `blocks` list, dropping any node that
  /// yields nothing and inserting vertical spacing between the survivors.
  List<Widget> _buildBlocks(
    Object? raw, {
    required int depth,
    required BuildContext context,
  }) {
    if (raw is! List) return const <Widget>[];
    final widgets = <Widget>[];
    for (final node in raw) {
      final widget = _buildNode(node, depth: depth, context: context);
      if (widget == null) continue;
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: StudyOsSpacing.sm));
      }
      widgets.add(widget);
    }
    return widgets;
  }

  Widget? _buildNode(
    Object? raw, {
    required int depth,
    required BuildContext context,
  }) {
    if (raw is! Map) return null;
    final node = Map<String, Object?>.from(raw);
    final theme = Theme.of(context);
    switch (node['node']?.toString()) {
      case 'heading':
        final text = _str(node, 'text');
        return text.isEmpty
            ? null
            : Text(text, style: theme.textTheme.titleMedium);
      case 'paragraph':
        final text = _str(node, 'text');
        return text.isEmpty
            ? null
            : Text(text, style: theme.textTheme.bodyLarge);
      case 'bullets':
        return _bullets(_strList(node['items']), theme);
      case 'key_values':
        return _keyValues(_mapList(node['rows']), theme);
      case 'table':
        return _table(node, theme);
      case 'stats':
        return _stats(_mapList(node['items']), theme);
      case 'badges':
        return _badges(_mapList(node['items']), theme);
      case 'divider':
        return const Divider(height: 1, color: StudyOsColors.border);
      case customViewContainerNode:
        if (depth >= customViewMaxDepth) return null;
        final children = _buildBlocks(
          node['blocks'],
          depth: depth + 1,
          context: context,
        );
        if (children.isEmpty) return null;
        return Padding(
          padding: const EdgeInsets.only(left: StudyOsSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        );
      case 'button':
        return _button(node);
      default:
        return null;
    }
  }

  Widget? _bullets(List<String> items, ThemeData theme) {
    if (items.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: 7,
                    right: StudyOsSpacing.sm,
                  ),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: StudyOsColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: 5),
                  ),
                ),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }

  Widget? _keyValues(List<Map<String, Object?>> rows, ThemeData theme) {
    final visible = rows
        .where(
          (row) =>
              _str(row, 'label').isNotEmpty || _str(row, 'value').isNotEmpty,
        )
        .toList(growable: false);
    if (visible.isEmpty) return null;
    return Column(
      children: <Widget>[
        for (final row in visible)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    _str(row, 'label'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: StudyOsColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: StudyOsSpacing.md),
                Expanded(
                  child: Text(
                    _str(row, 'value'),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: StudyOsColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget? _table(Map<String, Object?> node, ThemeData theme) {
    final columns = _strList(node['columns']);
    final rawRows = node['rows'];
    if (columns.isEmpty || rawRows is! List) return null;
    final rows = <List<String>>[];
    for (final raw in rawRows) {
      if (raw is! List) continue;
      final cells = <String>[
        for (var i = 0; i < columns.length; i++)
          i < raw.length ? (raw[i]?.toString() ?? '') : '',
      ];
      rows.add(cells);
    }
    if (rows.isEmpty) return null;

    TableRow buildRow(List<String> cells, {required bool header}) {
      return TableRow(
        children: <Widget>[
          for (final cell in cells)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StudyOsSpacing.sm,
                vertical: StudyOsSpacing.xs,
              ),
              child: Text(
                cell,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: header ? StudyOsColors.text : StudyOsColors.textMuted,
                  fontWeight: header ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
        ],
      );
    }

    return Table(
      border: const TableBorder(
        horizontalInside: BorderSide(color: StudyOsColors.border),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        buildRow(columns, header: true),
        for (final row in rows) buildRow(row, header: false),
      ],
    );
  }

  Widget? _stats(List<Map<String, Object?>> items, ThemeData theme) {
    final visible = items
        .where((item) => _str(item, 'value').isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return null;
    return Wrap(
      spacing: StudyOsSpacing.xl,
      runSpacing: StudyOsSpacing.sm,
      children: <Widget>[
        for (final item in visible)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _str(item, 'value'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 22,
                  color: StudyOsColors.accent,
                ),
              ),
              if (_str(item, 'label').isNotEmpty)
                Text(
                  _str(item, 'label'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: StudyOsColors.textMuted,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget? _badges(List<Map<String, Object?>> items, ThemeData theme) {
    final visible = items
        .where((item) => _str(item, 'text').isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) return null;
    return Wrap(
      spacing: StudyOsSpacing.sm,
      runSpacing: StudyOsSpacing.sm,
      children: <Widget>[
        for (final item in visible)
          _Badge(text: _str(item, 'text'), tone: _str(item, 'tone')),
      ],
    );
  }

  Widget? _button(Map<String, Object?> node) {
    final label = _str(node, 'label');
    final action = _actionFrom(node['action']);
    if (label.isEmpty || action == null) return null;
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: onAction == null ? null : () => onAction!(action),
        style: OutlinedButton.styleFrom(
          foregroundColor: StudyOsColors.accent,
          side: const BorderSide(color: StudyOsColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(StudyOsRadii.lg),
          ),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(label),
      ),
    );
  }

  /// Maps a button's `action` object onto the existing sealed action set. Any
  /// unknown type or incomplete payload returns null, which drops the button —
  /// no new action kinds can be introduced through a custom view.
  GeneratedComponentAction? _actionFrom(Object? raw) {
    if (raw is! Map) return null;
    final action = Map<String, Object?>.from(raw);
    switch (action['type']?.toString()) {
      case 'prompt':
        final prompt = _str(action, 'prompt');
        return prompt.isEmpty ? null : PromptComponentAction(prompt);
      case 'reminder':
        final title = _str(action, 'title');
        final due = DateTime.tryParse(_str(action, 'due'))?.toLocal();
        return title.isEmpty || due == null
            ? null
            : ReminderComponentAction(title: title, dueAt: due);
      case 'map':
        final name = _str(action, 'name');
        final latitude = _toDouble(action['latitude']);
        final longitude = _toDouble(action['longitude']);
        return name.isEmpty || latitude == null || longitude == null
            ? null
            : MapComponentAction(
                name: name,
                latitude: latitude,
                longitude: longitude,
              );
      default:
        return null;
    }
  }

  static String _str(Map<String, Object?> node, String key) =>
      node[key]?.toString().trim() ?? '';

  static List<String> _strList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<Map<String, Object?>> _mapList(Object? raw) {
    if (raw is! List) return const <Map<String, Object?>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '');
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.tone});

  final String text;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone.toLowerCase()) {
      'positive' || 'success' => StudyOsColors.success,
      'warning' => StudyOsColors.warning,
      'danger' || 'destructive' => StudyOsColors.destructive,
      _ => StudyOsColors.accent,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StudyOsSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(StudyOsRadii.sm),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
