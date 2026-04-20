import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';

final todayDistractionsProvider = Provider<List<HallOfShameRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.listHallOfShameForDay(dayId);
});

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionPoints = ref.watch(todaySessionPointsProvider);
    final sessions = ref.watch(todaySessionsProvider);
    final distractions = ref.watch(todayDistractionsProvider);
    final attendedSessions = sessions.where((s) => s.attended).toList();
    
    final totalCoverage = attendedSessions.fold<int>(
      0,
      (sum, s) => sum + (s.coveragePercent ?? 0),
    );
    final avgCoverage = attendedSessions.isEmpty
        ? 0
        : (totalCoverage / attendedSessions.length).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          _buildTodayStats(context, sessionPoints, attendedSessions.length, avgCoverage),
          const SizedBox(height: 24),
          _buildSessionHistory(context, sessions, distractions),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bar_chart_outlined, color: Colors.blue, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stats',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Your session statistics and progress',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.textColorSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayStats(BuildContext context, int points, int attendedCount, int avgCoverage) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, size: 20, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Text("Today's Sessions", style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    context,
                    icon: Icons.stars,
                    iconColor: Colors.green,
                    label: 'Points Earned',
                    value: '$points',
                    subtitle: 'pts',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    context,
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.blue,
                    label: 'Sessions',
                    value: '$attendedCount',
                    subtitle: 'attended',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    context,
                    icon: Icons.percent,
                    iconColor: Colors.purple,
                    label: 'Avg Coverage',
                    value: '$avgCoverage',
                    subtitle: '%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: context.textColorSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: context.textColorSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHistory(BuildContext context, List sessions, List<HallOfShameRow> allDistractions) {
    if (sessions.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.timer_off_outlined,
                  size: 48,
                  color: context.textColorTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No sessions yet',
                  style: TextStyle(color: context.textColorSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete a session to see your history',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textColorTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 20, color: context.textColorSecondary),
                const SizedBox(width: 8),
                Text('Session History', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final session = sessions[i];
                final coverage = session.coveragePercent ?? 0;
                final coverageColor = coverage >= 75
                    ? Colors.green
                    : coverage >= 50
                        ? Colors.orange
                        : Colors.red;

                final sessionDistractions = allDistractions
                    .where((d) => d.sessionId == session.id)
                    .toList();

                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: session.attended
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      session.attended ? Icons.check_circle : Icons.cancel,
                      color: session.attended ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    session.goal,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${session.durationMinutes} min • ${_formatTime(session.startedAtMs)}',
                    style: TextStyle(fontSize: 11, color: context.textColorSecondary),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${session.pointsEarned} pts',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade400,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: coverageColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$coverage%',
                              style: TextStyle(
                                fontSize: 11,
                                color: coverageColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (sessionDistractions.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber, size: 12, color: Colors.red),
                              const SizedBox(width: 2),
                              Text(
                                '${sessionDistractions.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  children: sessionDistractions.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.only(left: 56, bottom: 12),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_outline, size: 14, color: Colors.green.shade400),
                                const SizedBox(width: 6),
                                Text(
                                  'No distractions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : sessionDistractions.map((d) {
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.only(left: 56, right: 16),
                            leading: const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                            title: Text(
                              d.reason,
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              _formatTimestamp(d.createdAtMs),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textColorSecondary,
                              ),
                            ),
                          );
                        }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatTimestamp(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
