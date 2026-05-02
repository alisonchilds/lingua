import 'package:flutter/material.dart';

/// Dialog that prompts the user to enter their Grok API key.
/// The key is stored locally via PreferencesService.
class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({super.key, this.initialKey});
  final String? initialKey;

  static Future<String?> show(BuildContext context, {String? currentKey}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ApiKeyDialog(initialKey: currentKey),
    );
  }

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  late final TextEditingController _ctrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialKey ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Grok API Key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your xAI API key to enable real-time translation.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Get a key at platform.x.ai',
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'xai-…',
              labelText: 'API Key',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final key = _ctrl.text.trim();
            if (key.isNotEmpty) Navigator.of(context).pop(key);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
