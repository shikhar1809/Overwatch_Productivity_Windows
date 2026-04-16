import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/theme_extensions.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';

class MorningScreen extends ConsumerStatefulWidget {
  const MorningScreen({super.key});

  @override
  ConsumerState<MorningScreen> createState() => _MorningScreenState();
}

class _MorningScreenState extends ConsumerState<MorningScreen> {
  final _checklistController = TextEditingController();
  bool _sessionInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSession();
    });
  }

  void _initSession() {
    if (_sessionInitialized) return;
    try {
      final db = ref.read(appDatabaseProvider);
      final dayId = ref.read(todayDayIdProvider);
      final session = db.getMorningSession(dayId);
      if (session == null) {
        db.createMorningSession(dayId);
        db.insertChecklistItem(dayId: dayId, text: 'Review today\'s tasks');
        db.insertChecklistItem(dayId: dayId, text: 'Plan time blocks');
        db.insertChecklistItem(dayId: dayId, text: 'Set daily intention');
      }
      _sessionInitialized = true;
      if (mounted) setState(() {});
    } catch (e, stack) {
      debugPrint('Error initializing session: $e\n$stack');
      _sessionInitialized = true;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _checklistController.dispose();
    super.dispose();
  }

  void _addChecklistItem() {
    final text = _checklistController.text.trim();
    if (text.isEmpty) return;
    final db = ref.read(appDatabaseProvider);
    final dayId = ref.read(todayDayIdProvider);
    db.insertChecklistItem(dayId: dayId, text: text);
    _checklistController.clear();
    ref.invalidate(checklistItemsProvider);
    setState(() {});
  }

  void _toggleItem(String itemId) {
    final db = ref.read(appDatabaseProvider);
    db.toggleChecklistItem(itemId);
    ref.invalidate(checklistItemsProvider);
    ref.invalidate(areAllChecklistItemsCheckedProvider);
    setState(() {});
  }

  void _deleteItem(String itemId) {
    final db = ref.read(appDatabaseProvider);
    db.deleteChecklistItem(itemId);
    ref.invalidate(checklistItemsProvider);
    ref.invalidate(areAllChecklistItemsCheckedProvider);
    setState(() {});
  }

  void _editItem(ChecklistItemRow item) async {
    final controller = TextEditingController(text: item.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Checklist Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter item text...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final db = ref.read(appDatabaseProvider);
      db.updateChecklistItem(item.id, result.trim());
      ref.invalidate(checklistItemsProvider);
      setState(() {});
    }
  }

  void _showAddTaskDialog() {
    String priority = 'green';
    final titleController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.add_task),
              SizedBox(width: 8),
              Text('Add Task'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Task title', border: OutlineInputBorder()),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Priority: '),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('🔴 Red'),
                    selected: priority == 'red',
                    onSelected: (s) => setDialogState(() => priority = 'red'),
                    selectedColor: Colors.red.shade100,
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: const Text('🟡 Amber'),
                    selected: priority == 'amber',
                    onSelected: (s) => setDialogState(() => priority = 'amber'),
                    selectedColor: Colors.amber.shade100,
                  ),
                  const SizedBox(width: 4),
                  ChoiceChip(
                    label: const Text('🟢 Green'),
                    selected: priority == 'green',
                    onSelected: (s) => setDialogState(() => priority = 'green'),
                    selectedColor: Colors.green.shade100,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Points: ${AppDatabase.basePointsForPriority(priority)}',
                style: TextStyle(color: context.textColorSecondary),
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
                if (titleController.text.trim().isNotEmpty) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ).then((result) {
      if (result == true) {
        final db = ref.read(appDatabaseProvider);
        final dayId = ref.read(todayDayIdProvider);
        db.insertTask(dayId: dayId, title: titleController.text.trim(), priority: priority);
        ref.invalidate(todayTasksProvider);
        ref.invalidate(todayScoreProvider);
        setState(() {});
      }
    });
  }

  void _deleteTask(String taskId) {
    final db = ref.read(appDatabaseProvider);
    db.deleteTask(taskId);
    ref.invalidate(todayTasksProvider);
    ref.invalidate(todayScoreProvider);
    setState(() {});
  }

  void _submitDayPlan() {
    final db = ref.read(appDatabaseProvider);
    final dayId = ref.read(todayDayIdProvider);
    final session = db.getMorningSession(dayId);
    final tasks = db.listTasksForDay(dayId);
    final slots = db.listSlotsForDay(dayId);

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one task before submitting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock, color: Colors.amber),
            SizedBox(width: 8),
            Text('Submit Day Plan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Once submitted, your plan is LOCKED:'),
            const SizedBox(height: 12),
            _buildConfirmItem(Icons.check, 'Tasks cannot be added/removed'),
            _buildConfirmItem(Icons.check, 'Slots cannot be modified'),
            _buildConfirmItem(Icons.check, 'Checklist is frozen'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. Your day begins now!',
                      style: TextStyle(color: Colors.amber.shade800, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () {
              final currentDayId = dayId;
              Navigator.of(ctx).pop();
              try {
                if (session != null) {
                  db.submitTasks(session.id);
                  db.completeMorningSession(session.id, fallPointsAccepted: false);
                  db.commitAllFilledSlots(currentDayId);
                }
                ref.invalidate(morningSessionProvider);
                ref.invalidate(isDayStartedProvider);
                ref.invalidate(todayScoreProvider);
                
                Future.microtask(() {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Day plan submitted! Your work session has begun.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    GoRouter.of(context).go('/planner');
                  }
                });
              } catch (e, st) {
                debugPrint('Submit Error $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.amber.shade700),
            child: const Text('Submit & Start Day'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.green),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final checklistItems = ref.watch(checklistItemsProvider);
    final allChecked = ref.watch(areAllChecklistItemsCheckedProvider);
    final tasks = ref.watch(todayTasksProvider);
    final slots = ref.watch(todaySlotsProvider);
    final db = ref.watch(appDatabaseProvider);
    final dayId = ref.watch(todayDayIdProvider);
    final session = db.getMorningSession(dayId);
    final isSubmitted = session?.tasksSubmitted ?? false;
    final isDayStarted = ref.watch(isDayStartedProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          
          // Step 1: Morning Ritual (max 5 items)
          _buildMorningRitual(context, checklistItems, allChecked, isSubmitted),
          const SizedBox(height: 32),
          
          // Step 2: Task Creation
          _buildTasksSection(context, tasks, isSubmitted),
          const SizedBox(height: 32),
          
          // Step 3: Slots Preview
          _buildSlotsPreview(context, slots),
          const SizedBox(height: 32),
          
          // Step 4: Submit Button
          if (!isSubmitted && !isDayStarted)
            _buildSubmitSection(context, tasks, slots, allChecked),
          
          // Show if day is locked
          if (isSubmitted || isDayStarted)
            _buildLockedBanner(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    final dateStr = '${_weekdayName(now.weekday)}, ${_monthName(now.month)} ${now.day}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.textColorSecondary,
              ),
        ),
        const SizedBox(height: 12),
        _buildProgressSteps(),
      ],
    );
  }

  Widget _buildProgressSteps() {
    return Row(
      children: [
        _StepBadge(number: 1, label: 'Morning Ritual', isActive: true),
        Container(width: 30, height: 2, color: context.dividerColor),
        _StepBadge(number: 2, label: 'Create Tasks', isActive: true),
        Container(width: 30, height: 2, color: context.dividerColor),
        _StepBadge(number: 3, label: 'Assign Slots', isActive: true),
        Container(width: 30, height: 2, color: context.dividerColor),
        _StepBadge(number: 4, label: 'Submit', isActive: true, isLast: true),
      ],
    );
  }

  Widget _buildMorningRitual(
    BuildContext context,
    List<ChecklistItemRow> items,
    bool allChecked,
    bool isSubmitted,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.checklist, color: Colors.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Morning Ritual',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${items.where((i) => i.checked).length}/${items.length} completed',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: allChecked ? Colors.green : context.textColorSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                if (allChecked)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Complete your morning checklist (max 5 items)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.textColor),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _buildChecklistItem(item, isSubmitted)),
            if (items.length < 5 && !isSubmitted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _checklistController,
                      decoration: InputDecoration(
                        hintText: 'Add checklist item...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onSubmitted: (_) => _addChecklistItem(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addChecklistItem,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(ChecklistItemRow item, bool isSubmitted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: item.checked,
            onChanged: isSubmitted ? null : (_) => _toggleItem(item.id),
          ),
          Expanded(
            child: GestureDetector(
              onDoubleTap: isSubmitted ? null : () => _editItem(item),
              child: Text(
                item.text,
                style: TextStyle(
                  decoration: item.checked ? TextDecoration.lineThrough : null,
                  color: item.checked ? context.textColorSecondary : context.textColor,
                ),
              ),
            ),
          ),
          if (!isSubmitted) ...[
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editItem(item),
              color: context.textColorTertiary,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => _deleteItem(item.id),
              color: context.textColorTertiary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTasksSection(BuildContext context, List<TaskRow> tasks, bool isSubmitted) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.task_alt, color: Colors.purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Tasks',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${tasks.length} task${tasks.length == 1 ? '' : 's'} planned',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.textColorSecondary),
                      ),
                    ],
                  ),
                ),
                if (!isSubmitted)
                  FilledButton.icon(
                    onPressed: _showAddTaskDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (tasks.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.add_task, size: 48, color: context.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        'No tasks yet',
                        style: TextStyle(color: context.isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add tasks to plan your day',
                        style: TextStyle(color: context.isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...tasks.map((t) => _buildTaskItem(context, t, isSubmitted)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskRow task, bool isSubmitted) {
    Color priorityColor;
    switch (task.priority) {
      case 'red':
        priorityColor = Colors.red;
        break;
      case 'amber':
        priorityColor = Colors.amber.shade700;
        break;
      default:
        priorityColor = Colors.green;
    }

    final child = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: priorityColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: priorityColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
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
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${task.priority.toUpperCase()} · ${task.basePoints} pts',
                  style: TextStyle(fontSize: 12, color: priorityColor),
                ),
              ],
            ),
          ),
          if (!isSubmitted)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteTask(task.id),
            ),
        ],
      ),
    );

    return Draggable<TaskRow>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: SizedBox(
            width: 300,
            child: child,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: child,
      ),
      child: child,
    );
  }

  Widget _buildSlotsPreview(BuildContext context, List<SlotRow> slots) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.grid_on, color: Colors.teal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time Slots',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Drag tasks into empty hours below.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.textColorSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: SingleChildScrollView(
                child: _DraggableTimeGrid(
                  slots: slots,
                  dayId: ref.read(todayDayIdProvider),
                  db: ref.read(appDatabaseProvider),
                  onSlotUpdated: () {
                    ref.invalidate(todaySlotsProvider);
                    setState(() {});
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitSection(
    BuildContext context,
    List<TaskRow> tasks,
    List<SlotRow> slots,
    bool checklistComplete,
  ) {
    final canSubmit = tasks.isNotEmpty;

    return Card(
      color: canSubmit ? Colors.green.shade50 : Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              canSubmit ? Icons.lock_open : Icons.lock,
              size: 48,
              color: canSubmit ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              canSubmit ? 'Ready to Lock Your Day' : 'Add Tasks to Continue',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: canSubmit ? Colors.green.shade700 : Colors.grey,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              canSubmit
                  ? 'Once submitted, your plan is locked and your work session begins.'
                  : 'Create tasks above to submit your daily plan.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: canSubmit ? context.textColorSecondary : Colors.grey,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canSubmit ? _submitDayPlan : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.rocket_launch),
                label: const Text(
                  'Submit Day Plan & Start Working',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLockedBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, color: Colors.green, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Day Plan Locked',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Your tasks and slots are now fixed. Focus on execution!',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => GoRouter.of(context).go('/planner'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            child: const Text('Go to Slots'),
          ),
        ],
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
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

class _DraggableTimeGrid extends ConsumerWidget {
  const _DraggableTimeGrid({
    required this.slots,
    required this.dayId,
    required this.db,
    required this.onSlotUpdated,
  });

  final List<SlotRow> slots;
  final String dayId;
  final AppDatabase db;
  final VoidCallback onSlotUpdated;

  static const double hourHeight = 50.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(todayTasksProvider);
    final session = db.getMorningSession(dayId);
    final isSubmitted = session?.tasksSubmitted ?? false;
    final isDayStarted = ref.watch(isDayStartedProvider);
    final isLocked = isSubmitted || isDayStarted;

    return SizedBox(
      height: 24 * hourHeight,
      child: Stack(
        children: [
          Column(
            children: [
              for (int h = 0; h < 24; h++)
                DragTarget<TaskRow>(
                  onWillAcceptWithDetails: (details) {
                    final existingSlot = slots.cast<SlotRow?>().firstWhere(
                      (s) => s != null && s.startMinute == h * 60,
                      orElse: () => null,
                    );
                    if (existingSlot != null && existingSlot.committed) {
                      return false;
                    }
                    if (existingSlot != null && existingSlot.taskId != null && isLocked) {
                      return false;
                    }
                    return true;
                  },
                  onAcceptWithDetails: (details) {
                    final task = details.data;
                    final existingSlot = slots.cast<SlotRow?>().firstWhere(
                      (s) => s != null && s.startMinute == h * 60,
                      orElse: () => null,
                    );
                    if (existingSlot != null) {
                      db.updateSlotTask(existingSlot.id, task.id);
                    } else {
                      final slotId = db.insertSlot(
                        dayId: dayId,
                        startMinute: h * 60,
                        endMinute: (h + 1) * 60,
                        taskId: task.id,
                      );
                      if (isLocked) {
                        db.commitSlot(slotId);
                      }
                    }
                    onSlotUpdated();
                  },
                  builder: (context, candidateData, rejectedData) {
                    return SizedBox(
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
                                color: candidateData.isNotEmpty
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                                    : null,
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
                    );
                  },
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
              child: IgnorePointer(
                ignoring: true, // Let drops pass through to DragTarget
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
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({
    required this.number,
    required this.label,
    required this.isActive,
    this.isLast = false,
  });

  final int number;
  final String label;
  final bool isActive;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? Colors.blue : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? context.textColor : Colors.grey,
          ),
        ),
      ],
    );
  }
}
