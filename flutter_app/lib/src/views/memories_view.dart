import 'package:flutter/material.dart';

import '../studyos_theme.dart';

class MemoriesView extends StatefulWidget {
  const MemoriesView({
    required this.worldState,
    required this.memoryText,
    required this.onSaveMemory,
    super.key,
  });

  final Map<String, Object?> worldState;
  final String memoryText;
  final Future<void> Function(String text) onSaveMemory;

  @override
  State<MemoriesView> createState() => _MemoriesViewState();
}

class _MemoriesViewState extends State<MemoriesView> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.memoryText.trim());
  }

  @override
  void didUpdateWidget(MemoriesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memoryText == widget.memoryText) return;
    _controller.text = widget.memoryText.trim();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await widget.onSaveMemory(_controller.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Notes saved.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: StudyOsSpacing.sm),
      children: <Widget>[
        _SectionHeader(
          title: 'Personal notes',
          description: 'Things StudyOS can remember for future chats.',
        ),
        const SizedBox(height: StudyOsSpacing.lg),
        _MemoryEditor(
          controller: _controller,
          isSaving: _isSaving,
          onSave: _save,
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: StudyOsSpacing.xs),
        Text(description, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MemoryEditor extends StatelessWidget {
  const _MemoryEditor({
    required this.controller,
    required this.isSaving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(StudyOsSpacing.lg),
      decoration: BoxDecoration(
        color: StudyOsColors.surface,
        border: Border.all(color: StudyOsColors.border),
        borderRadius: BorderRadius.circular(StudyOsRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Saved notes', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: StudyOsSpacing.sm),
          TextField(
            controller: controller,
            minLines: 10,
            maxLines: 18,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: '- Favorite food: lasagne\n- Studies best in mornings',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: StudyOsSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save notes'),
            ),
          ),
        ],
      ),
    );
  }
}
