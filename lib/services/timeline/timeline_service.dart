import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_notifier/local_notifier.dart';

import '../../data/app_database.dart';
import '../../data/providers.dart';

final timelineServiceProvider = Provider<TimelineService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TimelineService(db, ref);
});

class TimelineService {
  TimelineService(this._db, this._ref);

  final AppDatabase _db;
  final ProviderRef _ref;
  Timer? _timer;
  int _lastMinute = -1;
  String? _currentDayId;
  
  final Set<String> _sentNotifications = {};

  void start() {
    _timer?.cancel();
    _lastMinute = _getCurrentMinute();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
    debugPrint('TimelineService started.');
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  int _getCurrentMinute() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  String _formatTime(int minute) {
    final hour = minute ~/ 60;
    final min = minute % 60;
    return '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  }

  void _tick() {
    final currentMinute = _getCurrentMinute();
    if (currentMinute == _lastMinute) return;
    
    _lastMinute = currentMinute;
    
    try {
      final dayId = _ref.read(todayDayIdProvider);
      
      if (_currentDayId != dayId) {
        _currentDayId = dayId;
        _sentNotifications.clear();
      }
      
      final slots = _db.listCommittedSlotsForDay(dayId);
      final tasks = _db.listTasksForDay(dayId);
      
      for (final slot in slots) {
        if (slot.forfeited) continue;
        
        final taskName = slot.taskId != null 
            ? tasks.firstWhere(
                (t) => t.id == slot.taskId, 
                orElse: () => TaskRow(
                  id: '', dayId: '', title: 'Work Slot', 
                  priority: 'green', basePoints: 0, 
                  completed: false, violationCount: 0, 
                  forfeited: false, compromised: false, 
                  zeroNote: null, createdAtMs: 0
                )
              ).title
            : (slot.label.isNotEmpty ? slot.label : 'Work Slot');

        final slotDuration = slot.endMinute - slot.startMinute;
        final midwayPoint = slot.startMinute + (slotDuration ~/ 2);
        
        final basePoints = slot.taskId != null 
            ? (tasks.where((t) => t.id == slot.taskId).firstOrNull?.basePoints ?? 0)
            : 0;
        
        final cp20Points = (basePoints * 0.2).round();
        final cp50Points = (basePoints * 0.5).round();
        final cp100Points = basePoints;
        
        final slotKey = '${slot.id}_$currentMinute';
        
        if (slot.startMinute == currentMinute) {
          _showNotification(
            'Slot Started',
            'Time to focus: $taskName\n${_formatTime(slot.startMinute)} - ${_formatTime(slot.endMinute)}',
            'start_${slot.id}'
          );
        }
        
        if (midwayPoint == currentMinute && !_sentNotifications.contains('midway_${slot.id}')) {
          _showNotification(
            'Halfway There!',
            'Keep going: $taskName\nYou\'re halfway through!',
            'midway_${slot.id}'
          );
        }
        
        if (slot.startMinute > 0 && slot.startMinute - 30 == currentMinute) {
          _showNotification(
            'Upcoming: $taskName',
            'Work slot starting in 30 minutes!\n${_formatTime(slot.startMinute)} - ${_formatTime(slot.endMinute)}',
            'pre30_${slot.id}'
          );
        }
        
        if (slot.endMinute == currentMinute) {
          final totalPts = _calculateSlotPoints(slot, basePoints);
          _showNotification(
            'Slot Complete!',
            '$taskName finished\n+$totalPts points earned. Take a break!',
            'end_${slot.id}'
          );
        }
        
        if (slot.cp20 && !_sentNotifications.contains('cp20_${slot.id}')) {
          _showNotification(
            'Checkpoint 20%!',
            '$taskName: First checkpoint reached!\n+$cp20Points pts',
            'cp20_${slot.id}'
          );
        }
        
        if (slot.cp50 && !_sentNotifications.contains('cp50_${slot.id}')) {
          _showNotification(
            'Checkpoint 50%!',
            '$taskName: Halfway checkpoint!\n+$cp50Points pts',
            'cp50_${slot.id}'
          );
        }
        
        if (slot.cp100 && !_sentNotifications.contains('cp100_${slot.id}')) {
          _showNotification(
            'Slot Completed 100%!',
            '$taskName: Full completion!\n+$cp100Points pts earned!',
            'cp100_${slot.id}'
          );
        }
      }
    } catch (e, st) {
      debugPrint('TimelineService tick error: $e\n$st');
    }
  }

  int _calculateSlotPoints(SlotRow slot, int basePoints) {
    if (slot.cp100) return basePoints;
    
    int checkpointsHit = 0;
    if (slot.cp20) checkpointsHit++;
    if (slot.cp50) checkpointsHit++;
    if (slot.cp100) checkpointsHit++;
    
    switch (checkpointsHit) {
      case 3:
        return basePoints;
      case 2:
        return (basePoints * 0.75).round();
      case 1:
        return (basePoints * 0.4).round();
      default:
        return 0;
    }
  }

  void _showNotification(String title, String body, String notifKey) {
    if (_sentNotifications.contains(notifKey)) return;
    
    try {
      final notification = LocalNotification(
        title: title,
        body: body,
      );
      notification.onShow = () {
        debugPrint('Notification shown: $title - $body');
        _sentNotifications.add(notifKey);
      };
      notification.show();
    } catch (e) {
      debugPrint('Error showing notification: $e');
    }
  }
}
