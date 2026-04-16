import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../data/providers.dart';
import 'violation_detector.dart';

class ViolationTrackerState {
  final Map<String, int> slotViolationCounts;
  final List<ViolationRecord> violations;
  final bool isMonitoring;
  final String? activeTaskId;
  final String? activeSlotId;

  ViolationTrackerState({
    this.slotViolationCounts = const {},
    this.violations = const [],
    this.isMonitoring = false,
    this.activeTaskId,
    this.activeSlotId,
  });

  int getSlotViolationCount(String slotId) => slotViolationCounts[slotId] ?? 0;

  ViolationTier getSlotTier(String slotId) {
    final count = getSlotViolationCount(slotId);
    switch (count) {
      case 0:
        return ViolationTier.none;
      case 1:
        return ViolationTier.warning;
      case 2:
        return ViolationTier.compromised;
      default:
        return ViolationTier.forfeited;
    }
  }

  ViolationTrackerState copyWith({
    Map<String, int>? slotViolationCounts,
    List<ViolationRecord>? violations,
    bool? isMonitoring,
    String? activeTaskId,
    String? activeSlotId,
  }) {
    return ViolationTrackerState(
      slotViolationCounts: slotViolationCounts ?? this.slotViolationCounts,
      violations: violations ?? this.violations,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      activeTaskId: activeTaskId ?? this.activeTaskId,
      activeSlotId: activeSlotId ?? this.activeSlotId,
    );
  }
}

class ViolationRecord {
  final String id;
  final String taskId;
  final String? slotId;
  final ViolationTier tier;
  final String reasoning;
  final DateTime timestamp;

  ViolationRecord({
    required this.id,
    required this.taskId,
    this.slotId,
    required this.tier,
    required this.reasoning,
    required this.timestamp,
  });
}

final violationTrackerProvider =
    StateNotifierProvider<ViolationTrackerNotifier, ViolationTrackerState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ViolationTrackerNotifier(db, ref);
});

class ViolationTrackerNotifier extends StateNotifier<ViolationTrackerState> {
  final AppDatabase _db;
  final Ref _ref;

  ViolationTrackerNotifier(this._db, this._ref) : super(ViolationTrackerState());

  void startTracking(String taskId, String? slotId) {
    state = state.copyWith(
      isMonitoring: true,
      activeTaskId: taskId,
      activeSlotId: slotId,
    );
  }

  void stopTracking() {
    state = state.copyWith(
      isMonitoring: false,
      activeTaskId: null,
      activeSlotId: null,
    );
  }

  void recordViolation({
    required String taskId,
    String? slotId,
    required ViolationTier tier,
    required String reasoning,
  }) {
    final newCounts = Map<String, int>.from(state.slotViolationCounts);

    if (slotId != null) {
      newCounts[slotId] = (newCounts[slotId] ?? 0) + 1;
    }

    final violation = ViolationRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      taskId: taskId,
      slotId: slotId,
      tier: tier,
      reasoning: reasoning,
      timestamp: DateTime.now(),
    );

    final newViolations = [...state.violations, violation];

    state = state.copyWith(
      slotViolationCounts: newCounts,
      violations: newViolations,
    );

    _persistViolation(taskId, slotId, reasoning, tier);
    _updateTaskViolationStatus(taskId, tier);
  }

  void _persistViolation(
    String taskId,
    String? slotId,
    String reasoning,
    ViolationTier tier,
  ) {
    try {
      _db.insertViolation(
        taskId: taskId,
        slotId: slotId,
        verdict: false,
        reasoningText: reasoning,
      );
    } catch (e) {
      print('Failed to persist violation: $e');
    }
  }

  void _updateTaskViolationStatus(String taskId, ViolationTier tier) {
    switch (tier) {
      case ViolationTier.warning:
      case ViolationTier.compromised:
        _db.setTaskCompromised(taskId, compromised: true);
        break;
      case ViolationTier.forfeited:
        _db.setTaskCompromised(taskId, compromised: true);
        _db.setTaskForfeited(taskId, forfeited: true);
        break;
      default:
        break;
    }
  }

  void clearForSlot(String slotId) {
    final newCounts = Map<String, int>.from(state.slotViolationCounts);
    newCounts.remove(slotId);

    final newViolations = state.violations.where((v) => v.slotId != slotId).toList();

    state = state.copyWith(
      slotViolationCounts: newCounts,
      violations: newViolations,
    );
  }

  void clearAll() {
    state = ViolationTrackerState();
  }
}

final monitorIntervalProvider = StateProvider<int>((ref) => 15);

final isMonitorEnabledProvider = StateProvider<bool>((ref) => false);
