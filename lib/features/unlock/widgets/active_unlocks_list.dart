import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/app_database.dart';
import '../../../data/providers.dart';

class ActiveUnlocksList extends ConsumerWidget {
  const ActiveUnlocksList({
    super.key,
    required this.onRevoke,
    required this.onRefresh,
  });

  final void Function(UnlockSessionRow) onRevoke;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(activeUnlocksRefreshProvider);
    final activeSessions = ref.watch(activeUnlockSessionsProvider);

    if (activeSessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timer_off,
              size: 64,
              color: Colors.black.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No active unlocks',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unlocked apps will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black38,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: activeSessions.length,
      itemBuilder: (context, i) {
        final session = activeSessions[i];
        return _ActiveUnlockCard(
          session: session,
          onRevoke: () => onRevoke(session),
        );
      },
    );
  }
}

class _ActiveUnlockCard extends StatelessWidget {
  const _ActiveUnlockCard({
    required this.session,
    required this.onRevoke,
  });

  final UnlockSessionRow session;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final progress = _calculateProgress();
    final remaining = session.remainingSeconds;
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;

    Color statusColor;
    if (remaining <= 60) {
      statusColor = Colors.red;
    } else if (remaining <= 300) {
      statusColor = Colors.amber;
    } else {
      statusColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      session.appName[0],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.appName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.intent,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'remaining',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.black.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(statusColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Started ${_formatTime(session.startedAt)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                OutlinedButton.icon(
                  onPressed: onRevoke,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Revoke'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _calculateProgress() {
    final elapsed = DateTime.now().difference(session.startedAt).inSeconds;
    final total = session.durationMin * 60;
    if (total == 0) return 0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
