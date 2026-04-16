import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          _buildComingSoon(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.bar_chart_outlined, color: Colors.blue, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stats',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Your daily statistics and progress tracking',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white70 
                          : Colors.black54,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoon(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.construction_outlined,
            size: 80,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white24 
                : Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            'Coming Soon',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white54 
                      : Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Stats and analytics will be available here',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white38 
                      : Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }
}
