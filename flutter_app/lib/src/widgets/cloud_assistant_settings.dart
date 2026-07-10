import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class CloudAssistantSettings extends StatelessWidget {
  const CloudAssistantSettings({
    required this.endpointController,
    required this.modelController,
    required this.apiKeyController,
    required this.hasApiKey,
    required this.isSaving,
    required this.onSave,
    super.key,
  });

  final TextEditingController endpointController;
  final TextEditingController modelController;
  final TextEditingController apiKeyController;
  final bool hasApiKey;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      TextField(
        controller: endpointController,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(
          labelText: 'Server URL',
          hintText: 'https://api.example.com/v1/chat/completions',
          prefixIcon: Icon(Icons.link_rounded),
        ),
      ),
      const SizedBox(height: StudyOsSpacing.md),
      TextField(
        controller: modelController,
        decoration: const InputDecoration(
          labelText: 'Model',
          hintText: 'gpt-4.1-mini',
          prefixIcon: Icon(Icons.tune_rounded),
        ),
      ),
      const SizedBox(height: StudyOsSpacing.md),
      TextField(
        controller: apiKeyController,
        obscureText: true,
        decoration: InputDecoration(
          labelText: 'API key',
          helperText: hasApiKey
              ? 'An API key is saved securely on this device.'
              : 'Stored securely on this device.',
          prefixIcon: const Icon(Icons.key_rounded),
        ),
      ),
      const SizedBox(height: StudyOsSpacing.lg),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isSaving ? null : onSave,
          icon: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Save custom assistant'),
        ),
      ),
    ],
  );
}
