import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum TaskPriority { red, amber, green }

enum ExecutionLevel { none, partial, full }

class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static AppDatabase open(String path) {
    Directory(p.dirname(path)).createSync(recursive: true);
    final db = sqlite3.open(path);
    final app = AppDatabase._(db);
    app._migrate();
    return app;
  }

  static AppDatabase openMemory() {
    final db = sqlite3.open(':memory:');
    final app = AppDatabase._(db);
    app._migrate();
    return app;
  }

  void dispose() => _db.dispose();

  void _migrate() {
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute('''
CREATE TABLE IF NOT EXISTS days (
  id TEXT NOT NULL PRIMARY KEY,
  calendar_date TEXT NOT NULL UNIQUE,
  created_at_ms INTEGER NOT NULL
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS tasks (
  id TEXT NOT NULL PRIMARY KEY,
  day_id TEXT NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  priority TEXT NOT NULL,
  base_points INTEGER NOT NULL DEFAULT 0,
  completed INTEGER NOT NULL DEFAULT 0,
  violation_count INTEGER NOT NULL DEFAULT 0,
  forfeited INTEGER NOT NULL DEFAULT 0,
  compromised INTEGER NOT NULL DEFAULT 0,
  zero_note TEXT,
  created_at_ms INTEGER NOT NULL
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS slots (
  id TEXT NOT NULL PRIMARY KEY,
  day_id TEXT NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  task_id TEXT REFERENCES tasks(id) ON DELETE SET NULL,
  label TEXT NOT NULL DEFAULT '',
  start_minute INTEGER NOT NULL DEFAULT 0,
  end_minute INTEGER NOT NULL DEFAULT 0,
  committed INTEGER NOT NULL DEFAULT 0,
  committed_at_ms INTEGER,
  execution_percent INTEGER NOT NULL DEFAULT 0,
  cp20 INTEGER NOT NULL DEFAULT 0,
  cp50 INTEGER NOT NULL DEFAULT 0,
  cp100 INTEGER NOT NULL DEFAULT 0,
  forfeited INTEGER NOT NULL DEFAULT 0
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS violations (
  id TEXT NOT NULL PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  slot_id TEXT REFERENCES slots(id) ON DELETE SET NULL,
  ts_ms INTEGER NOT NULL,
  verdict INTEGER NOT NULL,
  reasoning_text TEXT NOT NULL,
  screenshot_hash TEXT
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS breaks (
  id TEXT NOT NULL PRIMARY KEY,
  task_id TEXT REFERENCES tasks(id) ON DELETE SET NULL,
  slot_id TEXT REFERENCES slots(id) ON DELETE SET NULL,
  started_at_ms INTEGER NOT NULL,
  duration_min INTEGER NOT NULL,
  ended_at_ms INTEGER
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS checklist_items (
  id TEXT NOT NULL PRIMARY KEY,
  day_id TEXT NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  checked INTEGER NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS morning_sessions (
  id TEXT NOT NULL PRIMARY KEY,
  day_id TEXT NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  started_at_ms INTEGER,
  completed_at_ms INTEGER,
  fall_points_accepted INTEGER NOT NULL DEFAULT 0,
  day_started INTEGER NOT NULL DEFAULT 0,
  tasks_submitted INTEGER NOT NULL DEFAULT 0,
  tasks_submitted_at_ms INTEGER
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS hall_of_shame (
  id TEXT NOT NULL PRIMARY KEY,
  day_id TEXT NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  task_id TEXT REFERENCES tasks(id) ON DELETE SET NULL,
  screenshot_path TEXT NOT NULL,
  reason TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS youtube_unlocks (
  id TEXT NOT NULL PRIMARY KEY,
  day_id TEXT NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  unhook_verified INTEGER NOT NULL DEFAULT 0,
  intent TEXT NOT NULL,
  duration_min INTEGER NOT NULL,
  video_subject TEXT NOT NULL DEFAULT '',
  created_at_ms INTEGER NOT NULL
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS unlock_logs (
  id TEXT NOT NULL PRIMARY KEY,
  day_id TEXT NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  target TEXT NOT NULL,
  intent TEXT NOT NULL,
  duration_min INTEGER NOT NULL,
  created_at_ms INTEGER NOT NULL
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS settings (
  key TEXT NOT NULL PRIMARY KEY,
  value TEXT NOT NULL
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS app_blocking_rules (
  id TEXT NOT NULL PRIMARY KEY,
  app_id TEXT NOT NULL,
  app_name TEXT NOT NULL,
  category TEXT NOT NULL,
  domains TEXT NOT NULL,
  is_hard_blocked INTEGER NOT NULL DEFAULT 0,
  is_blocked INTEGER NOT NULL DEFAULT 1,
  requires_unhook INTEGER NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL
);
''');
    _db.execute('''
CREATE TABLE IF NOT EXISTS unlock_sessions (
  id TEXT NOT NULL PRIMARY KEY,
  day_id TEXT NOT NULL REFERENCES days(id) ON DELETE CASCADE,
  app_id TEXT NOT NULL,
  app_name TEXT NOT NULL,
  intent TEXT NOT NULL,
  duration_min INTEGER NOT NULL,
  started_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER,
  completed INTEGER NOT NULL DEFAULT 0,
  revoked INTEGER NOT NULL DEFAULT 0
);
''');
  }

  static int basePointsForPriority(String priority) {
    switch (priority) {
      case 'red':
        return 30;
      case 'amber':
        return 18;
      case 'green':
        return 8;
      default:
        return 8;
    }
  }

  static int fallPointsForPriority(String priority) {
    return (basePointsForPriority(priority) * 0.1).round();
  }

  // --- Days ---

  String insertDay({required String calendarDate}) {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
INSERT INTO days (id, calendar_date, created_at_ms) VALUES (?, ?, ?);
''').execute([id, calendarDate, now]);
    return id;
  }

  String getOrCreateDayId(String calendarDate) {
    final rows = _db.select(
      'SELECT id FROM days WHERE calendar_date = ?;',
      [calendarDate],
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;
    return insertDay(calendarDate: calendarDate);
  }

  List<DayRow> listDays() {
    final rows = _db.select('SELECT id, calendar_date, created_at_ms FROM days ORDER BY calendar_date DESC;');
    return [for (final r in rows) DayRow.fromRow(r)];
  }

  // --- Tasks ---

  String insertTask({
    required String dayId,
    required String title,
    required String priority,
  }) {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final basePoints = basePointsForPriority(priority);
    _db.prepare('''
INSERT INTO tasks (id, day_id, title, priority, base_points, completed, violation_count, forfeited, compromised, zero_note, created_at_ms)
VALUES (?, ?, ?, ?, ?, 0, 0, 0, 0, NULL, ?);
''').execute([id, dayId, title, priority, basePoints, now]);
    return id;
  }

  List<TaskRow> listTasksForDay(String dayId) {
    final rows = _db.select(
      'SELECT * FROM tasks WHERE day_id = ? ORDER BY created_at_ms;',
      [dayId],
    );
    return [for (final r in rows) TaskRow.fromRow(r)];
  }

  List<TaskRow> listRedTasks(String dayId) {
    final rows = _db.select(
      'SELECT * FROM tasks WHERE day_id = ? AND priority = ? ORDER BY created_at_ms;',
      [dayId, 'red'],
    );
    return [for (final r in rows) TaskRow.fromRow(r)];
  }

  bool areRedTasksComplete(String dayId) {
    final rows = _db.select(
      'SELECT COUNT(*) as count FROM tasks WHERE day_id = ? AND priority = ? AND completed = 0;',
      [dayId, 'red'],
    );
    return (rows.first['count'] as int) == 0;
  }

  void setTaskCompleted(String taskId, {required bool completed}) {
    _db.prepare('UPDATE tasks SET completed = ? WHERE id = ?;').execute([completed ? 1 : 0, taskId]);
  }

  void setTaskZeroNote(String taskId, String note) {
    _db.prepare('UPDATE tasks SET zero_note = ? WHERE id = ?;').execute([note, taskId]);
  }

  void incrementViolationCount(String taskId) {
    _db.prepare('UPDATE tasks SET violation_count = violation_count + 1 WHERE id = ?;').execute([taskId]);
  }

  void setTaskCompromised(String taskId, {required bool compromised}) {
    _db.prepare('UPDATE tasks SET compromised = ? WHERE id = ?;').execute([compromised ? 1 : 0, taskId]);
  }

  void setTaskForfeited(String taskId, {required bool forfeited}) {
    _db.prepare('UPDATE tasks SET forfeited = ? WHERE id = ?;').execute([forfeited ? 1 : 0, taskId]);
  }

  void updateTask(String taskId, String title, String priority, int basePoints) {
    _db.prepare('UPDATE tasks SET title = ?, priority = ?, base_points = ? WHERE id = ?;').execute([title, priority, basePoints, taskId]);
  }

  void deleteTask(String taskId) {
    _db.prepare('DELETE FROM tasks WHERE id = ?;').execute([taskId]);
  }

  void submitTasks(String sessionId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
UPDATE morning_sessions SET tasks_submitted = 1, tasks_submitted_at_ms = ? WHERE id = ?;
''').execute([now, sessionId]);
  }

  // --- Slots ---

  String insertSlot({
    required String dayId,
    required int startMinute,
    required int endMinute,
    String? taskId,
    String label = '',
  }) {
    final id = _uuid.v4();
    _db.prepare('''
INSERT INTO slots (id, day_id, task_id, label, start_minute, end_minute, committed, execution_percent, cp20, cp50, cp100, forfeited)
VALUES (?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 0);
''').execute([id, dayId, taskId, label, startMinute, endMinute]);
    return id;
  }

  List<SlotRow> listSlotsForDay(String dayId) {
    final rows = _db.select(
      'SELECT * FROM slots WHERE day_id = ? ORDER BY start_minute;',
      [dayId],
    );
    return [for (final r in rows) SlotRow.fromRow(r)];
  }

  List<SlotRow> listCommittedSlotsForDay(String dayId) {
    final rows = _db.select(
      'SELECT * FROM slots WHERE day_id = ? AND committed = 1 ORDER BY start_minute;',
      [dayId],
    );
    return [for (final r in rows) SlotRow.fromRow(r)];
  }

  void updateSlotTask(String slotId, String? taskId) {
    _db.prepare('UPDATE slots SET task_id = ? WHERE id = ? AND committed = 0;').execute([taskId, slotId]);
  }

  void updateSlotLabel(String slotId, String label) {
    _db.prepare('UPDATE slots SET label = ? WHERE id = ? AND committed = 0;').execute([label, slotId]);
  }

  void commitSlot(String slotId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('UPDATE slots SET committed = 1, committed_at_ms = ? WHERE id = ?;').execute([now, slotId]);
  }

  void commitAllFilledSlots(String dayId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('UPDATE slots SET committed = 1, committed_at_ms = ? WHERE day_id = ? AND task_id IS NOT NULL AND committed = 0;').execute([now, dayId]);
  }

  void setSlotExecutionPercent(String slotId, int percent) {
    _db.prepare('UPDATE slots SET execution_percent = ? WHERE id = ?;').execute([percent, slotId]);
  }

  void markSlotCheckpoint(String slotId, int checkpoint) {
    switch (checkpoint) {
      case 20:
        _db.prepare('UPDATE slots SET cp20 = 1 WHERE id = ?;').execute([slotId]);
        break;
      case 50:
        _db.prepare('UPDATE slots SET cp50 = 1 WHERE id = ?;').execute([slotId]);
        break;
      case 100:
        _db.prepare('UPDATE slots SET cp100 = 1 WHERE id = ?;').execute([slotId]);
        break;
    }
  }

  void forfeitSlot(String slotId) {
    _db.prepare('UPDATE slots SET forfeited = 1, execution_percent = 0 WHERE id = ?;').execute([slotId]);
  }

  void deleteSlot(String slotId) {
    _db.prepare('DELETE FROM slots WHERE id = ? AND committed = 0;').execute([slotId]);
  }

  int calculateSlotPoints(SlotRow slot) {
    if (slot.forfeited) return 0;
    if (slot.executionPercent == 0 && slot.cp20 == 0) return 0;

    int base;
    if (slot.taskId != null) {
      final taskRows = _db.select('SELECT base_points FROM tasks WHERE id = ?;', [slot.taskId]);
      base = taskRows.isNotEmpty ? taskRows.first['base_points'] as int : 8;
    } else {
      base = 8;
    }

    int checkpointsHit = 0;
    if (slot.cp20 == 1) checkpointsHit++;
    if (slot.cp50 == 1) checkpointsHit++;
    if (slot.cp100 == 1) checkpointsHit++;

    int earned;
    if (checkpointsHit == 3) {
      earned = base;
    } else if (checkpointsHit == 2) {
      earned = (base * 0.75).round();
    } else if (checkpointsHit == 1) {
      earned = (base * 0.4).round();
    } else {
      earned = 0;
    }

    if (slot.violationCount >= 2) {
      earned = (earned * 0.5).round();
    }

    return earned;
  }

  // --- Checklist Items ---

  String insertChecklistItem({
    required String dayId,
    required String text,
  }) {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
INSERT INTO checklist_items (id, day_id, text, checked, created_at_ms)
VALUES (?, ?, ?, 0, ?);
''').execute([id, dayId, text, now]);
    return id;
  }

  List<ChecklistItemRow> listChecklistItems(String dayId) {
    final rows = _db.select(
      'SELECT * FROM checklist_items WHERE day_id = ? ORDER BY created_at_ms;',
      [dayId],
    );
    return [for (final r in rows) ChecklistItemRow.fromRow(r)];
  }

  void toggleChecklistItem(String itemId) {
    _db.prepare('''
UPDATE checklist_items SET checked = CASE WHEN checked = 1 THEN 0 ELSE 1 END WHERE id = ?;
''').execute([itemId]);
  }

  void deleteChecklistItem(String itemId) {
    _db.prepare('DELETE FROM checklist_items WHERE id = ?;').execute([itemId]);
  }

  void updateChecklistItem(String itemId, String text) {
    _db.prepare('UPDATE checklist_items SET text = ? WHERE id = ?;').execute([text, itemId]);
  }

  bool areAllChecklistItemsChecked(String dayId) {
    final rows = _db.select(
      'SELECT COUNT(*) as count FROM checklist_items WHERE day_id = ? AND checked = 0;',
      [dayId],
    );
    return (rows.first['count'] as int) == 0;
  }

  // --- Morning Sessions ---

  String createMorningSession(String dayId) {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
INSERT INTO morning_sessions (id, day_id, started_at_ms, completed_at_ms, fall_points_accepted, day_started)
VALUES (?, ?, ?, NULL, 0, 0);
''').execute([id, dayId, now]);
    return id;
  }

  MorningSessionRow? getMorningSession(String dayId) {
    final rows = _db.select(
      'SELECT * FROM morning_sessions WHERE day_id = ? ORDER BY started_at_ms DESC LIMIT 1;',
      [dayId],
    );
    if (rows.isEmpty) return null;
    return MorningSessionRow.fromRow(rows.first);
  }

  void completeMorningSession(String sessionId, {required bool fallPointsAccepted}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
UPDATE morning_sessions SET completed_at_ms = ?, day_started = 1, fall_points_accepted = ? WHERE id = ?;
''').execute([now, fallPointsAccepted ? 1 : 0, sessionId]);
  }

  bool isDayStarted(String dayId) {
    final session = getMorningSession(dayId);
    return session?.dayStarted ?? false;
  }

  // --- Violations ---

  String insertViolation({
    required String taskId,
    String? slotId,
    required bool verdict,
    required String reasoningText,
    String? screenshotHash,
  }) {
    final id = _uuid.v4();
    final ts = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
INSERT INTO violations (id, task_id, slot_id, ts_ms, verdict, reasoning_text, screenshot_hash)
VALUES (?, ?, ?, ?, ?, ?, ?);
''').execute([id, taskId, slotId, ts, verdict ? 1 : 0, reasoningText, screenshotHash]);
    incrementViolationCount(taskId);
    return id;
  }

  List<ViolationRow> listViolationsForTask(String taskId) {
    final rows = _db.select('SELECT * FROM violations WHERE task_id = ? ORDER BY ts_ms;', [taskId]);
    return [for (final r in rows) ViolationRow.fromRow(r)];
  }

  List<ViolationRow> listViolationsForDay(String dayId) {
    final rows = _db.select('''
SELECT v.* FROM violations v
JOIN tasks t ON v.task_id = t.id
WHERE t.day_id = ?
ORDER BY v.ts_ms;
''', [dayId]);
    return [for (final r in rows) ViolationRow.fromRow(r)];
  }

  // --- Hall of Shame ---

  void addHallOfShameEntry({
    required String dayId,
    String? taskId,
    required String screenshotPath,
    required String reason,
  }) {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
INSERT INTO hall_of_shame (id, day_id, task_id, screenshot_path, reason, created_at_ms)
VALUES (?, ?, ?, ?, ?, ?);
''').execute([id, dayId, taskId, screenshotPath, reason, now]);
  }

  List<HallOfShameRow> listHallOfShameEntries() {
    final rows = _db.select('SELECT * FROM hall_of_shame ORDER BY created_at_ms DESC;');
    return [for (final r in rows) _hallOfShameFromRow(r)];
  }

  List<HallOfShameRow> listHallOfShameForDay(String dayId) {
    final rows = _db.select(
      'SELECT * FROM hall_of_shame WHERE day_id = ? ORDER BY created_at_ms DESC;',
      [dayId],
    );
    return [for (final r in rows) _hallOfShameFromRow(r)];
  }

  HallOfShameRow _hallOfShameFromRow(Row r) {
    return HallOfShameRow(
      id: r['id'] as String,
      dayId: r['day_id'] as String,
      taskId: r['task_id'] as String?,
      screenshotPath: r['screenshot_path'] as String,
      reason: r['reason'] as String,
      createdAtMs: r['created_at_ms'] as int,
    );
  }

  // --- Breaks ---

  String startBreak({String? taskId, String? slotId}) {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
INSERT INTO breaks (id, task_id, slot_id, started_at_ms, duration_min, ended_at_ms)
VALUES (?, ?, ?, ?, 0, NULL);
''').execute([id, taskId, slotId]);
    return id;
  }

  void endBreak(String breakId, int durationMinutes) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
UPDATE breaks SET duration_min = ?, ended_at_ms = ? WHERE id = ?;
''').execute([durationMinutes, now, breakId]);
  }

  // --- Day Score Calculation ---

  DayScore calculateDayScore(String dayId) {
    final tasks = listTasksForDay(dayId);
    final slots = listSlotsForDay(dayId);
    final violations = listViolationsForDay(dayId);
    final checklistItems = listChecklistItems(dayId);

    int totalBasePoints = 0;
    int totalEarnedPoints = 0;
    int tasksCompleted = 0;
    int slotsCompleted = 0;
    int zeroNoteCount = 0;
    int fallPoints = 0;

    for (final task in tasks) {
      totalBasePoints += task.basePoints;
      if (task.completed) tasksCompleted++;
      if (task.zeroNote != null) zeroNoteCount++;
    }

    for (final slot in slots.where((s) => s.committed)) {
      if (slot.cp100 == 1) slotsCompleted++;
      totalEarnedPoints += calculateSlotPoints(slot);
    }

    for (final task in tasks.where((t) => t.priority == 'red' && !t.completed)) {
      fallPoints += fallPointsForPriority('red');
    }

    int checklistDone = checklistItems.where((c) => c.checked).length;

    String grade;
    if (totalBasePoints == 0) {
      grade = 'N/A';
    } else {
      double pct = totalEarnedPoints / totalBasePoints;
      if (pct >= 0.95 && violations.isEmpty) {
        grade = 'S';
      } else if (pct >= 0.85) {
        grade = 'A';
      } else if (pct >= 0.7) {
        grade = 'B';
      } else if (pct >= 0.5) {
        grade = 'C';
      } else {
        grade = 'F';
      }
    }

    return DayScore(
      totalBasePoints: totalBasePoints,
      totalEarnedPoints: totalEarnedPoints,
      tasksCompleted: tasksCompleted,
      totalTasks: tasks.length,
      slotsCompleted: slotsCompleted,
      totalCommittedSlots: slots.where((s) => s.committed).length,
      zeroNoteCount: zeroNoteCount,
      fallPoints: fallPoints,
      violationCount: violations.length,
      checklistDone: checklistDone,
      totalChecklistItems: checklistItems.length,
      grade: grade,
    );
  }

  // --- Settings ---

  String? getSetting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?;', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  void setSetting(String key, String value) {
    _db.prepare('''
INSERT INTO settings (key, value) VALUES (?, ?)
ON CONFLICT(key) DO UPDATE SET value = excluded.value;
''').execute([key, value]);
  }

  // --- App Blocking Rules ---

  String addBlockingRule({
    required String appId,
    required String appName,
    required String category,
    required List<String> domains,
    bool isHardBlocked = false,
    bool requiresUnhook = false,
  }) {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.prepare('''
INSERT INTO app_blocking_rules (id, app_id, app_name, category, domains, is_hard_blocked, is_blocked, requires_unhook, created_at_ms)
VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?);
''').execute([id, appId, appName, category, domains.join(','), isHardBlocked ? 1 : 0, requiresUnhook ? 1 : 0, now]);
    return id;
  }

  List<BlockingRuleRow> listBlockingRules() {
    final rows = _db.select('SELECT * FROM app_blocking_rules ORDER BY app_name;');
    return [for (final r in rows) BlockingRuleRow.fromRow(r)];
  }

  List<BlockingRuleRow> listBlockedApps() {
    final rows = _db.select('SELECT * FROM app_blocking_rules WHERE is_blocked = 1 ORDER BY app_name;');
    return [for (final r in rows) BlockingRuleRow.fromRow(r)];
  }

  List<BlockingRuleRow> listHardBlockedApps() {
    final rows = _db.select('SELECT * FROM app_blocking_rules WHERE is_hard_blocked = 1;');
    return [for (final r in rows) BlockingRuleRow.fromRow(r)];
  }

  void setAppBlocked(String appId, {required bool blocked}) {
    _db.prepare('UPDATE app_blocking_rules SET is_blocked = ? WHERE app_id = ?;').execute([blocked ? 1 : 0, appId]);
  }

  BlockingRuleRow? getBlockingRule(String appId) {
    final rows = _db.select('SELECT * FROM app_blocking_rules WHERE app_id = ?;', [appId]);
    if (rows.isEmpty) return null;
    return BlockingRuleRow.fromRow(rows.first);
  }

  // --- Unlock Sessions ---

  String createUnlockSession({
    required String dayId,
    required String appId,
    required String appName,
    required String intent,
    required int durationMinutes,
  }) {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiresAt = now + (durationMinutes * 60 * 1000);
    _db.prepare('''
INSERT INTO unlock_sessions (id, day_id, app_id, app_name, intent, duration_min, started_at_ms, expires_at_ms, completed, revoked)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0);
''').execute([id, dayId, appId, appName, intent, durationMinutes, now, expiresAt]);
    return id;
  }

  List<UnlockSessionRow> listActiveUnlockSessions() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = _db.select(
      'SELECT * FROM unlock_sessions WHERE completed = 0 AND revoked = 0 AND expires_at_ms > ? ORDER BY started_at_ms DESC;',
      [now],
    );
    return [for (final r in rows) UnlockSessionRow.fromRow(r)];
  }

  List<UnlockSessionRow> listUnlockSessionsForDay(String dayId) {
    final rows = _db.select(
      'SELECT * FROM unlock_sessions WHERE day_id = ? ORDER BY started_at_ms DESC;',
      [dayId],
    );
    return [for (final r in rows) UnlockSessionRow.fromRow(r)];
  }

  List<UnlockSessionRow> listRecentUnlockSessions(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final rows = _db.select(
      'SELECT * FROM unlock_sessions WHERE started_at_ms > ? ORDER BY started_at_ms DESC;',
      [cutoff],
    );
    return [for (final r in rows) UnlockSessionRow.fromRow(r)];
  }

  void completeUnlockSession(String sessionId) {
    _db.prepare('UPDATE unlock_sessions SET completed = 1 WHERE id = ?;').execute([sessionId]);
  }

  void revokeUnlockSession(String sessionId) {
    _db.prepare('UPDATE unlock_sessions SET revoked = 1 WHERE id = ?;').execute([sessionId]);
  }

  UnlockSessionRow? getActiveSessionForApp(String appId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = _db.select(
      'SELECT * FROM unlock_sessions WHERE app_id = ? AND completed = 0 AND revoked = 0 AND expires_at_ms > ? LIMIT 1;',
      [appId, now],
    );
    if (rows.isEmpty) return null;
    return UnlockSessionRow.fromRow(rows.first);
  }

  UnlockSessionRow? getActiveSessionForAppLive(String appId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rows = _db.select(
      'SELECT * FROM unlock_sessions WHERE app_id = ? AND completed = 0 AND revoked = 0 AND expires_at_ms > ? ORDER BY expires_at_ms ASC LIMIT 1;',
      [appId, now],
    );
    if (rows.isEmpty) return null;
    return UnlockSessionRow.fromRow(rows.first);
  }

  // --- Unlock Analytics ---

  Map<String, dynamic> getUnlockStats(int days) {
    final sessions = listRecentUnlockSessions(days);
    final completedSessions = sessions.where((s) => s.completed && !s.revoked).toList();

    int totalUnlocks = sessions.length;
    int completedUnlocks = completedSessions.length;
    int totalMinutes = 0;
    final appCounts = <String, int>{};
    final appMinutes = <String, int>{};

    for (final session in sessions) {
      totalMinutes += session.durationMin;
      appCounts[session.appName] = (appCounts[session.appName] ?? 0) + 1;
      appMinutes[session.appName] = (appMinutes[session.appName] ?? 0) + session.durationMin;
    }

    String mostUnlocked = '';
    int maxCount = 0;
    for (final entry in appCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostUnlocked = entry.key;
      }
    }

    return {
      'totalUnlocks': totalUnlocks,
      'completedUnlocks': completedUnlocks,
      'totalMinutes': totalMinutes,
      'mostUnlocked': mostUnlocked,
      'appCounts': appCounts,
      'appMinutes': appMinutes,
    };
  }
}

class DayRow {
  DayRow({required this.id, required this.calendarDate, required this.createdAtMs});

  final String id;
  final String calendarDate;
  final int createdAtMs;

  factory DayRow.fromRow(Row r) => DayRow(
        id: r['id'] as String,
        calendarDate: r['calendar_date'] as String,
        createdAtMs: r['created_at_ms'] as int,
      );
}

class TaskRow {
  TaskRow({
    required this.id,
    required this.dayId,
    required this.title,
    required this.priority,
    required this.basePoints,
    required this.completed,
    required this.violationCount,
    required this.forfeited,
    required this.compromised,
    required this.zeroNote,
    required this.createdAtMs,
  });

  final String id;
  final String dayId;
  final String title;
  final String priority;
  final int basePoints;
  final bool completed;
  final int violationCount;
  final bool forfeited;
  final bool compromised;
  final String? zeroNote;
  final int createdAtMs;

  factory TaskRow.fromRow(Row r) => TaskRow(
        id: r['id'] as String,
        dayId: r['day_id'] as String,
        title: r['title'] as String,
        priority: r['priority'] as String,
        basePoints: r['base_points'] as int,
        completed: (r['completed'] as int) != 0,
        violationCount: r['violation_count'] as int,
        forfeited: (r['forfeited'] as int) != 0,
        compromised: (r['compromised'] as int) != 0,
        zeroNote: r['zero_note'] as String?,
        createdAtMs: r['created_at_ms'] as int,
      );
}

class SlotRow {
  SlotRow({
    required this.id,
    required this.dayId,
    required this.taskId,
    required this.label,
    required this.startMinute,
    required this.endMinute,
    required this.committed,
    required this.committedAtMs,
    required this.executionPercent,
    required this.cp20,
    required this.cp50,
    required this.cp100,
    required this.forfeited,
    required this.violationCount,
  });

  final String id;
  final String dayId;
  final String? taskId;
  final String label;
  final int startMinute;
  final int endMinute;
  final bool committed;
  final int? committedAtMs;
  final int executionPercent;
  final bool cp20;
  final bool cp50;
  final bool cp100;
  final bool forfeited;
  final int violationCount;

  String get timeRange {
    final startHour = startMinute ~/ 60;
    final startMin = startMinute % 60;
    final endHour = endMinute ~/ 60;
    final endMin = endMinute % 60;
    return '${startHour.toString().padLeft(2, '0')}:${startMin.toString().padLeft(2, '0')} - '
        '${endHour.toString().padLeft(2, '0')}:${endMin.toString().padLeft(2, '0')}';
  }

  int get durationMinutes => endMinute - startMinute;

  factory SlotRow.fromRow(Row r) => SlotRow(
        id: r['id'] as String,
        dayId: r['day_id'] as String,
        taskId: r['task_id'] as String?,
        label: r['label'] as String,
        startMinute: r['start_minute'] as int,
        endMinute: r['end_minute'] as int,
        committed: (r['committed'] as int) != 0,
        committedAtMs: r['committed_at_ms'] as int?,
        executionPercent: r['execution_percent'] as int,
        cp20: (r['cp20'] as int) != 0,
        cp50: (r['cp50'] as int) != 0,
        cp100: (r['cp100'] as int) != 0,
        forfeited: (r['forfeited'] as int) != 0,
        violationCount: 0,
      );
}

class ChecklistItemRow {
  ChecklistItemRow({
    required this.id,
    required this.dayId,
    required this.text,
    required this.checked,
    required this.createdAtMs,
  });

  final String id;
  final String dayId;
  final String text;
  final bool checked;
  final int createdAtMs;

  factory ChecklistItemRow.fromRow(Row r) => ChecklistItemRow(
        id: r['id'] as String,
        dayId: r['day_id'] as String,
        text: r['text'] as String,
        checked: (r['checked'] as int) != 0,
        createdAtMs: r['created_at_ms'] as int,
      );
}

class MorningSessionRow {
  MorningSessionRow({
    required this.id,
    required this.dayId,
    required this.startedAtMs,
    required this.completedAtMs,
    required this.fallPointsAccepted,
    required this.dayStarted,
    required this.tasksSubmitted,
    required this.tasksSubmittedAtMs,
  });

  final String id;
  final String dayId;
  final int startedAtMs;
  final int? completedAtMs;
  final bool fallPointsAccepted;
  final bool dayStarted;
  final bool tasksSubmitted;
  final int? tasksSubmittedAtMs;

  factory MorningSessionRow.fromRow(Row r) => MorningSessionRow(
        id: r['id'] as String,
        dayId: r['day_id'] as String,
        startedAtMs: r['started_at_ms'] as int,
        completedAtMs: r['completed_at_ms'] as int?,
        fallPointsAccepted: (r['fall_points_accepted'] as int) != 0,
        dayStarted: (r['day_started'] as int) != 0,
        tasksSubmitted: (r['tasks_submitted'] as int?) == 1,
        tasksSubmittedAtMs: r['tasks_submitted_at_ms'] as int?,
      );
}

class ViolationRow {
  ViolationRow({
    required this.id,
    required this.taskId,
    required this.slotId,
    required this.tsMs,
    required this.verdict,
    required this.reasoningText,
    required this.screenshotHash,
  });

  final String id;
  final String taskId;
  final String? slotId;
  final int tsMs;
  final bool verdict;
  final String reasoningText;
  final String? screenshotHash;

  factory ViolationRow.fromRow(Row r) => ViolationRow(
        id: r['id'] as String,
        taskId: r['task_id'] as String,
        slotId: r['slot_id'] as String?,
        tsMs: r['ts_ms'] as int,
        verdict: (r['verdict'] as int) != 0,
        reasoningText: r['reasoning_text'] as String,
        screenshotHash: r['screenshot_hash'] as String?,
      );
}

class DayScore {
  DayScore({
    required this.totalBasePoints,
    required this.totalEarnedPoints,
    required this.tasksCompleted,
    required this.totalTasks,
    required this.slotsCompleted,
    required this.totalCommittedSlots,
    required this.zeroNoteCount,
    required this.fallPoints,
    required this.violationCount,
    required this.checklistDone,
    required this.totalChecklistItems,
    required this.grade,
  });

  final int totalBasePoints;
  final int totalEarnedPoints;
  final int tasksCompleted;
  final int totalTasks;
  final int slotsCompleted;
  final int totalCommittedSlots;
  final int zeroNoteCount;
  final int fallPoints;
  final int violationCount;
  final int checklistDone;
  final int totalChecklistItems;
  final String grade;
}

class BlockingRuleRow {
  BlockingRuleRow({
    required this.id,
    required this.appId,
    required this.appName,
    required this.category,
    required this.domains,
    required this.isHardBlocked,
    required this.isBlocked,
    required this.requiresUnhook,
    required this.createdAtMs,
  });

  final String id;
  final String appId;
  final String appName;
  final String category;
  final List<String> domains;
  final bool isHardBlocked;
  final bool isBlocked;
  final bool requiresUnhook;
  final int createdAtMs;

  factory BlockingRuleRow.fromRow(Row r) => BlockingRuleRow(
        id: r['id'] as String,
        appId: r['app_id'] as String,
        appName: r['app_name'] as String,
        category: r['category'] as String,
        domains: (r['domains'] as String).split(','),
        isHardBlocked: (r['is_hard_blocked'] as int) != 0,
        isBlocked: (r['is_blocked'] as int) != 0,
        requiresUnhook: (r['requires_unhook'] as int) != 0,
        createdAtMs: r['created_at_ms'] as int,
      );
}

class UnlockSessionRow {
  UnlockSessionRow({
    required this.id,
    required this.dayId,
    required this.appId,
    required this.appName,
    required this.intent,
    required this.durationMin,
    required this.startedAtMs,
    required this.expiresAtMs,
    required this.completed,
    required this.revoked,
  });

  final String id;
  final String dayId;
  final String appId;
  final String appName;
  final String intent;
  final int durationMin;
  final int startedAtMs;
  final int? expiresAtMs;
  final bool completed;
  final bool revoked;

  DateTime get startedAt => DateTime.fromMillisecondsSinceEpoch(startedAtMs);
  DateTime? get expiresAt => expiresAtMs != null ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs!) : null;

  bool get isActive {
    if (completed || revoked) return false;
    if (expiresAtMs == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  int get remainingSeconds {
    if (expiresAtMs == null) return 0;
    final remaining = expiresAt!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  factory UnlockSessionRow.fromRow(Row r) => UnlockSessionRow(
        id: r['id'] as String,
        dayId: r['day_id'] as String,
        appId: r['app_id'] as String,
        appName: r['app_name'] as String,
        intent: r['intent'] as String,
        durationMin: r['duration_min'] as int,
        startedAtMs: r['started_at_ms'] as int,
        expiresAtMs: r['expires_at_ms'] as int?,
        completed: (r['completed'] as int) != 0,
        revoked: (r['revoked'] as int) != 0,
      );
}

class HallOfShameRow {
  HallOfShameRow({
    required this.id,
    required this.dayId,
    required this.taskId,
    required this.screenshotPath,
    required this.reason,
    required this.createdAtMs,
  });

  final String id;
  final String dayId;
  final String? taskId;
  final String screenshotPath;
  final String reason;
  final int createdAtMs;

  DateTime get createdAt => DateTime.fromMillisecondsSinceEpoch(createdAtMs);
}
