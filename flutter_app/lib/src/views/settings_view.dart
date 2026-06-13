import 'package:flutter/material.dart';

import '../models.dart';
import '../native_bridge.dart';
import '../studyos_theme.dart';
import '../widgets/assistant_status_card.dart';
import '../widgets/feedback_settings_card.dart';
import '../widgets/local_model_settings_card.dart';
import '../widgets/profile_row.dart';
import '../widgets/settings_card.dart';
import 'profile_edit_view.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({
    required this.config,
    required this.profile,
    required this.status,
    required this.compactMessages,
    required this.onLogout,
    required this.onSaveAgentConfig,
    required this.onSaveProfile,
    required this.onCompactMessagesChanged,
    required this.nativeBridge,
    super.key,
  });

  final AgentConfig config;
  final OnboardingProfile? profile;
  final String status;
  final bool compactMessages;
  final VoidCallback? onLogout;
  final Future<void> Function(AgentConfig config, String? apiKey)
  onSaveAgentConfig;
  final Future<void> Function(OnboardingProfile profile) onSaveProfile;
  final ValueChanged<bool> onCompactMessagesChanged;
  final NativeBridge nativeBridge;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late AgentProvider _provider;
  late final TextEditingController _endpointController;
  late final TextEditingController _modelController;
  late final TextEditingController _apiKeyController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _provider = widget.config.provider;
    _endpointController = TextEditingController(
      text: widget.config.cloudEndpoint,
    );
    _modelController = TextEditingController(text: widget.config.cloudModel);
    _apiKeyController = TextEditingController();
  }

  @override
  void didUpdateWidget(SettingsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config == widget.config) return;
    _provider = widget.config.provider;
    _endpointController.text = widget.config.cloudEndpoint;
    _modelController.text = widget.config.cloudModel;
    _apiKeyController.clear();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final endpoint = _endpointController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    if (_provider == AgentProvider.cloud) {
      final uri = Uri.tryParse(endpoint);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        _showMessage('Enter a valid custom AI server URL.');
        return;
      }
      if (model.isEmpty) {
        _showMessage('Enter a model name.');
        return;
      }
      if (!widget.config.hasApiKey && apiKey.isEmpty) {
        _showMessage('Enter an API key to store securely.');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSaveAgentConfig(
        AgentConfig(
          provider: _provider,
          cloudEndpoint: endpoint,
          cloudModel: model,
          hasApiKey: widget.config.hasApiKey || apiKey.isNotEmpty,
          localModelId: widget.config.localModelId,
          localModelPath: widget.config.localModelPath,
        ),
        apiKey.isEmpty ? null : apiKey,
      );
      _apiKeyController.clear();
      _showMessage('Assistant setup saved.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editProfile() async {
    final profile = widget.profile;
    if (profile == null) return;
    final updated = await Navigator.of(context).push<OnboardingProfile>(
      MaterialPageRoute<OnboardingProfile>(
        builder: (_) => ProfileEditView(profile: profile),
      ),
    );
    if (updated == null) return;
    await widget.onSaveProfile(updated);
    _showMessage('Profile saved.');
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final isCloud = _provider == AgentProvider.cloud;
    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(
          'Profile, assistant, feedback, and app preferences.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        SettingsCard(
          children: <Widget>[
            ProfileRow(profile: widget.profile, onEdit: _editProfile),
            const Divider(color: StudyOsColors.border),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout'),
              subtitle: Text(
                widget.profile == null
                    ? 'No active profile session'
                    : 'End this app session',
              ),
              enabled: widget.onLogout != null,
              onTap: widget.onLogout,
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        SettingsCard(
          children: <Widget>[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Compact message layout'),
              subtitle: const Text(
                'Use tighter chat spacing on small screens.',
              ),
              value: widget.compactMessages,
              onChanged: widget.onCompactMessagesChanged,
            ),
          ],
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        FeedbackSettingsCard(status: widget.status),
        const SizedBox(height: StudyOsSpacing.lg),
        AssistantStatusCard(status: widget.status, config: widget.config),
        const SizedBox(height: StudyOsSpacing.lg),
        SettingsCard(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Assistant setup',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: StudyOsSpacing.md),
            SegmentedButton<AgentProvider>(
              segments: const <ButtonSegment<AgentProvider>>[
                ButtonSegment<AgentProvider>(
                  value: AgentProvider.local,
                  icon: Icon(Icons.memory_rounded),
                  label: Text('Built-in'),
                ),
                ButtonSegment<AgentProvider>(
                  value: AgentProvider.cloud,
                  icon: Icon(Icons.cloud_outlined),
                  label: Text('Custom'),
                ),
              ],
              selected: <AgentProvider>{_provider},
              onSelectionChanged: (value) {
                setState(() => _provider = value.first);
              },
            ),
            const SizedBox(height: StudyOsSpacing.md),
            if (!isCloud) ...<Widget>[
              LocalModelSettingsCard(
                config: widget.config,
                nativeBridge: widget.nativeBridge,
                onSaveAgentConfig: widget.onSaveAgentConfig,
              ),
              const SizedBox(height: StudyOsSpacing.lg),
            ],
            TextField(
              controller: _endpointController,
              enabled: isCloud,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Custom AI server',
                hintText: 'https://api.example.com/v1/chat/completions',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: StudyOsSpacing.md),
            TextField(
              controller: _modelController,
              enabled: isCloud,
              decoration: const InputDecoration(
                labelText: 'Model name',
                hintText: 'gpt-4.1-mini',
                prefixIcon: Icon(Icons.tune_rounded),
              ),
            ),
            const SizedBox(height: StudyOsSpacing.md),
            TextField(
              controller: _apiKeyController,
              enabled: isCloud,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API key',
                helperText: widget.config.hasApiKey
                    ? 'Saved securely on this device.'
                    : 'Stored securely on this device.',
                prefixIcon: const Icon(Icons.key_rounded),
              ),
            ),
            const SizedBox(height: StudyOsSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save assistant setup'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
