import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../blocking/blocking_constants.dart';

class UnhookService {
  static const String _unhookVerifiedKey = 'unhook_verified';
  static const String _unhookInstallDateKey = 'unhook_install_date';

  bool _isVerified = false;
  DateTime? _verifiedAt;

  bool get isVerified => _isVerified;
  DateTime? get verifiedAt => _verifiedAt;

  void setVerified(bool verified) {
    _isVerified = verified;
    _verifiedAt = verified ? DateTime.now() : null;
  }

  bool get needsReverification {
    if (!_isVerified || _verifiedAt == null) return true;
    final daysSinceVerification = DateTime.now().difference(_verifiedAt!).inDays;
    return daysSinceVerification >= 7;
  }

  String get installInstructions {
    return '''
To enable YouTube access:

1. Install the Unhook extension
   → Chrome: https://chrome.google.com/webstore/detail/unhook-youtube-remove-rec/jpfpebmajhhopehlkelmimbodnpnlihg
   → Firefox: https://addons.mozilla.org/en-US/firefox/addon/unhook-youtube

2. Configure Unhook settings:
   ✓ Block YouTube Shorts
   ✓ Disable autoplay
   ✓ Hide comments
   ✓ Hide recommendations

3. Come back and confirm below

Note: Unhook helps you stay focused by removing distractions from YouTube.
''';
  }
}

final unhookServiceProvider = Provider<UnhookService>((ref) {
  return UnhookService();
});

class UnlockSession {
  final String id;
  final String appId;
  final String appName;
  final String intent;
  final int durationMinutes;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final bool active;
  final bool expired;

  UnlockSession({
    required this.id,
    required this.appId,
    required this.appName,
    required this.intent,
    required this.durationMinutes,
    required this.startedAt,
    this.expiresAt,
    this.active = true,
    this.expired = false,
  });

  int get remainingMinutes {
    if (expiresAt == null) return durationMinutes;
    final remaining = expiresAt!.difference(DateTime.now()).inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  int get remainingSeconds {
    if (expiresAt == null) return 0;
    final remaining = expiresAt!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  double get progressPercent {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final total = durationMinutes * 60;
    if (total == 0) return 0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  UnlockSession copyWithExpired() {
    return UnlockSession(
      id: id,
      appId: appId,
      appName: appName,
      intent: intent,
      durationMinutes: durationMinutes,
      startedAt: startedAt,
      expiresAt: expiresAt,
      active: false,
      expired: true,
    );
  }
}

class UnhookAppInfo {
  final String id;
  final String name;
  final String category;
  final List<String> domains;
  final bool requiresUnhook;
  final bool isHardBlocked;

  const UnhookAppInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.domains,
    this.requiresUnhook = false,
    this.isHardBlocked = false,
  });

  static List<UnhookAppInfo> get availableApps => [
    const UnhookAppInfo(
      id: 'youtube',
      name: 'YouTube',
      category: 'Video',
      domains: BlockingConstants.youtubeDomains,
      requiresUnhook: true,
    ),
    const UnhookAppInfo(
      id: 'instagram',
      name: 'Instagram',
      category: 'Social',
      domains: ['instagram.com', 'www.instagram.com', 'api.instagram.com', 'i.instagram.com', 'graph.instagram.com'],
    ),
  ];
}
