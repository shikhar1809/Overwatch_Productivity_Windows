import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../services/monitor/violation_detector.dart';
import '../../services/monitor/violation_tracker.dart';

class BreakDeclarationDialog extends ConsumerStatefulWidget {
  const BreakDeclarationDialog({
    super.key,
    required this.onConfirm,
    this.currentTier = ViolationTier.none,
  });

  final void Function(int durationMinutes) onConfirm;
  final ViolationTier currentTier;

  @override
  ConsumerState<BreakDeclarationDialog> createState() =>
      _BreakDeclarationDialogState();
}

class _BreakDeclarationDialogState extends ConsumerState<BreakDeclarationDialog> {
  int _selectedDuration = 30;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.coffee, color: Colors.amber),
          SizedBox(width: 8),
          Text('Declare Break'),
        ],
      ),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monitoring will be paused during your break. '
              'The break will be logged and shown in your night review.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textColor,
                  ),
            ),
            const SizedBox(height: 20),
            Text(
              'Break Duration',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [15, 30, 45, 60].map((duration) {
                final isSelected = _selectedDuration == duration;
                return ChoiceChip(
                  label: Text('$duration min'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDuration = duration);
                    }
                  },
                  selectedColor:
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your current violation count will be preserved. '
                      'If you exceed 2 violations, the slot will be compromised.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade200),
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
        FilledButton.icon(
          onPressed: () {
            widget.onConfirm(_selectedDuration);
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Break'),
        ),
      ],
    );
  }
}

class ActiveBreakBanner extends StatelessWidget {
  const ActiveBreakBanner({
    super.key,
    required this.remainingMinutes,
    required this.onEnd,
  });

  final int remainingMinutes;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.coffee, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Break in progress',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
                Text(
                  '$remainingMinutes minutes remaining',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade200,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onEnd,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
            ),
            child: const Text('End Early'),
          ),
        ],
      ),
    );
  }
}
