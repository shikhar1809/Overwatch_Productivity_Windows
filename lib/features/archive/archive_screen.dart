import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/app_database.dart';
import '../../data/providers.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);
    final allDays = db.listDays();
    final todayId = ref.watch(todayDayIdProvider);
    
    final pastDays = allDays.where((d) => d.id != todayId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: pastDays.isEmpty
          ? const Center(
              child: Text(
                'No past days found in the archive.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: pastDays.length,
              itemBuilder: (context, index) {
                final day = pastDays[index];
                final score = db.calculateDayScore(day.id);
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
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(
                      day.calendarDate,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Score: ${score.totalEarnedPoints} / ${score.totalBasePoints} pts',
                      style: TextStyle(color: gradeColor),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: gradeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            score.grade,
                            style: TextStyle(color: gradeColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                    onTap: () {
                    context.push('/archive/${day.id}');
                    },
                  ),
                );
              },
            ),
    );
  }
}
