import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _NavSpec('Morning', Icons.wb_sunny_outlined, '/morning'),
    _NavSpec('Plan', Icons.grid_on_outlined, '/planner'),
    _NavSpec('OverWatch', Icons.visibility_outlined, '/monitor'),
    _NavSpec('Stats', Icons.bar_chart_outlined, '/shame'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idx = navigationShell.currentIndex;
    final isDark = ref.watch(themeProvider);

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
                    onDestinationSelected: navigationShell.goBranch,
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
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => launchUrl(Uri.parse('https://www.linkedin.com/in/shikhar-shahi-7934a327a/')),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
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
              ],
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: isDark ? Colors.grey.shade800 : null),
          Expanded(child: navigationShell),
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
