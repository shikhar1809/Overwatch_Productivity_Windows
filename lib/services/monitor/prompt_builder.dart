class PromptBuilder {
  static const List<String> alwaysRejectedDomains = [
    'instagram.com',
    'facebook.com',
    'twitter.com',
    'x.com',
    'reddit.com',
    'tiktok.com',
    'snapchat.com',
    'linkedin.com',
    'netflix.com',
    'twitch.tv',
    'spotify.com',
    'youtube.com',
    'news.',
    'wikipedia.org',
  ];

  static const List<String> alwaysRejectedApps = [
    'Spotify',
    'Discord',
    'Telegram',
    'WhatsApp',
    'Messages',
    'Slack',
  ];

  static String buildPrompt({
    required String taskName,
    required String? taskType,
  }) {
    final inferredType = taskType ?? _inferTaskType(taskName);

    return '''
Active task: $taskName
Task type: $inferredType

Question: Does the visible screen content show work directly relevant to this task?

Answer YES or NO, then one sentence of reasoning.

Rules:
- Music players (Spotify, YouTube Music, Apple Music) are always NO
- Social media (Instagram, Twitter, Reddit, TikTok, Facebook) is always NO
- Chat apps (WhatsApp, Telegram, Discord) are NO unless the task is explicitly communication work
- News sites are NO
- Shopping sites are NO
- A lecture video on the task subject is YES
- Notes, textbooks, IDE, documents on the task subject are YES
- Code editor/terminal for programming tasks is YES
- Research articles relevant to the task are YES

Answer format:
VERDICT: YES or NO
REASONING: [one sentence explaining why]
''';
  }

  static String _inferTaskType(String taskName) {
    final lower = taskName.toLowerCase();

    if (lower.contains('study') ||
        lower.contains('learn') ||
        lower.contains('read') ||
        lower.contains('book')) {
      return 'study';
    }

    if (lower.contains('code') ||
        lower.contains('program') ||
        lower.contains('develop') ||
        lower.contains('build') ||
        lower.contains('debug')) {
      return 'code';
    }

    if (lower.contains('write') ||
        lower.contains('essay') ||
        lower.contains('article') ||
        lower.contains('blog') ||
        lower.contains('document')) {
      return 'write';
    }

    if (lower.contains('design') ||
        lower.contains('draw') ||
        lower.contains('paint') ||
        lower.contains('illustrate') ||
        lower.contains('create')) {
      return 'design';
    }

    if (lower.contains('video') ||
        lower.contains('edit') ||
        lower.contains('render') ||
        lower.contains('animate')) {
      return 'video';
    }

    return 'other';
  }

  static bool parseVerdict(String response) {
    final upper = response.toUpperCase();
    if (upper.contains('VERDICT: YES') || upper.startsWith('YES')) {
      return true;
    }
    if (upper.contains('VERDICT: NO') || upper.startsWith('NO')) {
      return false;
    }
    return true;
  }

  static String parseReasoning(String response) {
    final lines = response.split('\n');
    for (final line in lines) {
      if (line.toUpperCase().startsWith('REASONING:')) {
        return line.substring('REASONING:'.length).trim();
      }
    }
    return response;
  }
}

class InferenceResult {
  final bool verdict;
  final String reasoning;
  final Duration inferenceTime;
  final String rawResponse;

  InferenceResult({
    required this.verdict,
    required this.reasoning,
    required this.inferenceTime,
    required this.rawResponse,
  });

  bool get isViolation => !verdict;

  @override
  String toString() =>
      'InferenceResult(verdict: $verdict, reasoning: $reasoning, time: ${inferenceTime.inMilliseconds}ms)';
}
