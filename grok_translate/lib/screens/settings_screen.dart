import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/conversation_controller.dart';
import '../models/conversation_models.dart';
import '../services/voice_service.dart';
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

  // Custom voice fetch state
  final _voiceService = VoiceService();
  List<GrokVoice> _customVoices = [];
  bool _loadingVoices = false;
  String? _voiceLoadError;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(preferencesServiceProvider);
    _myLangCode = prefs.getMyLanguageCode();
    _voiceId = prefs.getVoiceId();
    _loadCustomVoices();
  }

  Future<void> _loadCustomVoices() async {
    if (!mounted) return;
    setState(() { _loadingVoices = true; _voiceLoadError = null; });
    try {
      final voices = await _voiceService.fetchCustomVoices();
      if (mounted) setState(() { _customVoices = voices; _loadingVoices = false; });
    } catch (e) {
      if (mounted) setState(() { _voiceLoadError = e.toString(); _loadingVoices = false; });
    }
  }

  Future<void> _setMyLanguage(String code) async {
    final lang = kSupportedLanguages.firstWhere((l) => l.code == code);
    await ref.read(preferencesServiceProvider).setMyLanguage(code, lang.name);
    if (mounted) setState(() => _myLangCode = code);
  }

  Future<void> _selectVoice(String id) async {
    await ref.read(preferencesServiceProvider).setVoiceId(id);
    if (mounted) setState(() => _voiceId = id);
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Built-in voices ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text('Built-in voices',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.bold)),
                ),
                ...kBuiltInVoices.map((v) => _VoiceTile(
                      voice: v,
                      selected: _voiceId == v.id,
                      onTap: () => _selectVoice(v.id),
                    )),

                // ── My Cloned Voices ──────────────────────────────────────
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('My cloned voices',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.bold)),
                      ),
                      // Refresh button
                      if (!_loadingVoices)
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          tooltip: 'Refresh',
                          onPressed: _loadCustomVoices,
                          padding: EdgeInsets.zero,
                          color: theme.colorScheme.outline,
                        ),
                    ],
                  ),
                ),
                if (_loadingVoices)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                else if (_customVoices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No cloned voices yet.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Record ~90 s at console.x.ai → Voice Library → Clone Voice. '
                          'Tap ↺ above after creating one to load it here.\n'
                          'US only (excluding Illinois).',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outlineVariant),
                        ),
                      ],
                    ),
                  )
                else ...[
                  ..._customVoices.map((v) => _VoiceTile(
                        voice: v,
                        selected: _voiceId == v.id,
                        onTap: () => _selectVoice(v.id),
                      )),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                    child: Text(
                      'Tap ↺ to refresh after adding new voices in the xAI console.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outlineVariant),
                    ),
                  ),
                ],
              ],
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
                  const _InfoRow('App', 'Babelfish v1.0.0'),
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

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.voice,
    required this.selected,
    required this.onTap,
  });
  final GrokVoice voice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Custom voice badge
            if (voice.isCustom)
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: theme.colorScheme.tertiary.withValues(alpha: 0.4)),
                ),
                child: Text('CLONE',
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.tertiary,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                        letterSpacing: 0.6)),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Icon(Icons.record_voice_over_outlined,
                    size: 18, color: theme.colorScheme.outline),
              ),
            // Name + description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(voice.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                  Text(voice.description,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
            // Selection checkmark
            if (selected)
              Icon(Icons.check_circle_rounded,
                  size: 20, color: theme.colorScheme.primary)
            else
              const SizedBox(width: 20),
          ],
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
