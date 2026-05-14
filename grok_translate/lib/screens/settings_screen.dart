import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/conversation_controller.dart';
import '../models/conversation_models.dart';
import '../widgets/language_selector.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

// Built-in xAI voice options
const _kBuiltInVoices = [
  ('eve', 'Eve', 'Female · Energetic, upbeat'),
  ('ara', 'Ara', 'Female · Warm, friendly'),
  ('rex', 'Rex', 'Male · Confident, clear'),
  ('sal', 'Sal', 'Neutral · Smooth, balanced'),
  ('leo', 'Leo', 'Male · Authoritative, strong'),
];

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late String _myLangCode;
  late String _voiceId;
  late bool _useCustomVoice;
  final _customVoiceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesServiceProvider);
    _myLangCode = prefs.getMyLanguageCode();
    _voiceId = prefs.getVoiceId();
    final isBuiltIn = _kBuiltInVoices.any((v) => v.$1 == _voiceId);
    _useCustomVoice = !isBuiltIn;
    if (_useCustomVoice) _customVoiceController.text = _voiceId;
  }

  @override
  void dispose() {
    _customVoiceController.dispose();
    super.dispose();
  }

  Future<void> _setMyLanguage(String code) async {
    final lang = kSupportedLanguages.firstWhere((l) => l.code == code);
    await ref.read(preferencesServiceProvider).setMyLanguage(code, lang.name);
    if (mounted) setState(() => _myLangCode = code);
  }

  Future<void> _setBuiltInVoice(String id) async {
    await ref.read(preferencesServiceProvider).setVoiceId(id);
    if (mounted) setState(() => _voiceId = id);
  }

  Future<void> _saveCustomVoice() async {
    final id = _customVoiceController.text.trim();
    if (id.isEmpty) return;
    await ref.read(preferencesServiceProvider).setVoiceId(id);
    if (mounted) {
      setState(() => _voiceId = id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom voice saved')),
      );
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
          // ── My Language ────────────────────────────────────────────────────
          const _SectionHeader('Language'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LanguageSelector(
                    label: 'My Language',
                    selectedCode: _myLangCode,
                    showAuto: false,
                    onChanged: _setMyLanguage,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your primary language. Used as the default source '
                    'language in auto-detect mode.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Voice ──────────────────────────────────────────────────────────
          const _SectionHeader('Translation Voice'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Built-in / custom toggle
                  Row(
                    children: [
                      Expanded(
                        child: _VoiceToggle(
                          label: 'Built-in',
                          selected: !_useCustomVoice,
                          onTap: () => setState(() => _useCustomVoice = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _VoiceToggle(
                          label: 'My Voice (cloned)',
                          selected: _useCustomVoice,
                          onTap: () => setState(() => _useCustomVoice = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (!_useCustomVoice) ...[
                    ...(_kBuiltInVoices.map((v) => RadioListTile<String>(
                          value: v.$1,
                          groupValue: _voiceId,
                          title: Text(v.$2),
                          subtitle: Text(
                            v.$3,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (id) => _setBuiltInVoice(id!),
                        ))),
                  ] else ...[
                    Text(
                      'Paste your Voice ID from the xAI console',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customVoiceController,
                            decoration: const InputDecoration(
                              hintText: 'e.g. nlbqfwie',
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _saveCustomVoice,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(64, 40)),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Record ~90 s of your voice at console.x.ai → '
                      'Voice Library → Clone Voice, then copy the Voice ID here. '
                      'The cloned voice speaks all translations in your voice.\n\n'
                      'Currently available in the US only (excluding Illinois).',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ],
              ),
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
                    'Lower = more sensitive to quiet speech. Default: 0.70',
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
                    'Time after speech stops before translation triggers. Default: 300 ms',
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
                  const _InfoRow('Audio format', 'PCM16 · 16 kHz · Mono'),
                  const _InfoRow('VAD mode', 'server_vad'),
                  const _InfoRow('Auth', 'Server-side proxy (no key on device)'),
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

class _VoiceToggle extends StatelessWidget {
  const _VoiceToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? color : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
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
