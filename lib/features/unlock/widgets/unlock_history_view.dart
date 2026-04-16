import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';

class UnlockHistoryView extends ConsumerWidget {
  const UnlockHistoryView({super.key, required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalUnlocks = stats['totalUnlocks'] as int? ?? 0;
    final completedUnlocks = stats['completedUnlocks'] as int? ?? 0;
    final totalMinutes = stats['totalMinutes'] as int? ?? 0;
    final mostUnlocked = stats['mostUnlocked'] as String? ?? 'None';
    final appCounts = stats['appCounts'] as Map<String, int>? ?? {};
    final appMinutes = stats['appMinutes'] as Map<String, int>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Unlock Statistics',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          _buildStatsGrid(context, totalUnlocks, completedUnlocks, totalMinutes),
          const SizedBox(height: 24),
          if (mostUnlocked != 'None') ...[
            Text(
              'Most Unlocked: $mostUnlocked',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            _buildAppBreakdown(context, appCounts, appMinutes),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: Colors.black.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No unlock history yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _buildTipsCard(context),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    BuildContext context,
    int total,
    int completed,
    int minutes,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Unlocks',
            value: '$total',
            icon: Icons.lock_open,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Completed',
            value: '$completed',
            icon: Icons.check_circle,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Minutes',
            value: '$minutes',
            icon: Icons.timer,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildAppBreakdown(
    BuildContext context,
    Map<String, int> counts,
    Map<String, int> minutes,
  ) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Breakdown by App',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            ...entries.take(5).map((entry) {
              final appName = entry.key;
              final count = entry.value;
              final mins = minutes[appName] ?? 0;
              final percentage = counts.values.isNotEmpty
                  ? (count / counts.values.reduce((a, b) => a + b) * 100).round()
                  : 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _getAppColor(appName).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          appName[0],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getAppColor(appName),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.black.withValues(alpha: 0.1),
                              valueColor: AlwaysStoppedAnimation(
                                _getAppColor(appName),
                              ),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$count times',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          '${mins}min',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard(BuildContext context) {
    return Card(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Tips for Better Focus',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.blue,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _TipItem(
              icon: Icons.short_text,
              text: 'Be specific with your intent statements',
            ),
            const _TipItem(
              icon: Icons.timer,
              text: 'Set shorter durations to stay focused',
            ),
            const _TipItem(
              icon: Icons.check_circle,
              text: 'Complete red tasks before unlocking apps',
            ),
          ],
        ),
      ),
    );
  }

  Color _getAppColor(String appName) {
    switch (appName.toLowerCase()) {
      case 'youtube':
        return Colors.red;
      case 'facebook':
        return Colors.blue;
      case 'twitter':
        return Colors.black;
      case 'reddit':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  const _TipItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
