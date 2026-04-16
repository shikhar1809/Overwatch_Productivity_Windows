import 'dart:typed_data';

abstract class ScreenCaptureService {
  Future<void> initialize();
  Future<Uint8List?> captureScreenshot();
  Future<void> setInterval(int seconds);
  Future<void> pause();
  Future<void> resume();
  bool get isPaused;
  int get currentInterval;
  Future<void> dispose();
}

enum CaptureResult {
  success,
  noDisplay,
  permissionDenied,
  unknownError,
}

class Screenshot {
  final Uint8List bytes;
  final int width;
  final int height;
  final DateTime capturedAt;

  Screenshot({
    required this.bytes,
    required this.width,
    required this.height,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();

  int get sizeBytes => bytes.length;

  @override
  String toString() =>
      'Screenshot(${width}x$height, ${sizeBytes} bytes, ${capturedAt.toIso8601String()})';
}
