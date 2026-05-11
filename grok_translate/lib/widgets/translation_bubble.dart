import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/conversation_models.dart';
import '../theme/app_theme.dart';

/// A single message bubble in the subtitle/transcript list.
///
/// If the model slips in commentary after the pure translation (e.g.
/// "Good day. It's a polite German greeting..."), the bubble splits it:
/// the first sentence is shown as the main translation in normal weight,
/// and any trailing commentary is shown below in small italic muted text
/// so it is clearly secondary.
class TranslationBubble extends StatelessWidget {
  const TranslationBubble({super.key, required this.message});
  final TranslationMessage message;

  /// Returns the first sentence of [text] as the pure translation.
  static String _mainPart(String text) {
    final m = _sentenceBoundary.firstMatch(text);
    return m == null ? text : text.substring(0, m.start + 1).trim();
  }

  /// Returns everything after the first sentence, or null if nothing extra.
  static String? _notePart(String text) {
    final m = _sentenceBoundary.firstMatch(text);
    if (m == null) return null;
    final rest = text.substring(m.start + 1).trim();
    return rest.isEmpty ? null : rest;
  }

  // Matches a sentence-ending punctuation followed by a space and a capital,
  // indicating the start of a new (likely explanatory) sentence.
  static final _sentenceBoundary = RegExp(r'[.!?]\s+(?=[A-Z])');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser1 = message.speaker == Speaker.user1;
    final bubbleColor = isUser1
        ? AppTheme.user1Color.withValues(alpha: 0.12)
        : AppTheme.user2Color.withValues(alpha: 0.12);
    final borderColor =
        isUser1 ? AppTheme.user1Color : AppTheme.user2Color;

    final mainText = _mainPart(message.translatedText);
    final noteText = _notePart(message.translatedText);

    return Align(
      alignment: isUser1 ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser1 ? 4 : 16),
              bottomRight: Radius.circular(isUser1 ? 16 : 4),
            ),
            border: Border.all(color: borderColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: borderColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  // Show the language pair so attribution is always clear,
                  // regardless of whether speaker detection is accurate.
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
                ],
              ),
              const SizedBox(height: 6),
              // Pure translation — full weight
              Text(mainText, style: theme.textTheme.bodyMedium),
              // Optional model commentary — visually de-emphasised
              if (noteText != null) ...[
                const SizedBox(height: 4),
                Text(
                  noteText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    )
        .animate()
        .slideY(begin: 0.3, end: 0, duration: 250.ms, curve: Curves.easeOut)
        .fadeIn(duration: 200.ms);
  }
}
