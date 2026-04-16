import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(todaySlotsProvider);
    final score = ref.watch(todayScoreProvider);
    final isSubmitted = ref.watch(areTasksSubmittedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, score, isSubmitted),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: _buildTaskList(context, ref),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: _buildTimeGrid(context, ref, slots),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(todayTasksProvider);
    final sortedTasks = List<TaskRow>.from(tasks)
      ..sort((a, b) {
        int getPriorityValue(String priority) {
          switch (priority) {
            case 'red': return 1;
            case 'amber': return 2;
            case 'green': return 3;
            default: return 4;
          }
        }
        return getPriorityValue(a.priority).compareTo(getPriorityValue(b.priority));
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            if (sortedTasks.isEmpty)
              Text('No tasks added yet.', style: TextStyle(color: context.textColorSecondary))
            else
              ...sortedTasks.map((t) {
                Color priorityColor;
                switch (t.priority) {
                  case 'red': priorityColor = Colors.red; break;
                  case 'amber': priorityColor = Colors.amber; break;
                  default: priorityColor = Colors.green;
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: priorityColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            Text('${t.basePoints} pts', style: TextStyle(fontSize: 11, color: priorityColor)),
                          ],
                        ),
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

  Widget _buildHeader(BuildContext context, DayScore score, bool isSubmitted) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plan', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                isSubmitted
                    ? 'Day plan locked - focus on execution!'
                    : 'Your today plan preview',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isSubmitted ? Colors.green : context.textColor,
                    ),
              ),
            ],
          ),
        ),
        _buildScoreBadge(context, score),
      ],
    );
  }

  Widget _buildScoreBadge(BuildContext context, DayScore score) {
    Color gradeColor;
    switch (score.grade) {
      case 'S':
        gradeColor = Colors.purple;
        break;
      case 'A':
        gradeColor = Colors.green;
        break;
      case 'B':
        gradeColor = Colors.blue;
        break;
      case 'C':
        gradeColor = Colors.orange;
        break;
      case 'F':
        gradeColor = Colors.red;
        break;
      default:
        gradeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: gradeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gradeColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            '${score.totalEarnedPoints}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: gradeColor,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '/ ${score.totalBasePoints} pts',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.textColorSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeGrid(BuildContext context, WidgetRef ref, List<SlotRow> slots) {
    final tasks = ref.watch(todayTasksProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_on, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('24-Hour Schedule', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: SingleChildScrollView(
                child: _TimeGridView(
                  slots: slots,
                  tasks: tasks,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeGridView extends StatelessWidget {
  const _TimeGridView({
    required this.slots,
    required this.tasks,
  });

  final List<SlotRow> slots;
  final List<TaskRow> tasks;

  static const double hourHeight = 40.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24 * hourHeight,
      child: Stack(
        children: [
          Column(
            children: [
              for (int h = 0; h < 24; h++)
                SizedBox(
                  height: hourHeight,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text(
                          '${h.toString().padLeft(2, '0')}:00',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.textColorSecondary,
                              ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: context.isDarkMode 
                                    ? Colors.white.withValues(alpha: 0.1) 
                                    : Colors.black.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          ...slots.map((slot) {
            final top = slot.startMinute / 60 * hourHeight;
            final height = (slot.endMinute - slot.startMinute) / 60 * hourHeight;
            final task = slot.taskId != null
                ? tasks.cast<TaskRow?>().firstWhere(
                      (t) => t?.id == slot.taskId,
                      orElse: () => null,
                    )
                : null;

            Color slotColor;
            if (slot.forfeited) {
              slotColor = Colors.red.withValues(alpha: 0.3);
            } else if (slot.cp100 == 1) {
              slotColor = Colors.green.withValues(alpha: 0.3);
            } else if (slot.committed) {
              slotColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.3);
            } else {
              slotColor = Colors.grey.withValues(alpha: 0.2);
            }

            return Positioned(
              top: top,
              left: 50,
              right: 8,
              height: height.clamp(30, double.infinity),
              child: Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: slotColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: slot.committed 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey,
                    width: slot.committed ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot.label.isNotEmpty ? slot.label : (task?.title ?? 'Slot'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (slot.committed) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (slot.cp20 == 1) _buildCheckpointBadge('20%', Colors.green),
                          if (slot.cp50 == 1) _buildCheckpointBadge('50%', Colors.blue),
                          if (slot.cp100 == 1) _buildCheckpointBadge('100%', Colors.purple),
                          if (slot.forfeited) _buildCheckpointBadge('FORFEITED', Colors.red),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCheckpointBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, color: Colors.white),
      ),
    );
  }
}
