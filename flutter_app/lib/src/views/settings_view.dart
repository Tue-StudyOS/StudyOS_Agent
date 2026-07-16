import 'package:flutter/material.dart';

import '../assistant_copy.dart';
import '../models.dart';
import '../native_bridge.dart';
import '../studyos_theme.dart';
import '../widgets/feedback_settings_card.dart';
import '../widgets/cloud_assistant_settings.dart';
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
          localBackend: widget.config.localBackend,
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
      padding: const EdgeInsets.only(
        top: StudyOsSpacing.xl,
        bottom: StudyOsSpacing.xxl,
      ),
      children: <Widget>[
        Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(
          'Your account, assistant, and app preferences.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: StudyOsSpacing.xxl),
        _SettingsSection(
          title: 'Account',
          child: SettingsCard(
            children: <Widget>[
              ProfileRow(profile: widget.profile, onEdit: _editProfile),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.logout_rounded,
                  color: StudyOsColors.destructive,
                ),
                title: const Text('Log out'),
                subtitle: Text(
                  widget.profile == null
                      ? 'No active profile session'
                      : 'Sign out from this device',
                ),
                enabled: widget.onLogout != null,
                onTap: widget.onLogout,
              ),
            ],
          ),
        ),
        const SizedBox(height: StudyOsSpacing.xl),
        _SettingsSection(
          title: 'Appearance',
          child: SettingsCard(
            children: <Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compact chat'),
                subtitle: const Text('Use tighter spacing in conversations.'),
                value: widget.compactMessages,
                onChanged: widget.onCompactMessagesChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: StudyOsSpacing.xl),
        _SettingsSection(
          title: 'Assistant',
          child: SettingsCard(
            children: <Widget>[
              _AssistantSummary(status: widget.status, config: widget.config),
              const Divider(),
              SegmentedButton<AgentProvider>(
                segments: const <ButtonSegment<AgentProvider>>[
                  ButtonSegment<AgentProvider>(
                    value: AgentProvider.local,
                    icon: Icon(Icons.memory_rounded),
                    label: Text('On device'),
                  ),
                  ButtonSegment<AgentProvider>(
                    value: AgentProvider.cloud,
                    icon: Icon(Icons.cloud_outlined),
                    label: Text('Custom'),
                  ),
                ],
                selected: <AgentProvider>{_provider},
                onSelectionChanged: (value) =>
                    setState(() => _provider = value.first),
              ),
              const SizedBox(height: StudyOsSpacing.lg),
              if (!isCloud)
                LocalModelSettingsCard(
                  config: widget.config,
                  nativeBridge: widget.nativeBridge,
                  onSaveAgentConfig: widget.onSaveAgentConfig,
                )
              else
                CloudAssistantSettings(
                  endpointController: _endpointController,
                  modelController: _modelController,
                  apiKeyController: _apiKeyController,
                  hasApiKey: widget.config.hasApiKey,
                  isSaving: _isSaving,
                  onSave: _save,
                ),
            ],
          ),
        ),
        const SizedBox(height: StudyOsSpacing.xl),
        _SettingsSection(
          title: 'Support',
          child: SettingsCard(children: const <Widget>[FeedbackSettingsCard()]),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: StudyOsColors.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
      const SizedBox(height: StudyOsSpacing.sm),
      child,
    ],
  );
}

class _AssistantSummary extends StatelessWidget {
  const _AssistantSummary({required this.status, required this.config});

  final String status;
  final AgentConfig config;

  @override
  Widget build(BuildContext context) {
    final ready = assistantIsReady(status);
    final color = ready ? StudyOsColors.success : StudyOsColors.warning;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(Icons.auto_awesome_outlined, color: color),
      ),
      title: Text(assistantStatusLabel(status)),
      subtitle: Text(assistantSetupLabel(config)),
    );
  }
}
