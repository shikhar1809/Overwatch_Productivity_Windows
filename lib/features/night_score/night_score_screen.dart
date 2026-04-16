import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';

class NightScoreScreen extends ConsumerStatefulWidget {
  const NightScoreScreen({super.key});

  @override
  ConsumerState<NightScoreScreen> createState() => _NightScoreScreenState();
}

class _NightScoreScreenState extends ConsumerState<NightScoreScreen> {
  final _zeroNoteController = TextEditingController();
  String? _editingTaskId;

  @override
  void dispose() {
    _zeroNoteController.dispose();
    super.dispose();
  }

  void _showZeroNoteDialog(String taskId, String taskTitle) {
    _editingTaskId = taskId;
    _zeroNoteController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zero Note Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Task: $taskTitle'),
            const SizedBox(height: 8),
            Text(
              'You marked this task as 0% complete. Please explain why:',
              style: TextStyle(color: ctx.textColorSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _zeroNoteController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'What happened? What will you do differently?',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final note = _zeroNoteController.text.trim();
              if (note.isNotEmpty) {
                final db = ref.read(appDatabaseProvider);
                db.setTaskZeroNote(taskId, note);
                ref.invalidate(todayTasksProvider);
                ref.invalidate(todayScoreProvider);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final score = ref.watch(todayScoreProvider);
    final tasks = ref.watch(todayTasksProvider);
    final slots = ref.watch(todaySlotsProvider);
    final violations = ref.watch(todayViolationsProvider);
    final db = ref.watch(appDatabaseProvider);
    final dayId = ref.watch(todayDayIdProvider);

    final zeroNoteTasks = tasks.where((t) => !t.completed && t.zeroNote == null).toList();
    final incompleteTasks = tasks.where((t) => !t.completed).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, score),
          const SizedBox(height: 24),
          _buildScoreCard(context, score),
          const SizedBox(height: 24),
          _buildSection(
            context,
            'Task Summary',
            Icons.task_alt,
            _buildTaskSummary(context, tasks, score),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            'Slot Breakdown',
            Icons.timer,
            _buildSlotBreakdown(context, slots, tasks),
          ),
          const SizedBox(height: 24),
          if (violations.isNotEmpty) ...[
            _buildSection(
              context,
              'Violations (${violations.length})',
              Icons.warning,
              _buildViolationsList(context, violations, tasks),
            ),
            const SizedBox(height: 24),
          ],
          if (zeroNoteTasks.isNotEmpty) ...[
            _buildSection(
              context,
              'Pending Zero Notes (${zeroNoteTasks.length})',
              Icons.note_add,
              _buildZeroNotesSection(context, zeroNoteTasks),
            ),
            const SizedBox(height: 24),
          ],
          _buildSection(
            context,
            'Statistics',
            Icons.analytics,
            _buildStatistics(context, score, tasks),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DayScore score) {
    final now = DateTime.now();
    final dateStr = '${_weekdayName(now.weekday)}, ${_monthName(now.month)} ${now.day}';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Night Score', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.textColorSecondary),
              ),
            ],
          ),
        ),
        _buildGradeBadge(context, score.grade),
      ],
    );
  }

  Widget _buildGradeBadge(BuildContext context, String grade) {
    Color gradeColor;
    IconData gradeIcon;

    switch (grade) {
      case 'S':
        gradeColor = Colors.purple;
        gradeIcon = Icons.star;
        break;
      case 'A':
        gradeColor = Colors.green;
        gradeIcon = Icons.check_circle;
        break;
      case 'B':
        gradeColor = Colors.blue;
        gradeIcon = Icons.thumb_up;
        break;
      case 'C':
        gradeColor = Colors.orange;
        gradeIcon = Icons.trending_flat;
        break;
      case 'F':
        gradeColor = Colors.red;
        gradeIcon = Icons.thumb_down;
        break;
      default:
        gradeColor = Colors.grey;
        gradeIcon = Icons.help;
    }

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: gradeColor.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: gradeColor, width: 3),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(gradeIcon, color: gradeColor, size: 24),
          Text(
            grade,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: gradeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context, DayScore score) {
    final earnedPct = score.totalBasePoints > 0
        ? (score.totalEarnedPoints / score.totalBasePoints * 100).round()
        : 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${score.totalEarnedPoints}',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  Text(
                    'of ${score.totalBasePoints} points',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: context.textColorSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: score.totalBasePoints > 0
                        ? score.totalEarnedPoints / score.totalBasePoints
                        : 0,
                    backgroundColor: context.dividerColor,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$earnedPct% efficiency',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.textColorSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: [
                  _buildScoreRow(context, 'Tasks', '${score.tasksCompleted}/${score.totalTasks}', score.totalTasks > 0 && score.tasksCompleted == score.totalTasks ? Colors.green : context.textColor),
                  const SizedBox(height: 8),
                  _buildScoreRow(context, 'Slots Done', '${score.slotsCompleted}/${score.totalCommittedSlots}', score.slotsCompleted == score.totalCommittedSlots && score.totalCommittedSlots > 0 ? Colors.green : context.textColor),
                  const SizedBox(height: 8),
                  _buildScoreRow(context, 'Violations', '${score.violationCount}', score.violationCount == 0 ? Colors.green : Colors.amber),
                  const SizedBox(height: 8),
                  _buildScoreRow(context, 'Fall Points', '-${score.fallPoints}', score.fallPoints == 0 ? Colors.green : Colors.amber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(BuildContext context, String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.textColor)),
        Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: valueColor)),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    Widget content,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSummary(BuildContext context, List<TaskRow> tasks, DayScore score) {
    if (tasks.isEmpty) {
      return Text('No tasks today', style: TextStyle(color: context.textColorSecondary));
    }

    return Column(
      children: tasks.map((task) {
        Color priorityColor;
        switch (task.priority) {
          case 'red':
            priorityColor = Colors.red;
            break;
          case 'amber':
            priorityColor = Colors.amber;
            break;
          default:
            priorityColor = Colors.green;
        }

        final checkpointsHit = task.compromised ? 2 : task.violationCount;
        int earnedPoints = 0;
        if (task.completed) {
          earnedPoints = task.basePoints;
        } else if (checkpointsHit >= 2) {
          earnedPoints = (task.basePoints * 0.5).round();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        decoration: task.completed ? TextDecoration.lineThrough : null,
                        color: task.completed ? context.textColorSecondary : context.textColor,
                      ),
                    ),
                    Text(
                      '${task.priority.toUpperCase()} · $earnedPoints / ${task.basePoints} pts',
                      style: TextStyle(fontSize: 12, color: priorityColor),
                    ),
                  ],
                ),
              ),
              if (task.completed)
                const Icon(Icons.check_circle, color: Colors.green, size: 20)
              else if (task.forfeited)
                const Icon(Icons.block, color: Colors.red, size: 20)
              else if (task.zeroNote != null)
                const Icon(Icons.note, color: Colors.amber, size: 20)
              else if (task.violationCount > 0)
                const Icon(Icons.warning, color: Colors.amber, size: 20),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSlotBreakdown(BuildContext context, List<SlotRow> slots, List<TaskRow> tasks) {
    final committedSlots = slots.where((s) => s.committed).toList();

    if (committedSlots.isEmpty) {
      return Text('No committed slots today', style: TextStyle(color: context.textColorSecondary));
    }

    return Column(
      children: committedSlots.map((slot) {
        final task = slot.taskId != null
            ? tasks.cast<TaskRow?>().firstWhere(
                  (t) => t?.id == slot.taskId,
                  orElse: () => null,
                )
            : null;

        Color statusColor;
        String statusText;
        if (slot.forfeited) {
          statusColor = Colors.red;
          statusText = 'Forfeited';
        } else if (slot.cp100 == 1) {
          statusColor = Colors.green;
          statusText = 'Complete';
        } else if (slot.cp50 == 1) {
          statusColor = Colors.blue;
          statusText = '50%';
        } else if (slot.cp20 == 1) {
          statusColor = Colors.amber;
          statusText = '20%';
        } else {
          statusColor = Colors.grey;
          statusText = 'Started';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 80,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  slot.timeRange,
                  style: TextStyle(fontSize: 12, color: context.textColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  slot.label.isNotEmpty ? slot.label : (task?.title ?? 'Unnamed slot'),
                  style: TextStyle(
                    color: slot.forfeited ? context.textColorSecondary : context.textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (slot.cp20 == 1) _buildMiniCheck(true),
                    if (slot.cp50 == 1) _buildMiniCheck(true),
                    if (slot.cp100 == 1) _buildMiniCheck(true),
                    if (slot.forfeited) const Icon(Icons.close, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniCheck(bool reached) {
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Icon(
        reached ? Icons.check : Icons.circle_outlined,
        size: 12,
        color: reached ? Colors.green : Colors.grey,
      ),
    );
  }

  Widget _buildViolationsList(BuildContext context, List<ViolationRow> violations, List<TaskRow> tasks) {
    if (violations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 20),
            SizedBox(width: 8),
            Text(
              'No violations - Perfect focus!',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
      );
    }

    return Column(
      children: violations.map((v) {
        final task = tasks.cast<TaskRow?>().firstWhere(
              (t) => t?.id == v.taskId,
              orElse: () => null,
            );

        final timestamp = DateTime.fromMillisecondsSinceEpoch(v.tsMs);
        final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.red)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task?.title ?? 'Unknown task',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      v.reasoningText,
                      style: TextStyle(fontSize: 12, color: context.textColorSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.warning, size: 16, color: Colors.red),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildZeroNotesSection(BuildContext context, List<TaskRow> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Zero notes are required for tasks with 0% progress to complete your day review.',
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...tasks.map((task) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task.title)),
                  TextButton.icon(
                    onPressed: () => _showZeroNoteDialog(task.id, task.title),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Add Note'),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildStatistics(BuildContext context, DayScore score, List<TaskRow> tasks) {
    final completedTasks = tasks.where((t) => t.completed).length;
    final redTasks = tasks.where((t) => t.priority == 'red').toList();
    final amberTasks = tasks.where((t) => t.priority == 'amber').toList();
    final greenTasks = tasks.where((t) => t.priority == 'green').toList();

    final redComplete = redTasks.where((t) => t.completed).length;
    final amberComplete = amberTasks.where((t) => t.completed).length;
    final greenComplete = greenTasks.where((t) => t.completed).length;

    return Column(
      children: [
        _buildStatRow('Red Tasks', '$redComplete/${redTasks.length}', Colors.red),
        _buildStatRow('Amber Tasks', '$amberComplete/${amberTasks.length}', Colors.amber),
        _buildStatRow('Green Tasks', '$greenComplete/${greenTasks.length}', Colors.green),
        const Divider(height: 24),
        _buildStatRow('Checklist Complete', '${score.checklistDone}/${score.totalChecklistItems}', Colors.blue),
        _buildStatRow('Zero Notes Written', '${score.zeroNoteCount}', Colors.purple),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w500, color: color),
          ),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}
