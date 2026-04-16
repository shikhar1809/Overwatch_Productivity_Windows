import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme_extensions.dart';
import '../../services/monitor/violation_detector.dart';

class WarningOverlay extends StatefulWidget {
  const WarningOverlay({
    super.key,
    required this.violationInfo,
    required this.onDismiss,
    this.countdownSeconds = 30,
  });

  final ViolationInfo violationInfo;
  final VoidCallback onDismiss;
  final int countdownSeconds;

  @override
  State<WarningOverlay> createState() => _WarningOverlayState();
}

class _WarningOverlayState extends State<WarningOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _countdownTimer;
  int _remainingSeconds = 30;
  double _progress = 1.0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.countdownSeconds),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onDismiss();
        }
      });

    _animationController.forward();
    _startCountdown();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
        if (widget.countdownSeconds > 0) {
          _progress = _remainingSeconds / widget.countdownSeconds;
        }
      });

      if (_remainingSeconds <= 0) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Color _getTierColor(ViolationTier tier) {
    switch (tier) {
      case ViolationTier.warning:
        return Colors.amber;
      case ViolationTier.compromised:
        return Colors.orange;
      case ViolationTier.forfeited:
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  String _getTierMessage(ViolationTier tier) {
    switch (tier) {
      case ViolationTier.warning:
        return 'Warning: Irrelevant Screen Detected';
      case ViolationTier.compromised:
        return 'Slot Compromised - Points Capped at 50%';
      case ViolationTier.forfeited:
        return 'Slot Forfeited - 0 Points';
      default:
        return 'Screen Violation';
    }
  }

  IconData _getTierIcon(ViolationTier tier) {
    switch (tier) {
      case ViolationTier.warning:
        return Icons.warning_amber;
      case ViolationTier.compromised:
        return Icons.error_outline;
      case ViolationTier.forfeited:
        return Icons.block;
      default:
        return Icons.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getTierColor(widget.violationInfo.tier);
    final isSevere = widget.violationInfo.tier != ViolationTier.warning;

    return Material(
      color: context.isDarkMode ? Colors.white.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.9),
      child: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(32),
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getTierIcon(widget.violationInfo.tier),
                  size: 80,
                  color: color,
                ),
                const SizedBox(height: 24),
                Text(
                  _getTierMessage(widget.violationInfo.tier),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.isDarkMode ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Reason:',
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.violationInfo.reasoning,
                        style: const TextStyle(
                          color: context.textColor,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (isSevere) ...[
                  Text(
                    'Return to your task immediately.',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Closing in $_remainingSeconds seconds...',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: context.isDarkMode ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: widget.onDismiss,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'I\'m back on task',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Violation #${widget.violationInfo.violationCount}',
                  style: const TextStyle(
                    color: context.textColorSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ViolationTierBadge extends StatelessWidget {
  const ViolationTierBadge({super.key, required this.tier});

  final ViolationTier tier;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (tier) {
      case ViolationTier.warning:
        color = Colors.amber;
        label = 'Warning';
        icon = Icons.warning_amber;
        break;
      case ViolationTier.compromised:
        color = Colors.orange;
        label = 'Compromised';
        icon = Icons.error_outline;
        break;
      case ViolationTier.forfeited:
        color = Colors.red;
        label = 'Forfeited';
        icon = Icons.block;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
