import 'window_tracker.dart';

class FocusScore {
  final int score; // 0–100
  final String reason;
  final bool isViolation;

  const FocusScore({
    required this.score,
    required this.reason,
    required this.isViolation,
  });
}

class FocusScorer {
  List<String> blockedProcesses;
  List<String> blockedTitleKeywords;

  static const _defaultBlockedProcesses = [
    'discord.exe',
    'telegram.exe',
    'whatsapp.exe',
    'slack.exe',
    'spotify.exe',
    'steam.exe',
    'epicgameslauncher.exe',
    'valorant.exe',
    'leagueclient.exe',
  ];

  static const _defaultBlockedTitleKeywords = [
    'youtube',
    'netflix',
    'instagram',
    'facebook',
    'twitter',
    'tiktok',
    'reddit',
    'twitch',
    'snapchat',
    'hinge',
    'tinder',
    '9gag',
    'buzzfeed',
    'prime video',
  ];

  static const _productiveProcesses = [
    'code.exe',        // VS Code
    'devenv.exe',      // Visual Studio
    'cursor.exe',      // Cursor IDE
    'pycharm64.exe',
    'idea64.exe',
    'webstorm64.exe',
    'clion64.exe',
    'android studio',
    'sublime_text.exe',
    'notepad++.exe',
    'vim.exe',
    'nvim.exe',
    'winword.exe',     // MS Word
    'excel.exe',
    'powerpnt.exe',
    'onenote.exe',
    'acrobat.exe',
    'adobe',
    'figma.exe',
    'blender.exe',
    'unity.exe',
    'unreal',
    'cmd.exe',
    'powershell.exe',
    'wt.exe',          // Windows Terminal
    'hyper.exe',
    'postman.exe',
    'insomnia.exe',
    'dbeaver.exe',
    'tableplus.exe',
  ];

  FocusScorer({
    List<String>? blockedProcesses,
    List<String>? blockedTitleKeywords,
  })  : blockedProcesses = blockedProcesses ?? List.from(_defaultBlockedProcesses),
        blockedTitleKeywords =
            blockedTitleKeywords ?? List.from(_defaultBlockedTitleKeywords);

  FocusScore evaluate({
    required WindowInfo? window,
    required Duration idleTime,
    required String taskName,
    required List<String> taskKeywords,
  }) {
    // No window at all
    if (window == null) {
      return const FocusScore(
        score: 70,
        reason: 'No active window detected',
        isViolation: false,
      );
    }

    final title = window.title.toLowerCase();
    final process = window.processName.toLowerCase();

    // ── Hard violations (score = 0) ─────────────────────────────────────────

    // Blocked process names
    for (final blocked in blockedProcesses) {
      if (process.contains(blocked.toLowerCase())) {
        return FocusScore(
          score: 0,
          reason: '🚫 Blocked app open: ${window.processName}',
          isViolation: true,
        );
      }
    }

    // Blocked title keywords (catches browser tabs like "YouTube - Chrome")
    for (final keyword in blockedTitleKeywords) {
      if (title.contains(keyword.toLowerCase())) {
        return FocusScore(
          score: 0,
          reason: '🚫 Off-task site detected: "$keyword" in "${window.title}"',
          isViolation: true,
        );
      }
    }

    // ── Idle penalty ────────────────────────────────────────────────────────

    if (idleTime.inMinutes >= 10) {
      return FocusScore(
        score: 20,
        reason: '💤 Idle for ${idleTime.inMinutes} min — are you still there?',
        isViolation: true,
      );
    }

    if (idleTime.inMinutes >= 5) {
      return FocusScore(
        score: 50,
        reason: '⚠️ Idle for ${idleTime.inMinutes} min',
        isViolation: false,
      );
    }

    // ── Task keyword match (best positive signal) ────────────────────────────

    for (final keyword in taskKeywords) {
      if (keyword.length >= 3 && title.contains(keyword)) {
        return FocusScore(
          score: 100,
          reason: '✅ On task — "$keyword" found in: "${window.title}"',
          isViolation: false,
        );
      }
    }

    // ── Known productive app ─────────────────────────────────────────────────

    for (final prod in _productiveProcesses) {
      if (process.contains(prod.toLowerCase())) {
        return FocusScore(
          score: 85,
          reason: '✅ Productive app: ${window.processName}',
          isViolation: false,
        );
      }
    }

    // ── Neutral / unknown ────────────────────────────────────────────────────

    return FocusScore(
      score: 65,
      reason: '🔍 Unknown: "${window.title}" — not matched to task',
      isViolation: false,
    );
  }

  /// Extracts meaningful keywords from the task name string.
  static List<String> extractKeywords(String taskName) {
    const stopWords = {
      'a', 'an', 'the', 'in', 'on', 'at', 'for', 'and', 'or', 'to',
      'do', 'my', 'with', 'is', 'be', 'of', 'by', 'as', 'it', 'its',
      'this', 'that', 'are', 'was', 'from', 'up', 'out',
    };
    return taskName
        .toLowerCase()
        .split(RegExp(r'[\s,;.\-_]+'))
        .where((w) => w.length >= 3 && !stopWords.contains(w))
        .toList();
  }
}
