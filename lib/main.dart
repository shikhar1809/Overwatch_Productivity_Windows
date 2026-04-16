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
  } on Object {
    // Elevation or policy may block autostart; non-fatal for Phase 1.
  }
}
