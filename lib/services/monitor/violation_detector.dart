import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'app_blocker.dart';
import 'face_monitor_service.dart';
import 'window_tracker.dart';
import 'idle_tracker.dart';

// ── Public types (kept compatible with rest of app) ───────────────────────────

enum ViolationTier { none, warning, compromised, forfeited }

class ViolationInfo {
  final ViolationTier tier;
  final String reasoning;
  final DateTime timestamp;
  final int violationCount;

  ViolationInfo({
    required this.tier,
    required this.reasoning,
    required this.timestamp,
    required this.violationCount,
  });
}

class MonitorStatus {
  final bool isMonitoring;
  final bool isPaused;
  final String? currentTask;
  final int violationCount;
  final ViolationTier tier;
  final String activeWindow;
  final Duration idleTime;
  final bool faceAlarm;
  final bool windowAlarm;
  final String statusReason;

  MonitorStatus({
    required this.isMonitoring,
    required this.isPaused,
    this.currentTask,
    required this.violationCount,
    required this.tier,
    this.activeWindow = '',
    this.idleTime = Duration.zero,
    this.faceAlarm = false,
    this.windowAlarm = false,
    this.statusReason = '',
  });

  bool get hasActiveSlot => currentTask != null && isMonitoring && !isPaused;
}

// ── Main orchestrator ─────────────────────────────────────────────────────────

class ViolationDetector {
  final WindowTracker _windowTracker = WindowTracker();
  final IdleTracker _idleTracker = IdleTracker();
  final AppBlocker blocker = AppBlocker();
  final FaceMonitorService faceMonitor = FaceMonitorService();
  final AudioPlayer _windowAlarmPlayer = AudioPlayer();

  static const _soundPath =
      r'c:\Users\royal\Desktop\Productive\Sound_Effect.mp3';

  Timer? _windowTimer;
  bool _isMonitoring = false;
  bool _isPaused = false;
  bool _windowAlarmPlaying = false;

  String? _currentTaskId;
  String? _currentTaskName;
  String? _currentSlotId;
  int _violationCount = 0;
  int _intervalSeconds = 15;

  String _lastActiveWindow = '';
  Duration _lastIdleTime = Duration.zero;
  String _lastStatusReason = '—';

  final _violationController = StreamController<ViolationInfo>.broadcast();
  final _statusController = StreamController<MonitorStatus>.broadcast();

  Stream<ViolationInfo> get violationStream => _violationController.stream;
  Stream<MonitorStatus> get statusStream => _statusController.stream;

  bool get isMonitoring => _isMonitoring;
  bool get isPaused => _isPaused;
  int get currentViolationCount => _violationCount;
  ViolationTier get currentTier => _tier(_violationCount);
  String get lastActiveWindow => _lastActiveWindow;
  Duration get lastIdleTime => _lastIdleTime;
  String get lastStatusReason => _lastStatusReason;

  Future<void> initialize() async {
    // NOTE: Do NOT pre-initialize faceMonitor here.
    // FaceMonitorService requires an onPhoneDetectedCallback that captures
    // AppDatabase + dayId — context only available in UI screens.
    // Initialization is deferred to MonitorSettingsScreen / SessionScreen,
    // both of which call faceMonitor.initialize() with the correct callback.
    debugPrint('ViolationDetector: ready (face monitor deferred to UI).');
  }

  void startMonitoring({
    required String taskId,
    required String taskName,
    String? slotId,
    int intervalSeconds = 15,
  }) {
    if (_isMonitoring) return;
    _currentTaskId = taskId;
    _currentTaskName = taskName;
    _currentSlotId = slotId;
    _intervalSeconds = intervalSeconds;
    _violationCount = 0;
    _isMonitoring = true;
    _isPaused = false;

    _startWindowLoop();
    if (faceMonitor.isInitialized) faceMonitor.start();
    _emitStatus();

    debugPrint('OverWatch started: "$taskName"');
  }

  void _startWindowLoop() {
    _windowTimer?.cancel();
    _windowTimer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (_) => _checkWindow(),
    );
    _checkWindow();
  }

  void _checkWindow() {
    if (!_isMonitoring || _isPaused) return;

    final window = _windowTracker.getActiveWindow();
    final idleTime = _idleTracker.getIdleDuration();

    _lastActiveWindow = window?.title ?? '';
    _lastIdleTime = idleTime;

    final blockedReason = blocker.checkWindow(window);

    if (blockedReason != null) {
      _lastStatusReason = blockedReason;
      if (!_windowAlarmPlaying) {
        _windowAlarmPlaying = true;
        _windowAlarmPlayer.setReleaseMode(ReleaseMode.loop);
        _windowAlarmPlayer.play(DeviceFileSource(_soundPath));
      }
      _violationCount++;
      _violationController.add(ViolationInfo(
        tier: _tier(_violationCount),
        reasoning: blockedReason,
        timestamp: DateTime.now(),
        violationCount: _violationCount,
      ));
    } else {
      _lastStatusReason = '✅ On track — ${window?.title ?? 'No window'}';
      if (_windowAlarmPlaying) {
        _windowAlarmPlaying = false;
        _windowAlarmPlayer.stop();
      }
    }

    _emitStatus();
  }

  ViolationTier _tier(int count) {
    if (count == 0) return ViolationTier.none;
    if (count == 1) return ViolationTier.warning;
    if (count == 2) return ViolationTier.compromised;
    return ViolationTier.forfeited;
  }

  void pauseMonitoring({int? durationMinutes}) {
    if (!_isMonitoring) return;
    _isPaused = true;
    _windowAlarmPlaying = false;
    _windowAlarmPlayer.stop();
    faceMonitor.stop();
    _emitStatus();
    if (durationMinutes != null) {
      Future.delayed(
          Duration(minutes: durationMinutes), () => resumeMonitoring());
    }
  }

  void resumeMonitoring() {
    if (!_isMonitoring) return;
    _isPaused = false;
    if (faceMonitor.isInitialized) faceMonitor.start();
    _emitStatus();
    _checkWindow();
  }

  void stopMonitoring() {
    _windowTimer?.cancel();
    _windowTimer = null;
    _windowAlarmPlaying = false;
    _windowAlarmPlayer.stop();
    faceMonitor.stop();
    _isMonitoring = false;
    _isPaused = false;
    _currentTaskId = null;
    _currentTaskName = null;
    _currentSlotId = null;
    _violationCount = 0;
    _lastStatusReason = '—';
    _emitStatus();
  }

  void setInterval(int seconds) {
    _intervalSeconds = seconds.clamp(10, 60);
    if (_isMonitoring && !_isPaused) _startWindowLoop();
  }

  void _emitStatus() {
    if (_statusController.isClosed) return;
    _statusController.add(MonitorStatus(
      isMonitoring: _isMonitoring,
      isPaused: _isPaused,
      currentTask: _currentTaskName,
      violationCount: _violationCount,
      tier: currentTier,
      activeWindow: _lastActiveWindow,
      idleTime: _lastIdleTime,
      faceAlarm: faceMonitor.isAlarmPlaying,
      windowAlarm: _windowAlarmPlaying,
      statusReason: _lastStatusReason,
    ));
  }

  Future<void> dispose() async {
    stopMonitoring();
    await _windowAlarmPlayer.dispose();
    await faceMonitor.dispose();
    await _violationController.close();
    await _statusController.close();
  }
}
