import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('appDatabaseProvider must be overridden');
});

String _calendarDateToday() {
  final n = DateTime.now();
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '${n.year}-$m-$d';
}

final todayDayIdProvider = Provider<String>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.getOrCreateDayId(_calendarDateToday());
});

final todayTasksProvider = Provider<List<TaskRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.listTasksForDay(dayId);
});

final redTasksProvider = Provider<List<TaskRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.listRedTasks(dayId);
});

final areRedTasksCompleteProvider = Provider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.areRedTasksComplete(dayId);
});

final todaySlotsProvider = Provider<List<SlotRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.listSlotsForDay(dayId);
});

final committedSlotsProvider = Provider<List<SlotRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.listCommittedSlotsForDay(dayId);
});

final checklistItemsProvider = Provider<List<ChecklistItemRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.listChecklistItems(dayId);
});

final areAllChecklistItemsCheckedProvider = Provider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.areAllChecklistItemsChecked(dayId);
});

final morningSessionProvider = Provider<MorningSessionRow?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.getMorningSession(dayId);
});

final isDayStartedProvider = Provider<bool>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.isDayStarted(dayId);
});

final areTasksSubmittedProvider = Provider<bool>((ref) {
  final session = ref.watch(morningSessionProvider);
  return session?.tasksSubmitted ?? false;
});

final todayScoreProvider = Provider<DayScore>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.calculateDayScore(dayId);
});

final todayViolationsProvider = Provider<List<ViolationRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.listViolationsForDay(dayId);
});

final taskByIdProvider = Provider.family<TaskRow?, String>((ref, taskId) {
  final tasks = ref.watch(todayTasksProvider);
  try {
    return tasks.firstWhere((t) => t.id == taskId);
  } catch (_) {
    return null;
  }
});

final slotByIdProvider = Provider.family<SlotRow?, String>((ref, slotId) {
  final slots = ref.watch(todaySlotsProvider);
  try {
    return slots.firstWhere((s) => s.id == slotId);
  } catch (_) {
    return null;
  }
});

final blockingRulesProvider = Provider<List<BlockingRuleRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.listBlockingRules();
});

final blockedAppsProvider = Provider<List<BlockingRuleRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.listBlockedApps();
});

final hardBlockedAppsProvider = Provider<List<BlockingRuleRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.listHardBlockedApps();
});

final activeUnlockSessionsProvider = Provider<List<UnlockSessionRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.listActiveUnlockSessions();
});

final todayUnlockSessionsProvider = Provider<List<UnlockSessionRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final dayId = ref.watch(todayDayIdProvider);
  return db.listUnlockSessionsForDay(dayId);
});

final unlockStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.getUnlockStats(7);
});

final unhookVerifiedProvider = StateProvider<bool>((ref) => false);

final activeUnlocksRefreshProvider = StateProvider<int>((ref) => 0);

final themeProvider = StateProvider<bool>((ref) => false);
