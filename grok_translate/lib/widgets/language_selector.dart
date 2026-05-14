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
    this.showAuto = true,
  });

  final String label;
  final String selectedCode;
  final ValueChanged<String> onChanged;
  final bool enabled;
  /// When false, the 'Auto Detect' option is excluded from the list.
  /// Use this for settings that require a concrete language choice.
  final bool showAuto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final languages = showAuto
        ? kSupportedLanguages
        : kSupportedLanguages.where((l) => l.code != 'auto').toList();
    final selected = languages.firstWhere(
      (l) => l.code == selectedCode,
      orElse: () => languages.first,
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
          items: languages
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
