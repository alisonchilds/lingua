import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/conversation_models.dart';
import '../theme/app_theme.dart';

/// White card bubble matching the Babelfish design:
///
///   French > English                            4:42 PM  ▷
///   Oui, ça va. Et vous?           ← italic grey (original)
///   Yeah, I'm good. How about you? ← large dark (translation)
class TranslationBubble extends StatelessWidget {
  const TranslationBubble({
    super.key,
    required this.message,
    this.onReplay,
  });

  final TranslationMessage message;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final langLabel = message.fromLanguage.isNotEmpty
        ? '${message.fromLanguage} > ${message.toLanguage}'
        : message.toLanguage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ────────────────────────────────────────────────
            Row(
              children: [
                Text(
                  langLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFF888888),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat.jm().format(message.timestamp),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: const Color(0xFF888888)),
                ),
                if (onReplay != null) ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onReplay,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.cream,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          size: 16, color: Color(0xFF555555)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // ── Original text (small italic grey) ─────────────────────────
            if (message.originalText.isNotEmpty) ...[
              Text(
                message.originalText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF888888),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 5),
            ],

            // ── Translation (large, prominent) ───────────────────────────
            Text(
              message.translatedText,
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .slideY(begin: 0.2, end: 0, duration: 220.ms, curve: Curves.easeOut)
        .fadeIn(duration: 200.ms);
  }
}
