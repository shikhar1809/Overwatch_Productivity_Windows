import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_extensions.dart';

final phoneSoundPathProvider = StateProvider<String>((ref) => r'c:\Users\royal\Desktop\Productive\Phone_Sound_Effect.mp3');
final noFaceSoundPathProvider = StateProvider<String>((ref) => r'c:\Users\royal\Desktop\Productive\NoFace_Sound_Effect.mp3');
final offTrackSoundPathProvider = StateProvider<String>((ref) => r'c:\Users\royal\Desktop\Productive\OffTrack_Sound_Effect.mp3');
final alarmVolumeProvider = StateProvider<double>((ref) => 1.0);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phoneSound = ref.watch(phoneSoundPathProvider);
    final noFaceSound = ref.watch(noFaceSoundPathProvider);
    final offTrackSound = ref.watch(offTrackSoundPathProvider);
    final volume = ref.watch(alarmVolumeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          _buildSoundSettings(context, ref, phoneSound, noFaceSound, offTrackSound, volume),
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
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.indigo.shade600],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.settings, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                'Customize your experience',
                style: TextStyle(color: context.textColorSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSoundSettings(BuildContext context, WidgetRef ref, String phoneSound, String noFaceSound, String offTrackSound, double volume) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.volume_up, size: 20),
                const SizedBox(width: 8),
                Text('Sound Effects', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Customize sounds for different violations.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            
            // Volume Slider
            Text('Alarm Volume: ${(volume * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w500)),
            Slider(
              value: volume,
              onChanged: (v) => ref.read(alarmVolumeProvider.notifier).state = v,
              min: 0.0,
              max: 1.0,
            ),
            const Divider(height: 32),
            
            // Phone Detection Sound
            _buildSoundTile(
              context,
              'Phone Detection',
              'Alert when physical phone is detected',
              phoneSound,
              () {},
            ),
            const SizedBox(height: 12),
            
            // No Face Sound
            _buildSoundTile(
              context,
              'No Face Detected',
              'Alert when face is not in frame',
              noFaceSound,
              () {},
            ),
            const SizedBox(height: 12),
            
            // Off Track Sound
            _buildSoundTile(
              context,
              'Off Track Activity',
              'Alert when looking away from screen',
              offTrackSound,
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundTile(BuildContext context, String title, String subtitle, String path, VoidCallback onTap) {
    final fileName = path.split('\\').last;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: context.textColorSecondary)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(fileName, style: const TextStyle(fontSize: 11)),
      ),
      onTap: onTap,
    );
  }
}