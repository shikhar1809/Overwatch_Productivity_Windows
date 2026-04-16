import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';
import '../../services/blocking/blocking_constants.dart';
import '../../services/blocking/windows_blocking.dart';
import '../../services/unhook/unhook_service.dart';
import 'widgets/active_unlocks_list.dart';
import 'widgets/unlock_request_dialog.dart';
import 'widgets/unlock_history_view.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;
  final WindowsBlockingService _blockingService = WindowsBlockingService();
  bool _hasPermissions = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initBlocking();
    _startRefreshTimer();
  }

  Future<void> _initBlocking() async {
    await _blockingService.initialize();
    _hasPermissions = await _blockingService.hasElevatedPermissions();
    if (!_hasPermissions) {
      _hasPermissions = await _blockingService.requestElevatedPermissions();
    }
    await _applyDefaultBlocks();
    _initialized = true;
    setState(() {});
  }

  Future<void> _applyDefaultBlocks() async {
    if (!_hasPermissions) return;

    try {
      final db = ref.read(appDatabaseProvider);
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
      await _blockingService.applyBlocks(domains);
    } catch (e) {
      debugPrint('Failed to apply blocks: $e');
    }
  }

  void _startRefreshTimer() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(activeUnlocksRefreshProvider.notifier).state++;
      _checkExpiredSessions();
    });
  }

  Future<void> _checkExpiredSessions() async {
    final db = ref.read(appDatabaseProvider);
    final activeSessions = db.listActiveUnlockSessions();

    for (final session in activeSessions) {
      if (!session.isActive) {
        db.completeUnlockSession(session.id);
        if (_hasPermissions) {
          await _blockingService.applyBlocks(
            AppInfo.predefinedApps
                .where((a) => a.id == session.appId)
                .expand((a) => a.domains)
                .toList(),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _showUnlockDialog(UnhookAppInfo app) {
    showDialog(
      context: context,
      builder: (ctx) => UnlockRequestDialog(
        app: app,
        onUnlock: (intent, duration) async {
          await _startUnlock(app, intent, duration);
        },
      ),
    );
  }

  Future<void> _startUnlock(UnhookAppInfo app, String intent, int duration) async {
    final db = ref.read(appDatabaseProvider);
    final dayId = ref.read(todayDayIdProvider);

    final sessionId = db.createUnlockSession(
      dayId: dayId,
      appId: app.id,
      appName: app.name,
      intent: intent,
      durationMinutes: duration,
    );

    if (_hasPermissions) {
      await _blockingService.removeBlocks(app.domains);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${app.name} unlocked for $duration minutes'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.black,
            onPressed: () => _tabController.animateTo(1),
          ),
        ),
      );
    }

    ref.invalidate(activeUnlockSessionsProvider);
    ref.invalidate(todayUnlockSessionsProvider);
  }

  Future<void> _revokeUnlock(UnlockSessionRow session) async {
    final db = ref.read(appDatabaseProvider);
    db.revokeUnlockSession(session.id);

    AppInfo? app;
    try {
      app = AppInfo.predefinedApps.firstWhere(
        (a) => a.id == session.appId,
      );
    } catch (_) {
      app = null;
    }

    if (_hasPermissions && app != null) {
      await _blockingService.applyBlocks(app.domains);
      await _blockingService.forceCloseBrowsers();
    }

    ref.invalidate(activeUnlockSessionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final areRedTasksComplete = ref.watch(areRedTasksCompleteProvider);
    final unhookVerified = ref.watch(unhookVerifiedProvider);
    final stats = ref.watch(unlockStatsProvider);

    return Column(
      children: [
        _buildHeader(context, areRedTasksComplete, unhookVerified),
        const SizedBox(height: 16),
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Unlock'),
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUnlockTab(context, areRedTasksComplete, unhookVerified),
              ActiveUnlocksList(
                onRevoke: _revokeUnlock,
                onRefresh: () => ref.invalidate(activeUnlockSessionsProvider),
              ),
              UnlockHistoryView(stats: stats),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool redTasksComplete, bool unhookVerified) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unlock', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(
                  'Access blocked apps with intent gating',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: context.textColorSecondary),
                ),
              ],
            ),
          ),
          _buildStatusBadge(
            context,
            'Red Tasks',
            redTasksComplete ? 'Complete' : 'Incomplete',
            redTasksComplete ? Colors.green : Colors.amber,
          ),
          const SizedBox(width: 12),
          _buildStatusBadge(
            context,
            'Unhook',
            unhookVerified ? 'Verified' : 'Not Set',
            unhookVerified ? Colors.green : Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: context.textColorSecondary),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockTab(BuildContext context, bool redTasksComplete, bool unhookVerified) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPrerequisitesCard(context, redTasksComplete, unhookVerified),
          const SizedBox(height: 24),
          Text('Available Apps', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildAppsGrid(context, redTasksComplete, unhookVerified),
        ],
      ),
    );
  }

  Widget _buildPrerequisitesCard(BuildContext context, bool redTasksComplete, bool unhookVerified) {
    final canUnlock = redTasksComplete && unhookVerified;

    return Card(
      color: canUnlock ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  canUnlock ? Icons.check_circle : Icons.warning,
                  color: canUnlock ? Colors.green : Colors.amber,
                ),
                const SizedBox(width: 8),
                Text(
                  'Unlock Prerequisites',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: canUnlock ? Colors.green : Colors.amber,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPrerequisiteRow(
              'Red tasks complete',
              redTasksComplete,
              'Complete all red tasks before unlocking',
            ),
            const SizedBox(height: 8),
            _buildPrerequisiteRow(
              'Unhook verified',
              unhookVerified,
              'Install Unhook extension for YouTube',
            ),
            if (!unhookVerified) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _showUnhookSetup(context),
                icon: const Icon(Icons.extension),
                label: const Text('Setup Unhook'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPrerequisiteRow(String title, bool met, String description) {
    return Row(
      children: [
        Icon(
          met ? Icons.check_circle_outline : Icons.circle_outlined,
          size: 20,
          color: met ? Colors.green : context.textColorSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: met ? context.textColor : context.textColorSecondary,
                  fontWeight: met ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: context.textColorSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showUnhookSetup(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.extension),
            SizedBox(width: 8),
            Text('Setup Unhook'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Unhook removes YouTube distractions (Shorts, autoplay, recommendations, comments).',
              ),
              const SizedBox(height: 16),
              const Text('To install:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('1. Chrome: Visit the Chrome Web Store and search "Unhook"'),
              const Text('2. Firefox: Visit addons.mozilla.org and search "Unhook"'),
              const SizedBox(height: 16),
              const Text(
                'After installing, configure these settings in Unhook:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildUnhookSetting('Block YouTube Shorts', true),
              _buildUnhookSetting('Disable autoplay', true),
              _buildUnhookSetting('Hide recommendations', true),
              _buildUnhookSetting('Hide comments', true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(unhookVerifiedProvider.notifier).state = true;
              final db = ref.read(appDatabaseProvider);
              db.setSetting('unhook_verified', DateTime.now().toIso8601String());
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unhook verified! You can now unlock YouTube.'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('I\'ve installed Unhook'),
          ),
        ],
      ),
    );
  }

  Widget _buildUnhookSetting(String setting, bool required) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          Text(setting),
          if (required)
            Text(
              ' *',
              style: TextStyle(color: Colors.amber.shade700),
            ),
        ],
      ),
    );
  }

  Widget _buildAppsGrid(BuildContext context, bool redTasksComplete, bool unhookVerified) {
    final apps = UnhookAppInfo.availableApps;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: apps.length,
      itemBuilder: (context, i) {
        final app = apps[i];
        final canUnlock = redTasksComplete && (!app.requiresUnhook || unhookVerified);
        final isHardBlocked = AppInfo.predefinedApps.any((a) => a.id == app.id && a.isHardBlocked);

        return Card(
          color: canUnlock
              ? Theme.of(context).cardTheme.color
              : Colors.grey.withValues(alpha: 0.2),
          child: InkWell(
            onTap: canUnlock ? () => _showUnlockDialog(app) : null,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getAppColor(app.id).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        app.name[0],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _getAppColor(app.id),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              app.name,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (isHardBlocked) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LOCKED',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          app.category,
                          style: TextStyle(fontSize: 12, color: context.textColorSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!canUnlock)
                    Icon(Icons.lock, color: context.textColorSecondary)
                  else
                    Icon(Icons.arrow_forward_ios, size: 16, color: context.textColorTertiary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getAppColor(String appId) {
    switch (appId) {
      case 'youtube':
        return Colors.red;
      case 'instagram':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
