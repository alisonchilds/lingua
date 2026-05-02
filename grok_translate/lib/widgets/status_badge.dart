import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/conversation_models.dart';
import '../theme/app_theme.dart';

/// Pill badge showing the current pipeline status with label.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final ConversationStatus status;

  (String, Color) _info(ConversationStatus s) => switch (s) {
        ConversationStatus.idle => ('Idle', Colors.grey),
        ConversationStatus.listening => ('Listening…', AppTheme.listeningColor),
        ConversationStatus.translating =>
          ('Translating…', AppTheme.translatingColor),
        ConversationStatus.speaking => ('Speaking…', AppTheme.speakingColor),
        ConversationStatus.error => ('Error', AppTheme.errorColor),
      };

  @override
  Widget build(BuildContext context) {
    final (label, color) = _info(status);
    final isAnimated = status == ConversationStatus.listening ||
        status == ConversationStatus.translating ||
        status == ConversationStatus.speaking;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );

    if (isAnimated) {
      badge = badge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fade(begin: 0.7, end: 1.0, duration: 800.ms);
    }

    return badge;
  }
}
