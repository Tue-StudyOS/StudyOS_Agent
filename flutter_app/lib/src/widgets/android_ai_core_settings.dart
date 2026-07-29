import 'package:flutter/material.dart';

import '../android_ai_core_models.dart';
import '../models.dart';
import '../native_bridge.dart';
import '../studyos_theme.dart';

class AndroidAiCoreSettings extends StatefulWidget {
  const AndroidAiCoreSettings({
    required this.config,
    required this.nativeBridge,
    required this.onSaveAgentConfig,
    super.key,
  });

  final AgentConfig config;
  final NativeBridge nativeBridge;
  final Future<void> Function(AgentConfig config, String? apiKey)
  onSaveAgentConfig;

  @override
  State<AndroidAiCoreSettings> createState() => _AndroidAiCoreSettingsState();
}

class _AndroidAiCoreSettingsState extends State<AndroidAiCoreSettings> {
  List<AndroidAiCoreModelOption> _models = const [];
  String _selectedId = defaultAndroidAiCoreModelId;
  bool _isLoading = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    if (isAndroidAiCoreModelId(widget.config.localModelId)) {
      _selectedId = widget.config.localModelId;
    }
    _loadModels();
  }

  @override
  void didUpdateWidget(AndroidAiCoreSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (isAndroidAiCoreModelId(widget.config.localModelId)) {
      _selectedId = widget.config.localModelId;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.hourglass_top_rounded),
        title: Text('Checking Android built-in AI…'),
      );
    }

    final supported = _models.where((model) => model.isSupported).toList();
    if (supported.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.block_rounded),
        title: const Text('Android built-in AI'),
        subtitle: const Text('Not supported on this device.'),
        trailing: IconButton(
          tooltip: 'Check again',
          onPressed: _loadModels,
          icon: const Icon(Icons.refresh_rounded),
        ),
      );
    }

    final selected = _selectedModel(supported);
    final isActive =
        widget.config.localModelPath.isEmpty &&
        widget.config.localModelId == selected.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Android built-in AI',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Check again',
              onPressed: _loadModels,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        Text(
          'Uses the shared Gemini Nano model managed by Android AICore.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: StudyOsSpacing.sm),
        if (supported.length > 1)
          DropdownButtonFormField<String>(
            key: ValueKey<String>(_selectedId),
            initialValue: selected.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Built-in model',
              prefixIcon: Icon(Icons.android_rounded),
            ),
            items: supported
                .map(
                  (model) => DropdownMenuItem<String>(
                    value: model.id,
                    child: Text(model.label),
                  ),
                )
                .toList(),
            onChanged: _isDownloading ? null : _selectModel,
          )
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.android_rounded),
            title: Text(selected.label),
          ),
        const SizedBox(height: StudyOsSpacing.xs),
        _AiCoreStatus(model: selected),
        const SizedBox(height: StudyOsSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _buttonAction(selected, isActive),
            icon: _isDownloading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    selected.isDownloadable
                        ? Icons.download_rounded
                        : Icons.memory_rounded,
                  ),
            label: Text(_buttonLabel(selected, isActive)),
          ),
        ),
      ],
    );
  }

  VoidCallback? _buttonAction(AndroidAiCoreModelOption model, bool isActive) {
    if (_isDownloading || model.isDownloading || isActive) return null;
    if (model.isDownloadable) return () => _downloadModel(model);
    if (model.isAvailable) return () => _activateModel(model);
    return null;
  }

  String _buttonLabel(AndroidAiCoreModelOption model, bool isActive) {
    if (_isDownloading || model.isDownloading) return 'Downloading…';
    if (model.isDownloadable) return 'Download Android model';
    if (isActive) return 'Using Android built-in AI';
    return 'Use Android built-in AI';
  }

  Future<void> _loadModels() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final values = await widget.nativeBridge.listAndroidAiCoreModels();
      final models = values
          .map(AndroidAiCoreModelOption.fromMap)
          .where((model) => model.id.isNotEmpty)
          .toList();
      final supported = models.where((model) => model.isSupported).toList();
      final selected = _preferredModel(supported);
      if (!mounted) return;
      setState(() {
        _models = models;
        _selectedId = selected?.id ?? _selectedId;
        _isLoading = false;
      });
      if (selected != null &&
          selected.isAvailable &&
          widget.config.localModelPath.isEmpty &&
          !isAndroidAiCoreModelId(widget.config.localModelId)) {
        await _activateModel(selected);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _models = const [];
        _isLoading = false;
      });
    }
  }

  AndroidAiCoreModelOption? _preferredModel(
    List<AndroidAiCoreModelOption> models,
  ) {
    if (isAndroidAiCoreModelId(widget.config.localModelId)) {
      for (final model in models) {
        if (model.id == widget.config.localModelId) return model;
      }
    }
    for (final model in models) {
      if (model.isAvailable) return model;
    }
    for (final model in models) {
      if (model.id == _selectedId) return model;
    }
    return models.isEmpty ? null : models.first;
  }

  AndroidAiCoreModelOption _selectedModel(
    List<AndroidAiCoreModelOption> models,
  ) {
    return _preferredModel(models) ?? models.first;
  }

  Future<void> _selectModel(String? id) async {
    if (id == null) return;
    setState(() => _selectedId = id);
    final model = _models.firstWhere((item) => item.id == id);
    if (model.isAvailable) await _activateModel(model);
  }

  Future<void> _downloadModel(AndroidAiCoreModelOption model) async {
    setState(() => _isDownloading = true);
    try {
      await widget.nativeBridge.downloadAndroidAiCoreModel(model.id);
      await _loadModels();
      AndroidAiCoreModelOption? refreshed;
      for (final item in _models) {
        if (item.id == model.id) {
          refreshed = item;
          break;
        }
      }
      if (refreshed?.isAvailable == true) await _activateModel(refreshed!);
    } catch (_) {
      _showMessage('Android built-in AI download failed.');
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _activateModel(AndroidAiCoreModelOption model) async {
    await widget.onSaveAgentConfig(
      widget.config.copyWith(
        provider: AgentProvider.local,
        localModelId: model.id,
        localModelPath: '',
      ),
      null,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AiCoreStatus extends StatelessWidget {
  const _AiCoreStatus({required this.model});

  final AndroidAiCoreModelOption model;

  @override
  Widget build(BuildContext context) {
    final available = model.isAvailable;
    return Row(
      children: <Widget>[
        Icon(
          available ? Icons.check_circle_rounded : Icons.download_for_offline,
          size: 18,
          color: available ? StudyOsColors.success : StudyOsColors.warning,
        ),
        const SizedBox(width: StudyOsSpacing.xs),
        Expanded(
          child: Text(
            model.baseModelName.isEmpty
                ? model.statusLabel
                : '${model.statusLabel} · ${model.baseModelName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
