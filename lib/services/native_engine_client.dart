import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Contract for the future Rust sidecar / FFI: screen capture + Gemma verdicts.
///
/// Phase 1 ships a stub that simulates IPC so UI and state wiring can proceed.
abstract class NativeEngineClient {
  bool get isConnected;

  Stream<MonitorEvent> get events;

  Future<void> connect();

  Future<void> disconnect();

  /// Push active task context when a slot is committed (real impl sends to sidecar).
  Future<void> setActiveTaskContext({required String taskTitle, String? taskType});

  Future<void> startMonitoring({Duration interval = const Duration(seconds: 30)});

  Future<void> stopMonitoring();
}

class MonitorEvent {
  MonitorEvent({
    required this.kind,
    this.verdict,
    this.reasoning,
  });

  final MonitorEventKind kind;
  final bool? verdict;
  final String? reasoning;
}

enum MonitorEventKind { connected, disconnected, verdict, heartbeat, error }

/// Stub engine: emits periodic heartbeats; [simulateViolation] can inject a fake NO verdict.
class StubNativeEngineClient implements NativeEngineClient {
  StubNativeEngineClient();

  final _controller = StreamController<MonitorEvent>.broadcast();
  Timer? _heartbeat;
  bool _connected = false;
  bool _monitoring = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<MonitorEvent> get events => _controller.stream;

  @override
  Future<void> connect() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _connected = true;
    _controller.add(MonitorEvent(kind: MonitorEventKind.connected));
  }

  @override
  Future<void> disconnect() async {
    _heartbeat?.cancel();
    _monitoring = false;
    _connected = false;
    _controller.add(MonitorEvent(kind: MonitorEventKind.disconnected));
  }

  @override
  Future<void> setActiveTaskContext({required String taskTitle, String? taskType}) async {
    if (!_connected) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<void> startMonitoring({Duration interval = const Duration(seconds: 30)}) async {
    if (!_connected) return;
    _monitoring = true;
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(interval, (_) {
      if (!_monitoring) return;
      _controller.add(MonitorEvent(kind: MonitorEventKind.heartbeat));
    });
  }

  @override
  Future<void> stopMonitoring() async {
    _monitoring = false;
    _heartbeat?.cancel();
  }

  /// Test hook: emit a fake irrelevant-screen verdict (NO).
  void simulateViolation({required String reasoning}) {
    _controller.add(MonitorEvent(
      kind: MonitorEventKind.verdict,
      verdict: false,
      reasoning: reasoning,
    ));
  }

  void dispose() {
    _heartbeat?.cancel();
    _controller.close();
  }
}

final nativeEngineProvider = Provider<StubNativeEngineClient>((ref) {
  final client = StubNativeEngineClient();
  ref.onDispose(client.dispose);
  return client;
});
