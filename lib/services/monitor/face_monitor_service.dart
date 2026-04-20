import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// A single timestamped log entry from the face monitor sidecar.
class FaceLogEntry {
  final String ts;
  final String event;
  final String msg;

  const FaceLogEntry({
    required this.ts,
    required this.event,
    required this.msg,
  });

  factory FaceLogEntry.fromJson(Map<String, dynamic> j) => FaceLogEntry(
        ts: j['ts'] as String? ?? '',
        event: j['event'] as String? ?? '',
        msg: j['msg'] as String? ?? '',
      );
}

/// Maps the Python sidecar `cause` string to a human-readable label.
String _causeLabel(String? cause) {
  switch (cause) {
    case 'yolo_phone':
    case 'yolo_phone_lap':
      return '📱 Physical phone detected';
    case 'gaze_pitch':
      return '👇 Looking down (phone in lap)';
    case 'head_yaw':
      return '↔️ Head turned away from screen';
    default:
      return '⚠️ Distraction detected';
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

class FaceMonitorService {
  // ── internal state ─────────────────────────────────────────────────────────
  bool _initialized = false;
  bool _isRunning   = false;
  bool _alarmPlaying = false;

  Process? _sidecar;
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _soundPath;

  void Function(String reason)? onPhoneDetected;

  // ── public notifiers ───────────────────────────────────────────────────────
  final ValueNotifier<String>           statusText       = ValueNotifier('Offline');
  final ValueNotifier<int>              snapCount        = ValueNotifier(0);
  final ValueNotifier<int>              focusScore       = ValueNotifier(100);
  final ValueNotifier<Uint8List?>       previewFrame     = ValueNotifier(null);
  final ValueNotifier<List<FaceLogEntry>> sessionLogs    = ValueNotifier(const []);
  final ValueNotifier<bool>             isRunningNotifier = ValueNotifier(false);
  /// Last distraction cause label (human-readable). Updated on every PHONE_DISTRACTION.
  final ValueNotifier<String>           lastCause        = ValueNotifier('');

  // ── public getters ─────────────────────────────────────────────────────────
  bool get isRunning     => isRunningNotifier.value;
  bool get isAlarmPlaying => _alarmPlaying;
  bool get isInitialized => _initialized;

  // ── initialize ─────────────────────────────────────────────────────────────

  Future<bool> initialize({
    required String soundPath,
    String? dayId,
    void Function(String reason)? onPhoneDetectedCallback,
  }) async {
    // Always update the callback — even if already initialised.
    // This fixes the bug where toggling the monitor manually from Settings
    // would set _initialized=true with NO callback, and any later call from
    // SessionScreen would hit the early-return and never wire up the callback.
    if (onPhoneDetectedCallback != null) {
      onPhoneDetected = onPhoneDetectedCallback;
    }

    if (_initialized) return true;  // heavy setup only once

    _soundPath = soundPath;

    // Verify the Python sidecar script exists
    final scriptPath = _sidecarPath();
    final scriptFile = File(scriptPath);
    if (!scriptFile.existsSync()) {
      statusText.value = 'Sidecar not found: $scriptPath';
      debugPrint('FaceMonitor: sidecar missing at $scriptPath');
      return false;
    }

    _initialized = true;
    statusText.value = 'Ready — tap toggle to start';
    debugPrint('FaceMonitor: initialized. Sidecar: $scriptPath');
    return true;
  }

  // ── start ──────────────────────────────────────────────────────────────────

  Future<void> start({bool forceReconnect = false}) async {
    if (!_initialized) return;

    // Check if sidecar is dead and needs restart
    bool needsRestart = forceReconnect || _sidecar == null;
    if (!needsRestart && _sidecar!.pid > 0) {
      try {
        // Process is running, just arm
        _sendArm(reconnect: forceReconnect);
        return;
      } catch (_) {
        needsRestart = true;
      }
    }

    _isRunning    = true;
    _alarmPlaying = false;
    isRunningNotifier.value = true;
    focusScore.value  = 100;
    sessionLogs.value = [];
    snapCount.value   = 0;
    statusText.value  = 'Starting sidecar…';

    // Kill any existing zombie
    if (_sidecar != null) {
      try { _sidecar!.kill(); } catch (_) {}
    }

    try {
      _sidecar = await Process.start(
        'python',
        [_sidecarPath()],
        runInShell: true,
      );

      // stdout → JSON events
      _stdoutSub = _sidecar!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onSidecarLine, onDone: _onSidecarDone);

      // stderr → debug log only
      _stderrSub = _sidecar!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => debugPrint('[sidecar stderr] $line'));

      debugPrint('FaceMonitor: sidecar process started (pid ${_sidecar!.pid})');
    } catch (e) {
      debugPrint('FaceMonitor: failed to start sidecar: $e');
      statusText.value = 'Error starting sidecar: $e';
      _isRunning = false;
      isRunningNotifier.value = false;
    }
  }

  void _sendArm({bool reconnect = false}) {
    _sendCmd({'cmd': 'ARM', 'reconnect': reconnect});
    _isRunning = true;
    isRunningNotifier.value = true;
    statusText.value = 'Monitoring face…';
  }

  // ── stop ───────────────────────────────────────────────────────────────────

  void stop() {
    if (!isRunningNotifier.value) return;
    _isRunning = false;
    isRunningNotifier.value = false;
    _sendCmd('DISARM');
    _stopAlarm();
    // Give the sidecar a moment to emit SESSION_SUMMARY, then kill it
    Future.delayed(const Duration(milliseconds: 800), _killSidecar);
    statusText.value = 'Stopped';
    debugPrint('FaceMonitor: stopped');
  }

  // ── dispose ────────────────────────────────────────────────────────────────

  Future<void> dispose() async {
    stop();
    _killSidecar();
    await _audioPlayer.dispose();
    _initialized = false;
  }

  // ── sidecar comms ──────────────────────────────────────────────────────────

  void _sendCmd(dynamic cmd) {
    try {
      final payload = cmd is String ? {'cmd': cmd} : cmd as Map<String, dynamic>;
      _sidecar?.stdin.writeln(jsonEncode(payload));
      _sidecar?.stdin.flush();
    } catch (e) {
      debugPrint('FaceMonitor: sendCmd($cmd) failed: $e');
    }
  }

  void _killSidecar() {
    _stdoutSub?.cancel();
    _stderrSub?.cancel();
    try {
      _sendCmd('QUIT');
    } catch (_) {}
    try {
      _sidecar?.kill(ProcessSignal.sigterm);
    } catch (_) {}
    _sidecar = null;
  }

  void _onSidecarDone() {
    debugPrint('FaceMonitor: sidecar stdout closed');
    if (_isRunning) {
      statusText.value = 'Sidecar disconnected';
      _isRunning = false;
    }
  }

  // ── event handling ─────────────────────────────────────────────────────────

  void _onSidecarLine(String line) {
    if (line.trim().isEmpty) return;
    debugPrint('[sidecar] $line');

    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(line) as Map<String, dynamic>;
    } catch (_) {
      return; // not a JSON line
    }

    final event = msg['event'] as String?;
    if (event == null) return;

    switch (event) {
      case 'READY':
        statusText.value = 'Sidecar ready — arming…';
        _sendArm();
        break;

      case 'STATUS':
        final m = msg['msg'] as String? ?? '';
        statusText.value = m;
        break;

      case 'PHONE_DISTRACTION':
        final cause      = msg['cause'] as String?;
        final causeLabel = _causeLabel(cause);
        lastCause.value  = causeLabel;
        statusText.value = '📵 $causeLabel';
        snapCount.value  = snapCount.value + 1;
        if (!_alarmPlaying) _startAlarm();
        onPhoneDetected?.call(causeLabel);
        break;

      case 'ALARM_DISMISSED':
        statusText.value = 'Alarm dismissed ✓';
        _stopAlarm();
        break;

      case 'NO_FACE':
        final secs = (msg['seconds'] as num?)?.toDouble() ?? 0;
        statusText.value = '😶 No face for ${secs.toStringAsFixed(0)}s';
        if (!_alarmPlaying) _startAlarm();
        onPhoneDetected?.call('No face detected - empty state');
        break;

      case 'FACE_BACK':
        statusText.value = 'Face detected — monitoring…';
        if (_alarmPlaying) _stopAlarm();
        break;

      case 'FOCUS_SCORE':
        _updateScore(msg);
        break;

      case 'SESSION_SUMMARY':
        _updateScore(msg);
        statusText.value = 'Session complete — score: ${focusScore.value}%';
        break;

      case 'FRAME':
        final b64 = msg['b64'] as String?;
        if (b64 != null) {
          previewFrame.value = base64Decode(b64);
        }
        break;

      case 'ERROR':
        final m = msg['msg'] as String? ?? 'Unknown error';
        debugPrint('FaceMonitor sidecar error: $m');
        statusText.value = 'Sidecar error (see logs)';
        break;
    }
  }

  void _updateScore(Map<String, dynamic> msg) {
    final score = (msg['score'] as num?)?.toInt() ?? focusScore.value;
    focusScore.value = score.clamp(0, 100);

    final rawLogs = msg['logs'] as List<dynamic>?;
    if (rawLogs != null) {
      final entries = rawLogs
          .whereType<Map<String, dynamic>>()
          .map(FaceLogEntry.fromJson)
          .toList();
      // newest first
      sessionLogs.value = entries.reversed.toList();
    }
  }

  // ── alarm ──────────────────────────────────────────────────────────────────

  void _startAlarm() {
    if (_soundPath == null || _alarmPlaying) return;
    try {
      _alarmPlaying = true;
      _audioPlayer.setReleaseMode(ReleaseMode.loop);
      _audioPlayer.play(DeviceFileSource(_soundPath!));
      debugPrint('FaceMonitor: alarm started');
    } catch (e) {
      debugPrint('FaceMonitor: alarm play error: $e');
      _alarmPlaying = false;
    }
  }

  void _stopAlarm() {
    if (!_alarmPlaying) return;
    try {
      _alarmPlaying = false;
      _audioPlayer.stop();
      debugPrint('FaceMonitor: alarm stopped');
    } catch (e) {
      debugPrint('FaceMonitor: alarm stop error: $e');
    }
  }

  // ── path helper ────────────────────────────────────────────────────────────

  static String _sidecarPath() {
    // Resolve relative to the executable / project root at runtime.
    // In debug: project root is the CWD when running `flutter run`.
    // In release: exe lives in build/windows/x64/runner/Release/
    // We walk up until we find python_sidecar/detector.py.
    final candidates = [
      r'c:\Users\royal\Desktop\Productive\focus_os\python_sidecar\detector.py',
      'python_sidecar/detector.py',
      '../python_sidecar/detector.py',
      '../../python_sidecar/detector.py',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    // Default absolute path (works during development)
    return r'c:\Users\royal\Desktop\Productive\focus_os\python_sidecar\detector.py';
  }
}
