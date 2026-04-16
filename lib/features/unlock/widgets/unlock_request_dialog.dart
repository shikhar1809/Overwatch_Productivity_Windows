import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/app_database.dart';
import '../../../data/providers.dart';

class UnlockRequestDialog extends StatefulWidget {
  const UnlockRequestDialog({
    super.key,
    required this.app,
    required this.onUnlock,
  });

  final dynamic app;
  final void Function(String intent, int duration) onUnlock;

  @override
  State<UnlockRequestDialog> createState() => _UnlockRequestDialogState();
}

class _UnlockRequestDialogState extends State<UnlockRequestDialog> {
  final _intentController = TextEditingController();
  int _selectedDuration = 30;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _intentController.dispose();
    super.dispose();
  }

  bool get _isValid {
    return _intentController.text.trim().length >= 20 && _acceptedTerms;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.lock_open, color: Colors.amber),
          const SizedBox(width: 8),
          Text('Unlock ${widget.app.name}'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What will you be doing?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _intentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Describe your intent for using ${widget.app.name}...',
                border: const OutlineInputBorder(),
                helperText: 'Minimum 20 characters',
                helperStyle: TextStyle(
                  color: _intentController.text.length >= 20
                      ? Colors.green
                      : Colors.amber,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text(
              'Duration',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [15, 20, 30, 45, 60, 90].map((duration) {
                final isSelected = _selectedDuration == duration;
                return ChoiceChip(
                  label: Text('$duration min'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDuration = duration);
                    }
                  },
                  selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              title: const Text(
                'I understand this time will be logged and may affect my daily score',
                style: TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'YouTube access requires Unhook extension active. Screen monitoring remains enabled.',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade200),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isValid
              ? () {
                  widget.onUnlock(
                    _intentController.text.trim(),
                    _selectedDuration,
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
