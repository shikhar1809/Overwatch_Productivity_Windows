import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class WindowInfo {
  final String title;
  final String processName;

  const WindowInfo({required this.title, required this.processName});

  @override
  String toString() => 'WindowInfo(title: "$title", process: "$processName")';
}

class WindowTracker {
  /// Returns information about the currently focused window, or null if none.
  WindowInfo? getActiveWindow() {
    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return null;

    final titleBuffer = wsalloc(512);
    final pidPtr = calloc<Uint32>();

    try {
      GetWindowText(hwnd, titleBuffer, 512);
      final title = titleBuffer.toDartString().trim();

      GetWindowThreadProcessId(hwnd, pidPtr);
      final pid = pidPtr.value;

      final processName = _getProcessName(pid);

      return WindowInfo(title: title, processName: processName);
    } finally {
      free(titleBuffer);
      free(pidPtr);
    }
  }

  String _getProcessName(int pid) {
    // PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
    final hProcess = OpenProcess(0x1000, FALSE, pid);
    if (hProcess == 0) return '';

    final buffer = wsalloc(MAX_PATH);
    final size = calloc<Uint32>()..value = MAX_PATH;

    try {
      QueryFullProcessImageName(hProcess, 0, buffer, size);
      final fullPath = buffer.toDartString();
      CloseHandle(hProcess);
      if (fullPath.isEmpty) return '';
      return fullPath.split('\\').last.toLowerCase();
    } catch (_) {
      CloseHandle(hProcess);
      return '';
    } finally {
      free(buffer);
      free(size);
    }
  }
}
