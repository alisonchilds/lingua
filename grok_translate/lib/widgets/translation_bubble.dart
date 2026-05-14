import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/conversation_models.dart';
import '../theme/app_theme.dart';

/// A single message bubble in the translation log.
///
/// Layout (top → bottom):
///   [language pair label]  [timestamp]  [optional replay icon]
///   [original text — small, muted]          ← shown when non-empty
///   [translated text — large, prominent]
class TranslationBubble extends StatelessWidget {
  const TranslationBubble({
    super.key,
    required this.message,
    this.onReplay,
  });

  final TranslationMessage message;

  /// Called when the user taps the replay button.
  /// Null = no audio available for this message (button hidden).
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser1 = message.speaker == Speaker.user1;
    final bubbleColor = isUser1
        ? AppTheme.user1Color.withValues(alpha: 0.10)
        : AppTheme.user2Color.withValues(alpha: 0.10);
    final borderColor = isUser1 ? AppTheme.user1Color : AppTheme.user2Color;

    return Align(
      alignment: isUser1 ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser1 ? 4 : 16),
              bottomRight: Radius.circular(isUser1 ? 16 : 4),
            ),
            border: Border.all(color: borderColor.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ──────────────────────────────────────────────
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration:
                        BoxDecoration(color: borderColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    message.fromLanguage.isNotEmpty
                        ? '${message.fromLanguage} → ${message.toLanguage}'
                        : message.toLanguage,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: borderColor),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat.jm().format(message.timestamp),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  if (onReplay != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onReplay,
                      child: Icon(
                        Icons.replay_rounded,
                        size: 14,
                        color: borderColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 7),

              // ── Original text (small, muted) ─────────────────────────────
              if (message.originalText.isNotEmpty) ...[
                Text(
                  message.originalText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 5),
              ],

              // ── Translation (large, prominent) ───────────────────────────
              Text(
                message.translatedText,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w400,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .slideY(begin: 0.25, end: 0, duration: 220.ms, curve: Curves.easeOut)
        .fadeIn(duration: 180.ms);
  }
}
