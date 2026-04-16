import 'window_tracker.dart';

enum TaskMode { dsa, college }

class AppBlocker {
  // ── Always blocked (regardless of task) ───────────────────────────────────
  static const _alwaysBlockedTitleKeywords = [
    'instagram',
    'x.com',
    'twitter',
    'facebook',
    'snapchat',
    'tiktok',
    '9gag',
    'reddit',
  ];

  static const _alwaysBlockedProcesses = [
    'instagram.exe',
    'snap.exe',
    'tweetdeck.exe',
    'discord.exe',
    'telegram.exe',
  ];

  // ── YouTube task keywords ──────────────────────────────────────────────────
  static const _dsaYoutubeKeywords = [
    'algorithm',
    'leetcode',
    'dsa',
    'data structure',
    'neetcode',
    'striver',
    'coding',
    'programming',
    'competitive',
    'binary search',
    'dynamic programming',
    'graph',
    'tree',
    'recursion',
    'complexity',
    'interview',
  ];

  static const _collegeYoutubeKeywords = [
    'lecture',
    'class',
    'course',
    'tutorial',
    'professor',
    'university',
    'college',
    'lesson',
    'explanation',
    'study',
    'subject',
    'semester',
    'exam',
    'theory',
    'chapter',
  ];

  TaskMode mode;
  String customKeywords; // user can add extra keywords comma-separated

  AppBlocker({this.mode = TaskMode.dsa, this.customKeywords = ''});

  List<String> get activeYouTubeKeywords {
    final base = mode == TaskMode.dsa ? _dsaYoutubeKeywords : _collegeYoutubeKeywords;
    final extras = customKeywords
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();
    return [...base, ...extras];
  }

  /// Returns a reason string if the current window is blocked, null if it's OK.
  String? checkWindow(WindowInfo? window) {
    if (window == null) return null;

    final title = window.title.toLowerCase();
    final process = window.processName.toLowerCase();

    // Blocked processes
    for (final blocked in _alwaysBlockedProcesses) {
      if (process.contains(blocked)) {
        return '🚫 ${window.processName} is blocked';
      }
    }

    // Always blocked site keywords
    for (final kw in _alwaysBlockedTitleKeywords) {
      if (title.contains(kw)) {
        return '🚫 $kw detected — blocked';
      }
    }

    // YouTube: allowed only if title has task keywords
    if (title.contains('youtube')) {
      final allowed = activeYouTubeKeywords.any((kw) => title.contains(kw));
      if (!allowed) {
        return '🚫 Off-task YouTube detected';
      }
    }

    return null; // all good
  }
}
