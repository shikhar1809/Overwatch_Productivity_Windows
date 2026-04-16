import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class IdleTracker {
  /// Returns how long the system has had no keyboard or mouse input.
  Duration getIdleDuration() {
    final lii = calloc<LASTINPUTINFO>();
    try {
      lii.ref.cbSize = sizeOf<LASTINPUTINFO>();
      if (GetLastInputInfo(lii) == 0) return Duration.zero;

      // GetTickCount wraps every ~49 days, handle overflow gracefully
      final now = GetTickCount();
      final last = lii.ref.dwTime;
      final idleMs = (now >= last) ? (now - last) : (0xFFFFFFFF - last + now);
      return Duration(milliseconds: idleMs);
    } finally {
      free(lii);
    }
  }
}
