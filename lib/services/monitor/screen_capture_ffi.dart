import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'screen_capture_service.dart';

class WindowsScreenCaptureService implements ScreenCaptureService {
  bool _initialized = false;
  bool _paused = false;
  int _interval = 30;
  String? _tempDir;

  @override
  bool get isPaused => _paused;

  @override
  int get currentInterval => _interval;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _tempDir = Directory.systemTemp.path;
    _initialized = true;
    debugPrint('WindowsScreenCaptureService initialized');
  }

  @override
  Future<Uint8List?> captureScreenshot() async {
    if (!_initialized) await initialize();

    try {
      return await _captureWithPowerShell();
    } catch (e) {
      debugPrint('Screenshot capture failed: $e');
      return null;
    }
  }

  Future<Uint8List?> _captureWithPowerShell() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempPath = '$_tempDir\\focusos_screenshot_$timestamp.png';

    final script = '''
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

\$screen = [System.Windows.Forms.Screen]::PrimaryScreen
\$bitmap = New-Object System.Drawing.Bitmap(\$screen.Bounds.Width, \$screen.Bounds.Height)
\$graphics = [System.Drawing.Graphics]::FromImage(\$bitmap)
\$graphics.CopyFromScreen(\$screen.Bounds.Location, [System.Drawing.Point]::Empty, \$screen.Bounds.Size)
\$bitmap.Save('$tempPath', [System.Drawing.Imaging.ImageFormat]::Png)
\$graphics.Dispose()
\$bitmap.Dispose()

Write-Output '$tempPath'
''';

    final scriptPath = '$_tempDir\\focusos_capture_$timestamp.ps1';
    await File(scriptPath).writeAsString(script);

    try {
      final result = await Process.run(
        'powershell',
        ['-ExecutionPolicy', 'Bypass', '-File', scriptPath],
        runInShell: true,
      );

      await File(scriptPath).delete();

      if (result.exitCode != 0) {
        debugPrint('PowerShell error: ${result.stderr}');
        return null;
      }

      final filePath = result.stdout.toString().trim();
      final file = File(filePath);

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        await file.delete();
        return bytes;
      }

      return null;
    } catch (e) {
      await File(scriptPath).delete();
      debugPrint('PowerShell capture error: $e');
      return null;
    }
  }

  @override
  Future<void> setInterval(int seconds) async {
    _interval = seconds.clamp(15, 60);
    debugPrint('Capture interval set to $_interval seconds');
  }

  @override
  Future<void> pause() async {
    _paused = true;
    debugPrint('Screen capture paused');
  }

  @override
  Future<void> resume() async {
    _paused = false;
    debugPrint('Screen capture resumed');
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    _paused = false;
    debugPrint('WindowsScreenCaptureService disposed');
  }
}

class MockScreenCaptureService implements ScreenCaptureService {
  bool _initialized = false;
  bool _paused = false;
  int _interval = 30;
  int _captureCount = 0;

  @override
  bool get isPaused => _paused;

  @override
  int get currentInterval => _interval;

  @override
  Future<void> initialize() async {
    _initialized = true;
    debugPrint('MockScreenCaptureService initialized');
  }

  @override
  Future<Uint8List?> captureScreenshot() async {
    if (!_initialized) await initialize();
    _captureCount++;

    await Future.delayed(const Duration(milliseconds: 100));

    final mockPng = _generateMockPng();
    return mockPng;
  }

  Uint8List _generateMockPng() {
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
      0x54, 0x08, 0xD7, 0x63, 0x60, 0x60, 0x60, 0x00,
      0x00, 0x00, 0x05, 0x00, 0x01, 0x00, 0x18, 0xDD,
      0x8D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
  }

  @override
  Future<void> setInterval(int seconds) async {
    _interval = seconds.clamp(15, 60);
  }

  @override
  Future<void> pause() async {
    _paused = true;
  }

  @override
  Future<void> resume() async {
    _paused = false;
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    _paused = false;
    _captureCount = 0;
  }

  int get captureCount => _captureCount;
}
