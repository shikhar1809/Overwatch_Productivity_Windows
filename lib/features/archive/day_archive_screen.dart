import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_database.dart';
import '../../data/providers.dart';

class DayArchiveScreen extends ConsumerWidget {
  const DayArchiveScreen({super.key, required this.dayId});
  final String dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final score = db.calculateDayScore(dayId);
    
    final days = db.listDays();
    final dayRow = days.firstWhere((d) => d.id == dayId, orElse: () => DayRow(id: '', calendarDate: 'Unknown Date', createdAtMs: 0));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('${dayRow.calendarDate} Archive', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScoreSummary(context, score),
            const SizedBox(height: 24),
            _buildStatCard(context, 'Tasks', '${score.tasksCompleted} / ${score.totalTasks}', Icons.task_alt, Colors.blue),
            const SizedBox(height: 12),
            _buildStatCard(context, 'Slots Committed', '${score.slotsCompleted} / ${score.totalCommittedSlots}', Icons.timer, Colors.purple),
            const SizedBox(height: 12),
            _buildStatCard(context, 'Violations', '${score.violationCount}', Icons.warning, score.violationCount > 0 ? Colors.red : Colors.green),
            const SizedBox(height: 12),
            _buildStatCard(context, 'Checklist Items', '${score.checklistDone} / ${score.totalChecklistItems}', Icons.checklist, Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSummary(BuildContext context, DayScore score) {
    Color gradeColor;
    switch (score.grade) {
      case 'S': gradeColor = Colors.purple; break;
      case 'A': gradeColor = Colors.green; break;
      case 'B': gradeColor = Colors.blue; break;
      case 'C': gradeColor = Colors.orange; break;
      case 'F': gradeColor = Colors.red; break;
      default: gradeColor = Colors.grey; break;
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text('Final Grade', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                score.grade,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: gradeColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${score.totalEarnedPoints} / ${score.totalBasePoints} pts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (score.fallPoints > 0) ...[
              const SizedBox(height: 8),
              Text(
                '-${score.fallPoints} Fall Points',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
