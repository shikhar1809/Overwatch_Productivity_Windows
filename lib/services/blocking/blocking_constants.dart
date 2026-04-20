class BlockingConstants {
  static const List<String> instagramDomains = [
    'instagram.com',
    'www.instagram.com',
    'api.instagram.com',
    'i.instagram.com',
    'graph.instagram.com',
  ];

  static const List<String> linkedinDomains = [
    'linkedin.com',
    'www.linkedin.com',
  ];

  static const List<String> youtubeDomains = [
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'youtu.be',
    'www.youtu.be',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  ];

  static const List<String> defaultBlockedDomains = [
    ...instagramDomains,
    ...linkedinDomains,
  ];

  static const List<String> socialMediaDomains = [
    'facebook.com',
    'www.facebook.com',
    'twitter.com',
    'www.twitter.com',
    'x.com',
    'www.x.com',
    'reddit.com',
    'www.reddit.com',
    'tiktok.com',
    'www.tiktok.com',
    'linkedin.com',
    'www.linkedin.com',
    'snapchat.com',
    'www.snapchat.com',
  ];

  static const List<String> entertainmentDomains = [
    'netflix.com',
    'www.netflix.com',
    'twitch.tv',
    'www.twitch.tv',
    'hulu.com',
    'www.hulu.com',
    'disneyplus.com',
    'www.disneyplus.com',
  ];

  static const int defaultUnlockDurationMinutes = 30;
  static const int minIntentLength = 20;

  static const List<int> unlockDurations = [15, 20, 30, 45, 60, 90];
}

class AppInfo {
  final String id;
  final String name;
  final List<String> domains;
  final String category;
  final bool isHardBlocked;

  const AppInfo({
    required this.id,
    required this.name,
    required this.domains,
    required this.category,
    this.isHardBlocked = false,
  });

  static const List<AppInfo> predefinedApps = [
    AppInfo(
      id: 'instagram',
      name: 'Instagram',
      domains: BlockingConstants.instagramDomains,
      category: 'Social Media',
      isHardBlocked: true,
    ),
    AppInfo(
      id: 'linkedin',
      name: 'LinkedIn',
      domains: BlockingConstants.linkedinDomains,
      category: 'Social Media',
      isHardBlocked: true,
    ),
    AppInfo(
      id: 'youtube',
      name: 'YouTube',
      domains: BlockingConstants.youtubeDomains,
      category: 'Entertainment',
      isHardBlocked: true,
    ),
    AppInfo(
      id: 'twitter',
      name: 'Twitter/X',
      domains: ['twitter.com', 'www.twitter.com', 'x.com', 'www.x.com'],
      category: 'Social Media',
      isHardBlocked: true,
    ),
    AppInfo(
      id: 'tiktok',
      name: 'TikTok',
      domains: ['tiktok.com', 'www.tiktok.com'],
      category: 'Social Media',
      isHardBlocked: true,
    ),
    AppInfo(
      id: 'netflix',
      name: 'Netflix',
      domains: ['netflix.com', 'www.netflix.com'],
      category: 'Entertainment',
      isHardBlocked: true,
    ),
    AppInfo(
      id: 'twitch',
      name: 'Twitch',
      domains: ['twitch.tv', 'www.twitch.tv'],
      category: 'Entertainment',
      isHardBlocked: true,
    ),
  ];
}
