import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/conversation_models.dart';
import '../theme/app_theme.dart';

/// A single message bubble in the subtitle/transcript list.
class TranslationBubble extends StatelessWidget {
  const TranslationBubble({super.key, required this.message});
  final TranslationMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser1 = message.speaker == Speaker.user1;
    final bubbleColor = isUser1
        ? AppTheme.user1Color.withValues(alpha: 0.12)
        : AppTheme.user2Color.withValues(alpha: 0.12);
    final borderColor =
        isUser1 ? AppTheme.user1Color : AppTheme.user2Color;

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
                  Text(
                    '${isUser1 ? 'User 1' : 'User 2'} · ${message.toLanguage}',
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
              Text(
                message.translatedText,
                style: theme.textTheme.bodyMedium,
              ),
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
