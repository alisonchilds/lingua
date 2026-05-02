import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/conversation_controller.dart';
import '../widgets/api_key_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasApiKey = false;

  @override
  void initState() {
    super.initState();
    _checkApiKey();
  }

  void _checkApiKey() {
    final prefs = ref.read(preferencesServiceProvider);
    final key = prefs.getApiKey();
    setState(() => _hasApiKey = key != null && key.isNotEmpty);
  }

  Future<void> _editApiKey() async {
    final prefs = ref.read(preferencesServiceProvider);
    final existing = prefs.getApiKey();
    final key = await ApiKeyDialog.show(context, currentKey: existing);
    if (key != null) {
      await prefs.setApiKey(key);
      if (mounted) setState(() => _hasApiKey = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationControllerProvider);
    final controller = ref.read(conversationControllerProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // API key section
          const _SectionHeader('API Key'),
          Card(
            child: ListTile(
              leading: Icon(
                _hasApiKey ? Icons.vpn_key : Icons.vpn_key_outlined,
                color: _hasApiKey ? Colors.green : theme.colorScheme.error,
              ),
              title:
                  Text(_hasApiKey ? 'API key configured' : 'No API key set'),
              subtitle: const Text('xAI platform.x.ai'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: _editApiKey,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitles
          const _SectionHeader('Display'),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.closed_caption_outlined),
              title: const Text('Live subtitles'),
              subtitle: const Text('Show translated text in the conversation'),
              value: state.subtitlesEnabled,
              onChanged: (_) => controller.toggleSubtitles(),
            ),
          ),
          const SizedBox(height: 16),

          // VAD settings
          const _SectionHeader('Voice Detection (VAD)'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Sensitivity threshold',
                          style: theme.textTheme.bodyMedium),
                      Text(state.vadThreshold.toStringAsFixed(2),
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: state.vadThreshold,
                    min: 0.3,
                    max: 0.9,
                    divisions: 12,
                    label: state.vadThreshold.toStringAsFixed(2),
                    onChanged: controller.setVadThreshold,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lower = more sensitive to quiet speech. Default: 0.60',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Silence duration (ms)',
                          style: theme.textTheme.bodyMedium),
                      Text('${state.vadSilenceDurationMs} ms',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Slider(
                    value: state.vadSilenceDurationMs.toDouble(),
                    min: 200,
                    max: 800,
                    divisions: 12,
                    label: '${state.vadSilenceDurationMs} ms',
                    onChanged: (v) => controller.setVadSilenceDuration(v.round()),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Time after speech stops before translation triggers. Default: 400 ms',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // About
          const _SectionHeader('About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _InfoRow('App', 'Grok Translate v1.0.0'),
                  const _InfoRow('API endpoint', 'wss://api.x.ai/v1/realtime'),
                  const _InfoRow('Audio format', 'PCM16 · 24 kHz · Mono'),
                  const _InfoRow('VAD mode', 'server_vad'),
                  const SizedBox(height: 12),
                  Text(
                    'MVP limitations: echo cancellation is gating-based only. '
                    'Bluetooth per-earbud routing is out of scope. '
                    'Speaker identification is heuristic (alternating).',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
