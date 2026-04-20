import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'router/app_router.dart';
import 'services/monitor/violation_detector.dart';
import 'services/monitor/violation_tracker.dart';
import 'services/timeline/timeline_service.dart';

final violationDetectorSingletonProvider = Provider<ViolationDetector>((ref) {
  return ViolationDetector();
});

class FocusOSApp extends ConsumerStatefulWidget {
  const FocusOSApp({super.key});

  @override
  ConsumerState<FocusOSApp> createState() => _FocusOSAppState();
}

class _FocusOSAppState extends ConsumerState<FocusOSApp> with TrayListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(timelineServiceProvider).start();
      final isEnabled = ref.read(isMonitorEnabledProvider);
      if (isEnabled) {
        final detector = ref.read(violationDetectorSingletonProvider);
        final dayId = ref.read(todayDayIdProvider);
        
        await detector.faceMonitor.initialize(
          soundPath: r'c:\Users\royal\Desktop\Productive\Phone_Sound_Effect.mp3',
          dayId: dayId,
          onPhoneDetectedCallback: (reason) {
            final db = ref.read(appDatabaseProvider);
            db.addHallOfShameEntry(
              dayId: dayId,
              screenshotPath: 'face_${DateTime.now().millisecondsSinceEpoch}.log',
              reason: reason,
            );
          },
        );
        detector.startMonitoring(
          taskId: 'auto_start',
          taskName: 'Focus Mode',
        );
      }
    });
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
        return;
      case 'quit':
        trayManager.destroy();
        windowManager.close();
        exit(0);
      default:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final isDark = ref.watch(themeProvider);
    
    return MaterialApp.router(
      title: 'Focus OS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
