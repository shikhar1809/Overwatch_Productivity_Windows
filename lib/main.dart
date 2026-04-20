import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:local_notifier/local_notifier.dart';

import 'app.dart';
import 'data/app_database.dart';
import 'data/providers.dart';
import 'services/blocking/windows_blocking.dart';
import 'services/blocking/blocking_constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid || Platform.isIOS) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }

  await localNotifier.setup(
    appName: 'FocusOS',
    shortcutPolicy: ShortcutPolicy.requireCreate,
  );

  final supportDir = await getApplicationSupportDirectory();
  final dbPath = p.join(supportDir.path, 'focus_os.db');
  final db = AppDatabase.open(dbPath);

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1100, 700),
    minimumSize: Size(800, 600),
    center: true,
    title: 'Focus OS',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await _initTray();
  await _initLaunchAtStartup();
  await _initBlocking(db);

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const FocusOSApp(),
    ),
  );
}

Future<void> _initTray() async {
  await trayManager.setIcon(await _trayIconPath());
  await trayManager.setToolTip('Focus OS');

  final menu = Menu(
    items: [
      MenuItem(key: 'show', label: 'Show Focus OS'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ],
  );
  await trayManager.setContextMenu(menu);
}

Future<String> _trayIconPath() async {
  final data = await rootBundle.load('assets/logo.png');
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, 'focus_os_tray.png'));
  await file.writeAsBytes(data.buffer.asUint8List());
  return file.path;
}

Future<void> _initLaunchAtStartup() async {
  if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;
  try {
    launchAtStartup.setup(
      appName: 'Focus OS',
      appPath: Platform.resolvedExecutable,
      args: const [],
    );
    await launchAtStartup.enable();
    final isEnabled = await launchAtStartup.isEnabled();
    print('[Startup] Auto-start enabled: $isEnabled');
  } on Object catch (e) {
    print('[Startup] Failed to enable auto-start: $e');
  }
}

Future<void> _initBlocking(AppDatabase db) async {
  if (!Platform.isWindows) return;
  try {
    final blockingService = WindowsBlockingService();
    await blockingService.initialize();
    
    final hasPermissions = await blockingService.hasElevatedPermissions();
    if (!hasPermissions) {
      await blockingService.requestElevatedPermissions();
    }

    final hardBlocked = db.listHardBlockedApps();
    if (hardBlocked.isEmpty) {
      for (final app in AppInfo.predefinedApps.where((a) => a.isHardBlocked)) {
        db.addBlockingRule(
          appId: app.id,
          appName: app.name,
          category: app.category,
          domains: app.domains,
          isHardBlocked: app.isHardBlocked,
          requiresUnhook: false,
        );
      }
    }

    final rules = db.listHardBlockedApps();
    final domains = rules.expand((r) => r.domains).toList();
    await blockingService.applyBlocks(domains);
    print('[Blocking] Initialized with ${rules.length} hard-blocked apps');
  } on Object catch (e) {
    print('[Blocking] Failed to initialize: $e');
  }
}
