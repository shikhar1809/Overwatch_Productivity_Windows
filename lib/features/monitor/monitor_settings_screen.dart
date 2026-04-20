import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/theme/theme_extensions.dart';
import '../../data/app_database.dart';
import '../../data/providers.dart';
import '../../services/monitor/app_blocker.dart';
import '../../services/monitor/violation_detector.dart';
import '../../services/monitor/violation_tracker.dart';

class MonitorSettingsScreen extends ConsumerStatefulWidget {
  const MonitorSettingsScreen({super.key});

  @override
  ConsumerState<MonitorSettingsScreen> createState() =>
      _MonitorSettingsScreenState();
}

class _MonitorSettingsScreenState
    extends ConsumerState<MonitorSettingsScreen> {
  MonitorStatus? _status;
  StreamSubscription<MonitorStatus>? _sub;
  bool _faceMonitorReady = false;
  bool _initializingFace = false;
  final _customKwController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final detector = ref.read(violationDetectorSingletonProvider);
    _sub = detector.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });

    Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      if (!detector.isMonitoring) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _customKwController.dispose();
    super.dispose();
  }

  Future<void> _initFaceMonitor() async {
    setState(() => _initializingFace = true);
    final detector = ref.read(violationDetectorSingletonProvider);
    final db = ref.read(appDatabaseProvider);
    final dayId = ref.read(todayDayIdProvider);
    
    await detector.faceMonitor.initialize(
      soundPath: r'c:\Users\royal\Desktop\Productive\Phone_Sound_Effect.mp3',
      dayId: dayId,
      onPhoneDetectedCallback: (reason) {
        db.addHallOfShameEntry(
          dayId: dayId,
          screenshotPath: 'face_${DateTime.now().millisecondsSinceEpoch}.log',
          reason: reason,
        );
        debugPrint('FaceMesh distraction saved to Hall of Shame');
      },
    );
    
    setState(() {
      _faceMonitorReady = detector.faceMonitor.isInitialized;
      _initializingFace = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionRefreshProvider);
    final interval = ref.watch(monitorIntervalProvider);
    final isEnabled = ref.watch(isMonitorEnabledProvider);
    final dayStarted = ref.watch(isDayStartedProvider) || ref.watch(areTasksSubmittedProvider);
    final sessionActive = ref.watch(isSessionActiveProvider);
    final locked = dayStarted || sessionActive;
    final detector = ref.read(violationDetectorSingletonProvider);
    final blocker = detector.blocker;

    final windowAlarm = _status?.windowAlarm ?? false;
    final faceAlarm = _status?.faceAlarm ?? false;
    final anyAlarm = windowAlarm || faceAlarm;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OverWatch',
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(
                    'Blocks Instagram, X, off-task YouTube. Watches your face.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: context.textColorSecondary),
                  ),
                ],
              ),
              const Spacer(),
              if (anyAlarm)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.volume_up,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        faceAlarm ? 'PHONE DETECTED' : 'SITE BLOCKED',
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          _buildLiveStatus(context, detector),
          const SizedBox(height: 24),

          _buildToggle(context, isEnabled, locked, detector),
          const SizedBox(height: 24),

          _buildTaskMode(context, blocker),
          const SizedBox(height: 24),

          _buildWebsiteBlocking(context),
          const SizedBox(height: 24),

          _buildFaceMonitor(context, detector, locked),
          const SizedBox(height: 24),

          _buildIntervalSlider(context, interval, locked, detector),
          const SizedBox(height: 24),

          _buildWhatIsBlocked(context, blocker),
        ],
      ),
    );
  }

  Widget _buildLiveStatus(BuildContext context, ViolationDetector detector) {
    final window = _status?.activeWindow.isNotEmpty == true
        ? _status!.activeWindow
        : detector.lastActiveWindow.isNotEmpty
            ? detector.lastActiveWindow
            : '—';
    final reason = _status?.statusReason.isNotEmpty == true
        ? _status!.statusReason
        : detector.lastStatusReason;
    final faceAlarm = _status?.faceAlarm ?? false;
    final windowAlarm = _status?.windowAlarm ?? false;

    Color statusColor = Colors.green;
    IconData statusIcon = Icons.check_circle_outline;
    if (windowAlarm) {
      statusColor = Colors.red;
      statusIcon = Icons.block;
    } else if (faceAlarm) {
      statusColor = Colors.orange;
      statusIcon = Icons.no_photography_outlined;
    }

    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined,
                    size: 20, color: statusColor),
                const SizedBox(width: 8),
                Text('Live Status',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 14),
            _statusRow(Icons.window_outlined, 'Active Window', window,
                Colors.blue),
            const SizedBox(height: 8),
            _statusRow(statusIcon, 'Status', reason, statusColor),
            const SizedBox(height: 8),
            _statusRow(
                detector.faceMonitor.isRunning
                    ? Icons.camera_alt
                    : Icons.videocam_off,
                'Webcam',
                detector.faceMonitor.isRunning
                    ? 'Active — watching for distractions'
                    : 'Disabled',
                detector.faceMonitor.isRunning ? Colors.deepPurple : Colors.grey),
            if (faceAlarm) ...[
              const SizedBox(height: 8),
              _statusRow(Icons.smartphone, 'Face Alert',
                  'Looking at phone > 5s!', Colors.orange),
            ],
            if (_status?.violationCount != null &&
                _status!.violationCount > 0) ...[
              const SizedBox(height: 8),
              _statusRow(Icons.warning_amber_outlined, 'Violations',
                  '${_status!.violationCount} this session', Colors.red),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.textColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(
      BuildContext context, bool isEnabled, bool locked, ViolationDetector detector) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isEnabled ? Colors.green : Colors.grey)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isEnabled ? Icons.visibility : Icons.visibility_off,
                color: isEnabled ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Block & Monitor',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    locked
                        ? 'Locked ON during session'
                        : isEnabled
                            ? 'Actively blocking distractions'
                            : 'Monitoring is off',
                    style: TextStyle(
                        fontSize: 12,
                        color: locked ? Colors.green : Colors.grey),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              activeColor: Colors.green,
              onChanged: locked
                  ? null
                  : (v) async {
                      if (v) {
                        ref.read(isMonitorEnabledProvider.notifier).state = true;
                        detector.startMonitoring(
                          taskId: 'manual',
                          taskName: 'Focus Mode',
                        );
                      } else {
                        ref.read(isMonitorEnabledProvider.notifier).state = false;
                        detector.stopMonitoring();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskMode(BuildContext context, AppBlocker blocker) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Task Mode',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Determines which YouTube videos are allowed.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _modeChip(
                    context,
                    label: 'DSA / Coding',
                    subtitle: 'LeetCode, algorithms, programming',
                    selected: blocker.mode == TaskMode.dsa,
                    onTap: () =>
                        setState(() => blocker.mode = TaskMode.dsa),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _modeChip(
                    context,
                    label: 'College Studies',
                    subtitle: 'Lectures, tutorials, courses',
                    selected: blocker.mode == TaskMode.college,
                    onTap: () =>
                        setState(() => blocker.mode = TaskMode.college),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _customKwController,
              decoration: const InputDecoration(
                labelText: 'Extra YouTube keywords (comma separated)',
                hintText: 'e.g. striver, operating systems',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => blocker.customKeywords = v,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebsiteBlocking(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block, size: 20),
                const SizedBox(width: 8),
                Text('Custom Blocked Websites',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Add websites to block during focus sessions.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _blockedSiteChip('linkedin.com'),
                _blockedSiteChip('whatsapp.com'),
                _blockedSiteChip('facebook.com'),
                _blockedSiteChip('twitter.com'),
                _blockedSiteChip('reddit.com'),
                _blockedSiteChip('tiktok.com'),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () => _showAddWebsiteDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Website'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blockedSiteChip(String site) {
    return Chip(
      label: Text(site, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.red.withValues(alpha: 0.1),
      labelStyle: const TextStyle(color: Colors.red),
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () {},
    );
  }

  void _showAddWebsiteDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Website to Block'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Website domain',
            hintText: 'e.g., example.com',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _modeChip(
    BuildContext context, {
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected ? color.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : Colors.grey.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? color : context.textColor,
                    fontSize: 13)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceMonitor(
      BuildContext context, ViolationDetector detector, bool locked) {
    final fm = detector.faceMonitor;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.face_retouching_natural,
                    size: 20, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text('FaceMesh Monitor',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                ValueListenableBuilder<bool>(
                  valueListenable: fm.isRunningNotifier,
                  builder: (_, running, __) {
                    if (!running) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('ACTIVE',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Detects phone distractions via head-pose + gaze direction. '
              'Raise both hands to dismiss alarm. '
              'Tracks desk absence & focus score per session.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.textColorSecondary),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _initializingFace
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : ValueListenableBuilder<bool>(
                              valueListenable: fm.isRunningNotifier,
                              builder: (_, running, __) => Icon(
                                running
                                    ? Icons.visibility
                                    : Icons.visibility_off_outlined,
                                color: running
                                    ? Colors.deepPurple
                                    : context.textColorTertiary,
                                size: 18,
                              ),
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ValueListenableBuilder<String>(
                          valueListenable: fm.statusText,
                          builder: (_, status, __) => Text(
                            _initializingFace ? 'Initialising…' : status,
                            style: TextStyle(
                              fontSize: 12,
                              color: fm.isRunning
                                  ? Colors.deepPurple
                                  : context.textColorSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: fm.isRunningNotifier,
                  builder: (_, running, __) => Switch(
                    value: running,
                    activeColor: Colors.deepPurple,
                    onChanged: _initializingFace || locked
                        ? null
                        : (bool value) async {
                            if (value) {
                              if (!fm.isInitialized) {
                                setState(() => _initializingFace = true);
                                final db    = ref.read(appDatabaseProvider);
                                final dayId = ref.read(todayDayIdProvider);
                                await fm.initialize(
                                  soundPath: r'c:\Users\royal\Desktop\Productive\Phone_Sound_Effect.mp3',
                                  dayId: dayId,
                                  onPhoneDetectedCallback: (reason) {
                                    db.addHallOfShameEntry(
                                      dayId: dayId,
                                      screenshotPath:
                                          'face_${DateTime.now().millisecondsSinceEpoch}.log',
                                      reason: reason,
                                    );
                                  },
                                );
                                if (mounted) {
                                  setState(() => _initializingFace = false);
                                }
                              }
                              if (fm.isInitialized) {
                                await fm.start(forceReconnect: true);
                              }
                            } else {
                              fm.stop();
                            }
                          },
                  ),
                ),
              ],
            ),
            ValueListenableBuilder<bool>(
              valueListenable: fm.isRunningNotifier,
              builder: (_, running, __) {
                if (!running) return const SizedBox.shrink();
                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ValueListenableBuilder<int>(
                          valueListenable: fm.snapCount,
                          builder: (_, count, __) => _monitorChip(
                            label: '$count distractions',
                            color: count > 0 ? Colors.red : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<int>(
                          valueListenable: fm.focusScore,
                          builder: (_, score, __) => _monitorChip(
                            label: 'Focus $score%',
                            color: score >= 75
                                ? Colors.green
                                : score >= 50
                                    ? Colors.orange
                                    : Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _monitorChip(
                            label: 'FaceMesh + Gaze',
                            color: Colors.deepPurple),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ValueListenableBuilder<Uint8List?>(
                      valueListenable: fm.previewFrame,
                      builder: (_, frameBytes, __) {
                        return Center(
                          child: SizedBox(
                            width: 180,
                            height: 180,
                            child: frameBytes == null
                                ? Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: const CircularProgressIndicator(),
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(
                                      frameBytes,
                                      width: 180,
                                      height: 180,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _monitorChip({required String label, required Color color}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildIntervalSlider(
      BuildContext context, int interval, bool locked, ViolationDetector detector) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, size: 20),
                const SizedBox(width: 8),
                Text('Check Interval',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${interval}s',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Slider(
              value: interval.toDouble(),
              min: 10,
              max: 60,
              divisions: 10,
              label: '${interval}s',
              onChanged: locked
                  ? null
                  : (v) {
                      ref.read(monitorIntervalProvider.notifier).state =
                          v.toInt();
                      detector.setInterval(v.toInt());
                    },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Builder(builder: (ctx) => Text('10s',
                    style:
                        TextStyle(fontSize: 11, color: ctx.textColorTertiary))),
                Builder(builder: (ctx) => Text('60s',
                    style:
                        TextStyle(fontSize: 11, color: ctx.textColorTertiary))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatIsBlocked(BuildContext context, AppBlocker blocker) {
    final ytKeywords = blocker.activeYouTubeKeywords.take(8).toList();
    return Card(
      color: Colors.red.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block_outlined,
                    size: 20, color: Colors.red),
                const SizedBox(width: 8),
                Text('What Is Blocked',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.red)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Always blocked:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textColorSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                'Instagram',
                'LinkedIn',
                'WhatsApp',
                'X / Twitter',
                'Facebook',
                'Snapchat',
                'TikTok',
                '9GAG',
                'Reddit',
                'Discord',
              ]
                  .map((s) => Chip(
                        label: Text(s,
                            style: const TextStyle(fontSize: 11)),
                        backgroundColor:
                            Colors.red.withValues(alpha: 0.08),
                        labelStyle:
                            const TextStyle(color: Colors.red),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text(
                'YouTube: allowed only with keywords (${blocker.mode == TaskMode.dsa ? 'DSA mode' : 'College mode'})',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textColorSecondary)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: ytKeywords
                  .map((kw) => Chip(
                        label: Text(kw,
                            style: const TextStyle(fontSize: 11)),
                        backgroundColor:
                            Colors.green.withValues(alpha: 0.08),
                        labelStyle:
                            const TextStyle(color: Colors.green),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
