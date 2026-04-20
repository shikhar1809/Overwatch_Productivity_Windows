import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/theme/theme_extensions.dart';
import '../../data/providers.dart';
import '../../services/monitor/violation_detector.dart';
import '../../services/monitor/violation_tracker.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  bool _isStarting = false;

  Timer? _timer;
  Timer? _slotRefreshTimer;
  int _remainingSeconds = 0;
  String? _activeSessionId;
  String _activeGoal = '';
  String? _activeSlotId;
  DateTime? _sessionStartTime;
  int _plannedDuration = 0;

  @override
  void initState() {
    super.initState();
    _slotRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.read(sessionRefreshProvider.notifier).state++;
    });
    _checkForActiveSession();
  }

  Future<void> _checkForActiveSession() async {
    final db = ref.read(appDatabaseProvider);
    final activeSession = db.getActiveSession(ref.read(todayDayIdProvider));
    if (activeSession != null && activeSession.remainingSeconds != null && activeSession.remainingSeconds! > 0) {
      _activeSessionId = activeSession.id;
      _activeGoal = activeSession.goal;
      _activeSlotId = activeSession.slotId;
      _plannedDuration = activeSession.durationMinutes;
      _remainingSeconds = activeSession.remainingSeconds!;
      
      final detector = ref.read(violationDetectorSingletonProvider);
      final dayId = ref.read(todayDayIdProvider);
      
      if (!detector.faceMonitor.isInitialized) {
        await detector.faceMonitor.initialize(
          soundPath: r'c:\Users\royal\Desktop\Productive\Phone_Sound_Effect.mp3',
          dayId: dayId,
          onPhoneDetectedCallback: (reason) {
            db.addHallOfShameEntry(
              dayId: dayId,
              sessionId: _activeSessionId,
              screenshotPath: 'face_${DateTime.now().millisecondsSinceEpoch}.log',
              reason: reason,
            );
          },
        );
      }
      
      if (detector.faceMonitor.isInitialized) {
        await detector.faceMonitor.start(forceReconnect: true);
      }
      
      _startTimerFromRecovery();
      
      if (mounted) setState(() {});
    }
  }

  void _startTimerFromRecovery() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          if (_remainingSeconds % 10 == 0 && _activeSessionId != null) {
            final db = ref.read(appDatabaseProvider);
            db.updateSessionRemainingSeconds(_activeSessionId!, _remainingSeconds);
          }
        } else {
          _timer?.cancel();
          _showAccountabilityDialog();
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slotRefreshTimer?.cancel();
    super.dispose();
  }

  void _testClick() {
    setState(() {
      _remainingSeconds = 10;
    });
  }

  void _manualStartSession(String goal, String slotId, int duration, int slotEndMinute) {
    // Use WidgetsBinding to ensure we're on main thread
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doStartSession(goal, slotId, duration, slotEndMinute);
    });
  }
  
  void _doStartSession(String goal, String slotId, int duration, int slotEndMinute) {
    int smartDuration = duration;
    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;
    if (slotEndMinute > currentMinute) {
      smartDuration = slotEndMinute - currentMinute;
    }
    if (smartDuration < 1) smartDuration = 1;
    
    final db = ref.read(appDatabaseProvider);
    final dayId = ref.read(todayDayIdProvider);
    
    String createdId = db.createSession(
      dayId: dayId,
      goal: goal,
      durationMinutes: smartDuration,
      slotId: slotId,
    );

    _activeSessionId = createdId;
    _activeGoal = goal;
    _activeSlotId = slotId;
    _sessionStartTime = now;
    _plannedDuration = smartDuration;
    _remainingSeconds = smartDuration * 60;

    _startTimerLoop();
    
    setState(() {});
  }

  Future<void> _startSession(String goal, String? slotId, int duration, {int? slotEndMinute}) async {
    setState(() => _isStarting = true);

    int smartDuration = duration;
    if (slotEndMinute != null) {
      final now = DateTime.now();
      final currentMinute = now.hour * 60 + now.minute;
      if (slotEndMinute > currentMinute) {
        smartDuration = slotEndMinute - currentMinute;
      }
    }
    
    final db = ref.read(appDatabaseProvider);
    final dayId = ref.read(todayDayIdProvider);
    
    _activeSessionId = db.createSession(
      dayId: dayId,
      goal: goal,
      durationMinutes: smartDuration,
      slotId: slotId,
    );

    _activeGoal = goal;
    _activeSlotId = slotId;
    _sessionStartTime = DateTime.now();
    _plannedDuration = smartDuration;
    _remainingSeconds = smartDuration * 60;

    ref.read(isMonitorEnabledProvider.notifier).state = true;
    ref.read(sessionRefreshProvider.notifier).state++;

    _startTimerLoop();
    
    if (mounted) {
      setState(() => _isStarting = false);
    }
  }

  void _startTimerLoop() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          if (_remainingSeconds % 10 == 0 && _activeSessionId != null) {
            final db = ref.read(appDatabaseProvider);
            db.updateSessionRemainingSeconds(_activeSessionId!, _remainingSeconds);
          }
        } else {
          _timer?.cancel();
          _showAccountabilityDialog();
        }
      });
    });
  }

  Future<void> _endSessionEarly() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Session Early?'),
        content: const Text('You can still log your accountability for this session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Session'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _timer?.cancel();
      await _showAccountabilityDialog();
    }
  }

  Future<void> _showAccountabilityDialog() async {
    final db = ref.read(appDatabaseProvider);
    final dayId = ref.read(todayDayIdProvider);
    final distractions = db.listHallOfShameForDay(dayId);
    final sessionDistractions = distractions.where((d) => d.sessionId == _activeSessionId).length;
    final focusScore = (100 - (sessionDistractions * 20)).clamp(0, 100);
    
    int? selectedCoverage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          final textColorSecondary = isDark ? Colors.grey[400]! : Colors.grey[600]!;
          
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.assignment_turned_in, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('Session Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _activeGoal,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'How focused were you? Be honest with yourself.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Coverage Percentage',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [0, 25, 50, 75, 100].map((coverage) {
                    final selected = selectedCoverage == coverage;
                    return ChoiceChip(
                      label: Text('$coverage%'),
                      selected: selected,
                      selectedColor: Colors.green.shade200,
                      onSelected: (sel) {
                        setDialogState(() => selectedCoverage = sel ? coverage : null);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        focusScore >= 80 ? Icons.emoji_events : (focusScore >= 50 ? Icons.thumb_up : Icons.warning_amber),
                        color: focusScore >= 80 ? Colors.amber : (focusScore >= 50 ? Colors.blue : Colors.orange),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Focus Score: $focusScore/100',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: focusScore >= 80 ? Colors.amber.shade700 : (focusScore >= 50 ? Colors.blue : Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($sessionDistractions distractions)',
                        style: TextStyle(fontSize: 12, color: textColorSecondary),
                      ),
                    ],
                  ),
                ),
                if (selectedCoverage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.stars, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Points earned: $selectedCoverage',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              FilledButton(
                onPressed: selectedCoverage != null
                    ? () {
                        Navigator.pop(dialogContext);
                        _completeSession(selectedCoverage!);
                      }
                    : null,
                child: const Text('Log Session'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _completeSession(int coverage) {
    if (_activeSessionId != null) {
      final db = ref.read(appDatabaseProvider);
      db.completeSession(
        sessionId: _activeSessionId!,
        coveragePercent: coverage,
      );

      _showNotification(
        'Session Logged',
        'Coverage: $coverage% | Points: $coverage',
      );
    }

    _cleanup();
  }

  void _cleanup() {
    _timer?.cancel();
    _activeSessionId = null;
    _activeGoal = '';
    _activeSlotId = null;
    _sessionStartTime = null;
    _plannedDuration = 0;
    _remainingSeconds = 0;
    ref.read(sessionRefreshProvider.notifier).state++;
    if (mounted) setState(() {});
  }

  void _showNotification(String title, String body) {
    debugPrint('Notification: $title - $body');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionRefreshProvider);
    final detector = ref.read(violationDetectorSingletonProvider);
    final sessionPoints = ref.watch(todaySessionPointsProvider);
    final sessions = ref.watch(todaySessionsProvider);
    final attendedSessions = sessions.where((s) => s.attended).length;
    final currentSlot = ref.watch(currentActiveSlotProvider);
    final nextSlot = ref.watch(nextUpcomingSlotProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, sessionPoints, attendedSessions),
          const SizedBox(height: 32),
          if (!_isSessionActive) ...[
            if (currentSlot != null)
              _buildCurrentSlotCard(context, currentSlot)
            else if (nextSlot != null)
              _buildNextSlotCard(context, nextSlot)
            else
              _buildNoSlotsCard(context),
            const SizedBox(height: 28),
            _buildTodaySessionsCard(context, sessions),
          ] else
            _buildActiveSessionCard(context, detector),
        ],
      ),
    );
  }

  bool get _isSessionActive => _activeSessionId != null && _remainingSeconds > 0;

  Widget _buildHeader(BuildContext context, int points, int attended) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.teal.shade600],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.timer_outlined, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Focus Sessions',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '$points points from $attended sessions today',
                style: TextStyle(color: context.textColorSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentSlotCard(BuildContext context, dynamic slot) {
    final duration = slot.endMinute - slot.startMinute;
    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;
    final minsRemaining = slot.startMinute - currentMinute;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_filled, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'IN PROGRESS',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  slot.timeRange,
                  style: TextStyle(
                    color: context.textColorSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              slot.label.isNotEmpty ? slot.label : _getTaskTitle(ref, slot.taskId),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: context.textColorSecondary),
                const SizedBox(width: 4),
                Text(
                  '$duration minutes',
                  style: TextStyle(color: context.textColorSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                _testClick();
              },
              child: Container(
                color: Colors.green,
                padding: const EdgeInsets.all(16),
                child: Text('TAP TO START', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextSlotCard(BuildContext context, dynamic slot) {
    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;
    final minutesUntil = slot.startMinute - currentMinute;
    final duration = slot.endMinute - slot.startMinute;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, color: Colors.blue, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'UPCOMING',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Starts in $minutesUntil min',
                  style: TextStyle(
                    color: context.textColorSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              slot.label.isNotEmpty ? slot.label : _getTaskTitle(ref, slot.taskId),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 18, color: context.textColorSecondary),
                const SizedBox(width: 4),
                Text(
                  slot.timeRange,
                  style: TextStyle(color: context.textColorSecondary),
                ),
                const SizedBox(width: 16),
                Icon(Icons.timer_outlined, size: 18, color: context.textColorSecondary),
                const SizedBox(width: 4),
                Text(
                  '$duration min',
                  style: TextStyle(color: context.textColorSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isStarting
                    ? null
                    : () => _startSession(
                          slot.label.isNotEmpty ? slot.label : _getTaskTitle(ref, slot.taskId),
                          slot.id,
                          duration,
                          slotEndMinute: slot.endMinute,
                        ),
                icon: _isStarting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_isStarting ? 'Starting...' : 'Start Early'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSlotsCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_outlined, size: 64, color: context.textColorTertiary),
            const SizedBox(height: 16),
            Text('No Planned Sessions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Go to the Plan tab to schedule your day.', style: TextStyle(color: context.textColorSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveSessionCard(BuildContext context, ViolationDetector detector) {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    final totalSeconds = _plannedDuration * 60;
    final elapsed = totalSeconds > 0 ? _remainingSeconds / totalSeconds : 1.0;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text('SESSION ACTIVE', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(_activeGoal, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Text('${m}m ${s}s left', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: 1.0 - elapsed, minHeight: 8, backgroundColor: Colors.green.withValues(alpha: 0.2), valueColor: AlwaysStoppedAnimation(Colors.green)),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _endSessionEarly,
              icon: const Icon(Icons.stop),
              label: const Text('End Early'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySessionsCard(BuildContext context, List sessions) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history, size: 20, color: context.textColorSecondary),
                const SizedBox(width: 8),
                Text("Today's Sessions", style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            if (sessions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No sessions yet today.', style: TextStyle(color: context.textColorSecondary)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final session = sessions[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(session.attended ? Icons.check_circle : Icons.cancel, color: session.attended ? Colors.green : Colors.red, size: 20),
                    title: Text(session.goal, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${session.formattedDuration} • ${session.coveragePercent ?? 0}% coverage', style: TextStyle(fontSize: 11, color: context.textColorSecondary)),
                    trailing: Text('${session.pointsEarned} pts', style: TextStyle(color: Colors.green.shade400, fontWeight: FontWeight.bold)),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _getTaskTitle(WidgetRef ref, String? taskId) {
    if (taskId == null || taskId.isEmpty) return 'Work Session';
    final tasks = ref.read(todayTasksProvider);
    try {
      final task = tasks.firstWhere((t) => t.id == taskId);
      return task.title;
    } catch (_) {
      return 'Work Session';
    }
  }
}