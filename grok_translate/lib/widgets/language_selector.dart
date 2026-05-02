import 'package:flutter/material.dart';
import '../models/conversation_models.dart';

/// Dropdown selector for a single language slot.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    super.key,
    required this.label,
    required this.selectedCode,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final String selectedCode;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = kSupportedLanguages.firstWhere(
      (l) => l.code == selectedCode,
      orElse: () => kSupportedLanguages.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selected.code,
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          isExpanded: true,
          items: kSupportedLanguages
              .map((lang) => DropdownMenuItem(
                    value: lang.code,
                    child: Row(
                      children: [
                        Text(lang.flag, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Text(lang.name),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: enabled ? (v) => onChanged(v!) : null,
        ),
      ],
    );
  }
}
