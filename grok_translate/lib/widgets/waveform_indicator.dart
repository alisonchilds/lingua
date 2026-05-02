import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/conversation_models.dart';
import '../theme/app_theme.dart';

/// Animated waveform / mic indicator that reflects the current conversation status.
class WaveformIndicator extends StatelessWidget {
  const WaveformIndicator({
    super.key,
    required this.status,
    this.size = 160,
  });

  final ConversationStatus status;
  final double size;

  Color _colorForStatus(ConversationStatus s) => switch (s) {
        ConversationStatus.listening => AppTheme.listeningColor,
        ConversationStatus.translating => AppTheme.translatingColor,
        ConversationStatus.speaking => AppTheme.speakingColor,
        ConversationStatus.error => AppTheme.errorColor,
        _ => Colors.grey,
      };

  IconData _iconForStatus(ConversationStatus s) => switch (s) {
        ConversationStatus.listening => Icons.mic,
        ConversationStatus.translating => Icons.translate,
        ConversationStatus.speaking => Icons.volume_up,
        ConversationStatus.error => Icons.error_outline,
        _ => Icons.mic_off,
      };

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(status);
    final icon = _iconForStatus(status);
    final isActive = status == ConversationStatus.listening ||
        status == ConversationStatus.speaking;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing rings when active
          if (isActive) ...[
            _PulseRing(color: color, size: size, delay: 0.ms),
            _PulseRing(color: color, size: size * 0.8, delay: 300.ms),
          ],
          // Inner waveform bars when listening
          if (status == ConversationStatus.listening)
            _WaveformBars(color: color, width: size * 0.55),
          // Main circle
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(icon, color: color, size: size * 0.22),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  const _PulseRing(
      {required this.color, required this.size, required this.delay});
  final Color color;
  final double size;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.1, 1.1),
            duration: 1200.ms,
            delay: delay,
            curve: Curves.easeInOut)
        .fade(begin: 0.7, end: 0, duration: 1200.ms, delay: delay);
  }
}

class _WaveformBars extends StatelessWidget {
  const _WaveformBars({required this.color, required this.width});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    const barCount = 7;
    final random = Random(42);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(barCount, (i) {
        final targetHeight = 4.0 + random.nextDouble() * 20;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(width: 4, height: 8, color: color)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleY(
                begin: 0.3,
                end: targetHeight / 8,
                duration: Duration(milliseconds: 400 + i * 80),
                curve: Curves.easeInOut,
              ),
        );
      }),
    );
  }
}
