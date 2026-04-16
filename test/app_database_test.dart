import 'package:flutter_test/flutter_test.dart';
import 'package:focus_os/data/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.openMemory();
  });

  tearDown(() {
    db.dispose();
  });

  test('getOrCreateDayId is stable for same calendar date', () {
    final a = db.getOrCreateDayId('2026-04-14');
    final b = db.getOrCreateDayId('2026-04-14');
    expect(a, b);
  });

  test('insertTask and listTasksForDay', () {
    final day = db.getOrCreateDayId('2026-04-15');
    final tid = db.insertTask(dayId: day, title: 'Maths ch.5', priority: 'red');
    final tasks = db.listTasksForDay(day);
    expect(tasks, hasLength(1));
    expect(tasks.single.id, tid);
    expect(tasks.single.title, 'Maths ch.5');
    expect(tasks.single.violationCount, 0);
  });

  test('violations and incrementViolationCount', () {
    final day = db.getOrCreateDayId('2026-04-16');
    final tid = db.insertTask(dayId: day, title: 'Deep work', priority: 'amber');
    db.insertViolation(
      taskId: tid,
      verdict: false,
      reasoningText: 'Music player visible',
    );
    db.incrementViolationCount(tid);
    final t = db.listTasksForDay(day).single;
    expect(t.violationCount, 1);
    expect(db.listViolationsForTask(tid), hasLength(1));
  });

  test('settings roundtrip', () {
    db.setSetting('gemma_model_path', '/models/gemma.gguf');
    expect(db.getSetting('gemma_model_path'), '/models/gemma.gguf');
  });
}
