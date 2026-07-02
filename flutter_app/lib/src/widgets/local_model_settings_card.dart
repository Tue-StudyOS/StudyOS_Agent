import 'dart:async';

import 'package:flutter/material.dart';

import '../local_model_catalog.dart';
import '../models.dart';
import '../native_bridge.dart';
import '../studyos_theme.dart';

class LocalModelSettingsCard extends StatefulWidget {
  const LocalModelSettingsCard({
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
  State<LocalModelSettingsCard> createState() => _LocalModelSettingsCardState();
}

class _LocalModelSettingsCardState extends State<LocalModelSettingsCard> {
  late final TextEditingController _customModelUrlController;
  StreamSubscription<NativeEvent>? _nativeEventSubscription;
  String _localModelId = const AgentConfig.defaults().localModelId;
  LocalBackend _localBackend = const AgentConfig.defaults().localBackend;
  List<Map<String, Object?>> _installedModels = <Map<String, Object?>>[];
  bool _isDownloadingModel = false;
  bool _isDeletingModel = false;
  double? _downloadProgress;
  int _downloadedBytes = 0;
  int _downloadTotalBytes = -1;

  @override
  void initState() {
    super.initState();
    _customModelUrlController = TextEditingController();
    _localModelId = widget.config.localModelId;
    _localBackend = widget.config.localBackend;
    _nativeEventSubscription = widget.nativeBridge.events.listen(
      _handleNativeEvent,
      onError: (_) {},
    );
    _loadInstalledModels();
  }

  @override
  void didUpdateWidget(LocalModelSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config == widget.config) return;
    _localModelId = widget.config.localModelId;
    _localBackend = widget.config.localBackend;
  }

  @override
  void dispose() {
    _nativeEventSubscription?.cancel();
    _customModelUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        DropdownButtonFormField<String>(
          initialValue: _localModelId,
          decoration: const InputDecoration(
            labelText: 'Local model',
            prefixIcon: Icon(Icons.storage_rounded),
          ),
          items: localModelCatalog
              .map(
                (model) => DropdownMenuItem<String>(
                  value: model.id,
                  child: Text(model.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _localModelId = value);
          },
        ),
        const SizedBox(height: StudyOsSpacing.sm),
        _LocalModelStatus(
          model: localModelById(_localModelId),
          installed: _installedModelFor(_localModelId),
        ),
        const SizedBox(height: StudyOsSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Accelerator',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(height: StudyOsSpacing.xs),
        SegmentedButton<LocalBackend>(
          segments: const <ButtonSegment<LocalBackend>>[
            ButtonSegment<LocalBackend>(
              value: LocalBackend.gpu,
              icon: Icon(Icons.bolt_rounded),
              label: Text('GPU'),
            ),
            ButtonSegment<LocalBackend>(
              value: LocalBackend.cpu,
              icon: Icon(Icons.memory_rounded),
              label: Text('CPU'),
            ),
          ],
          selected: <LocalBackend>{_localBackend},
          onSelectionChanged: (selection) => _selectBackend(selection.first),
        ),
        const SizedBox(height: StudyOsSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _localBackend == LocalBackend.gpu
                ? 'Runs on the GPU, falling back to CPU if unsupported.'
                : 'Forces CPU. Slower, but works on every device.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: StudyOsSpacing.md),
        TextField(
          controller: _customModelUrlController,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Direct model URL',
            hintText: 'https://.../model.litertlm',
            prefixIcon: Icon(Icons.download_rounded),
          ),
        ),
        const SizedBox(height: StudyOsSpacing.md),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                onPressed: _isDownloadingModel ? null : _downloadSelectedModel,
                icon: _isDownloadingModel
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                label: const Text('Download model'),
              ),
            ),
            const SizedBox(width: StudyOsSpacing.sm),
            if (_isDownloadingModel) ...<Widget>[
              IconButton.filledTonal(
                tooltip: 'Cancel model download',
                onPressed: _cancelModelDownload,
                icon: const Icon(Icons.close_rounded),
              ),
              const SizedBox(width: StudyOsSpacing.sm),
            ],
            IconButton.filledTonal(
              tooltip: 'Delete downloaded model',
              onPressed: _isDeletingModel || _isDownloadingModel
                  ? null
                  : _deleteSelectedModel,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        if (_isDownloadingModel) ...<Widget>[
          const SizedBox(height: StudyOsSpacing.sm),
          LinearProgressIndicator(value: _downloadProgress),
          const SizedBox(height: StudyOsSpacing.xs),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _downloadProgressLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  void _handleNativeEvent(NativeEvent event) {
    if (event.type != 'localModelDownloadProgress') return;
    if (event.modelId != _localModelId) return;
    if (!mounted) return;
    setState(() {
      _downloadProgress = event.progress;
      _downloadedBytes = event.bytesReceived ?? _downloadedBytes;
      _downloadTotalBytes = event.totalBytes ?? _downloadTotalBytes;
    });
  }

  Future<void> _loadInstalledModels() async {
    try {
      final models = await widget.nativeBridge.listLocalModels();
      if (!mounted) return;
      setState(() => _installedModels = models);
    } catch (_) {
      if (!mounted) return;
      setState(() => _installedModels = <Map<String, Object?>>[]);
    }
  }

  Future<void> _selectBackend(LocalBackend backend) async {
    if (backend == _localBackend) return;
    setState(() => _localBackend = backend);
    await widget.onSaveAgentConfig(
      widget.config.copyWith(localBackend: backend),
      null,
    );
    _showMessage(
      backend == LocalBackend.gpu
          ? 'Local model will use the GPU (CPU fallback).'
          : 'Local model will use the CPU.',
    );
  }

  Future<void> _downloadSelectedModel() async {
    final option = localModelById(_localModelId);
    final customUrl = _customModelUrlController.text.trim();
    final url = option.downloadUrl.isEmpty ? customUrl : option.downloadUrl;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _showMessage('Enter a direct HTTPS .litertlm or .task model URL.');
      return;
    }

    setState(() {
      _isDownloadingModel = true;
      _downloadProgress = null;
      _downloadedBytes = 0;
      _downloadTotalBytes = -1;
    });
    try {
      final model = await widget.nativeBridge.downloadLocalModel(
        id: option.id,
        label: option.label,
        fileName: option.fileName,
        url: url,
      );
      await _loadInstalledModels();
      await widget.onSaveAgentConfig(
        widget.config.copyWith(
          provider: AgentProvider.local,
          localModelId: option.id,
          localModelPath: model['path']?.toString() ?? '',
        ),
        null,
      );
      _showMessage('${option.label} downloaded.');
    } catch (error) {
      final message = error.toString().contains('Download cancelled')
          ? 'Model download cancelled.'
          : 'Model download failed.';
      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingModel = false;
          _downloadProgress = null;
        });
      }
    }
  }

  Future<void> _cancelModelDownload() async {
    await widget.nativeBridge.cancelLocalModelDownload();
    _showMessage('Cancelling model download...');
  }

  Future<void> _deleteSelectedModel() async {
    final installed = _installedModelFor(_localModelId);
    if (installed == null) {
      _showMessage('This model is not downloaded.');
      return;
    }
    final confirmed = await _confirmDelete(installed);
    if (!confirmed) return;

    setState(() => _isDeletingModel = true);
    try {
      final sizeLabel = _formatModelBytes(
        installed['sizeBytes'],
        suffix: ' freed',
      );
      await widget.nativeBridge.deleteLocalModel(_localModelId);
      await _loadInstalledModels();
      final nextPath = widget.config.localModelId == _localModelId
          ? ''
          : widget.config.localModelPath;
      await widget.onSaveAgentConfig(
        widget.config.copyWith(localModelPath: nextPath),
        null,
      );
      _showMessage(
        'Deleted ${installed['label'] ?? _localModelId}; $sizeLabel.',
      );
    } catch (_) {
      _showMessage('Could not delete ${installed['label'] ?? _localModelId}.');
    } finally {
      if (mounted) setState(() => _isDeletingModel = false);
    }
  }

  Future<bool> _confirmDelete(Map<String, Object?> installed) async {
    final label = installed['label']?.toString() ?? _localModelId;
    final sizeLabel = _formatModelBytes(installed['sizeBytes']);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete downloaded model?'),
        content: Text('$label uses $sizeLabel. Delete it to free space?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Map<String, Object?>? _installedModelFor(String id) {
    for (final model in _installedModels) {
      if (model['id'] == id && model['exists'] == true) return model;
    }
    return null;
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String get _downloadProgressLabel {
    final received = _formatModelBytes(_downloadedBytes, suffix: '');
    final total = _downloadTotalBytes > 0
        ? _formatModelBytes(_downloadTotalBytes, suffix: '')
        : null;
    final percent = _downloadProgress == null
        ? null
        : '${(_downloadProgress!.clamp(0, 1) * 100).toStringAsFixed(0)}%';
    if (total != null && percent != null) {
      return 'Downloading $received of $total ($percent)';
    }
    return 'Downloading $received';
  }
}

class _LocalModelStatus extends StatelessWidget {
  const _LocalModelStatus({required this.model, required this.installed});

  final LocalModelOption model;
  final Map<String, Object?>? installed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = installed == null
        ? 'Not downloaded'
        : _formatModelBytes(installed?['sizeBytes'], suffix: ' downloaded');
    final path = installed?['path']?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(StudyOsSpacing.md),
      decoration: BoxDecoration(
        color: StudyOsColors.surfaceRaised,
        borderRadius: BorderRadius.circular(StudyOsRadii.md),
        border: Border.all(color: StudyOsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(model.description, style: textTheme.bodyMedium),
          const SizedBox(height: StudyOsSpacing.xs),
          Text(size, style: textTheme.labelLarge),
          if (path != null && path.isNotEmpty) ...<Widget>[
            const SizedBox(height: StudyOsSpacing.xs),
            Text(
              path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

String _formatModelBytes(Object? value, {String suffix = ''}) {
  final bytes = switch (value) {
    int amount => amount,
    String text => int.tryParse(text) ?? 0,
    _ => 0,
  };
  if (bytes <= 0) return suffix.isEmpty ? '0 B' : 'size unknown';
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size = size / 1024;
    unit += 1;
  }
  return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unit]}$suffix';
}
