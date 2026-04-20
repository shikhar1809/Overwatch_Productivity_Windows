import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers.dart';

final currentTimeProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});

final lastKnownDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _checkMidnightReset();
    _midnightTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkMidnightReset();
    });
  }

  void _checkMidnightReset() {
    final now = DateTime.now();
    final lastDate = ref.read(lastKnownDateProvider);
    
    if (now.day != lastDate.day || now.month != lastDate.month || now.year != lastDate.year) {
      ref.read(lastKnownDateProvider.notifier).state = now;
      ref.read(sessionRefreshProvider.notifier).state++;
      ref.read(activeUnlocksRefreshProvider.notifier).state++;
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  static const _destinations = [
    _NavSpec('Morning', Icons.wb_sunny_outlined, '/morning'),
    _NavSpec('Plan', Icons.grid_on_outlined, '/planner'),
    _NavSpec('Session', Icons.timer_outlined, '/session'),
    _NavSpec('OverWatch', Icons.visibility_outlined, '/monitor'),
    _NavSpec('Stats', Icons.bar_chart_outlined, '/stats'),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = widget.navigationShell.currentIndex;
    final isDark = ref.watch(themeProvider);
    final currentTimeAsync = ref.watch(currentTimeProvider);

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 120,
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            child: Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    selectedIndex: idx,
                    onDestinationSelected: widget.navigationShell.goBranch,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    leading: Column(
                      children: [
                        const SizedBox(height: 8),
                        Image.asset('assets/logo.png', width: 44, height: 44),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: Icon(
                            isDark ? Icons.light_mode : Icons.dark_mode,
                            color: isDark ? Colors.amber : Colors.grey.shade600,
                          ),
                          onPressed: () {
                            ref.read(themeProvider.notifier).state = !isDark;
                          },
                          tooltip: isDark ? 'Light Mode' : 'Dark Mode',
                        ),
                      ],
                    ),
                    destinations: [
                      for (final d in _destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon, color: isDark ? Colors.white70 : null),
                          selectedIcon: Icon(d.icon, color: Theme.of(context).colorScheme.primary),
                          label: Text(
                            d.label,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => launchUrl(Uri.parse('https://www.linkedin.com/in/shikhar-shahi-7934a327a/')),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: RichText(
                          text: TextSpan(
                            text: 'Built by ',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                            children: [
                              TextSpan(
                                text: 'Shikhar Shahi',
                                style: TextStyle(fontSize: 12, color: isDark ? Colors.amber : Colors.blue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                currentTimeAsync.when(
                  data: (now) => _LiveClock(now, isDark),
                  loading: () => _LiveClock(DateTime.now(), isDark),
                  error: (_, __) => _LiveClock(DateTime.now(), isDark),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: isDark ? Colors.grey.shade800 : null),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }
}

class _LiveClock extends StatelessWidget {
  final DateTime now;
  final bool isDark;

  const _LiveClock(this.now, this.isDark);

  @override
  Widget build(BuildContext context) {
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        children: [
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateStr,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.label, this.icon, this.path);
  final String label;
  final IconData icon;
  final String path;
}
