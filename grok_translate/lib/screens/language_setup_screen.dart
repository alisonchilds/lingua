import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/conversation_controller.dart';
import '../models/conversation_models.dart';
import '../router/app_router.dart';
import '../services/grok_api_service.dart';
import '../widgets/api_key_dialog.dart';
import '../widgets/language_selector.dart';

class LanguageSetupScreen extends ConsumerStatefulWidget {
  const LanguageSetupScreen({super.key});

  @override
  ConsumerState<LanguageSetupScreen> createState() =>
      _LanguageSetupScreenState();
}

class _LanguageSetupScreenState extends ConsumerState<LanguageSetupScreen> {
  late LanguageConfig _config;
  late AppMode _mode;
  bool _hasApiKey = false;

  bool get _keyRequired => !kIsWeb;

  @override
  void initState() {
    super.initState();
    final s = ref.read(conversationControllerProvider);
    _config = s.languageConfig ?? const LanguageConfig();
    _mode = s.appMode;
    if (_keyRequired) _checkApiKey();
  }

  Future<void> _checkApiKey() async {
    final key = ref.read(preferencesServiceProvider).getApiKey();
    if (mounted) setState(() => _hasApiKey = key != null && key.isNotEmpty);
  }

  Future<void> _promptApiKey() async {
    final prefs = ref.read(preferencesServiceProvider);
    final key = await ApiKeyDialog.show(context, currentKey: prefs.getApiKey());
    if (key != null) {
      await prefs.setApiKey(key);
      if (mounted) setState(() => _hasApiKey = true);
    }
  }

  Future<void> _start() async {
    if (_keyRequired && !_hasApiKey) {
      await _promptApiKey();
      if (!_hasApiKey) return;
    }
    final ctrl = ref.read(conversationControllerProvider.notifier);
    await ctrl.setLanguageConfig(_config);
    ctrl.setAppMode(_mode);
    if (!mounted) return;
    if (_mode == AppMode.subtitles) {
      context.go(AppRouter.pathSubtitles);
    } else {
      context.go(AppRouter.pathConversation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 700;
    final pad = isWide ? (width - 600) / 2.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Text('Grok Translate'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRouter.pathSettings),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.symmetric(horizontal: pad, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeroSection()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.15, end: 0, duration: 400.ms),
              const SizedBox(height: 32),

              // ── Mode selector ──────────────────────────────────────────
              _ModePicker(
                selected: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ).animate().fadeIn(duration: 400.ms, delay: 80.ms),
              const SizedBox(height: 24),

              // ── API key / proxy badge ──────────────────────────────────
              if (_keyRequired)
                _ApiKeyBadge(hasKey: _hasApiKey, onTap: _promptApiKey)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 120.ms)
              else
                _ProxyBadge()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 120.ms),
              const SizedBox(height: 24),

              // ── Auto-detect toggle ─────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SwitchListTile(
                    title: const Text('Auto-detect languages'),
                    subtitle: const Text(
                        'Grok detects and switches languages automatically'),
                    value: _config.autoDetect,
                    onChanged: (v) =>
                        setState(() => _config = _config.copyWith(autoDetect: v)),
                  ),
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 160.ms),
              const SizedBox(height: 12),

              // ── Language pickers ───────────────────────────────────────
              if (!_config.autoDetect)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        LanguageSelector(
                          label: _mode == AppMode.subtitles
                              ? 'Spoken language'
                              : 'Language 1 (User 1)',
                          selectedCode: _config.lang1Code,
                          onChanged: (code) {
                            final lang = kSupportedLanguages
                                .firstWhere((l) => l.code == code);
                            setState(() => _config = _config.copyWith(
                                  lang1Code: code,
                                  lang1Name: lang.name,
                                  autoDetect: false,
                                ));
                          },
                        ),
                        if (_mode == AppMode.translator) ...[
                          const SizedBox(height: 20),
                          const _SwapDivider(),
                          const SizedBox(height: 20),
                          LanguageSelector(
                            label: 'Language 2 (User 2)',
                            selectedCode: _config.lang2Code,
                            onChanged: (code) {
                              final lang = kSupportedLanguages
                                  .firstWhere((l) => l.code == code);
                              setState(() => _config = _config.copyWith(
                                    lang2Code: code,
                                    lang2Name: lang.name,
                                    autoDetect: false,
                                  ));
                            },
                          ),
                        ] else ...[
                          const SizedBox(height: 20),
                          const _ArrowDivider(),
                          const SizedBox(height: 20),
                          LanguageSelector(
                            label: 'Translate into',
                            selectedCode: _config.lang2Code,
                            onChanged: (code) {
                              final lang = kSupportedLanguages
                                  .firstWhere((l) => l.code == code);
                              setState(() => _config = _config.copyWith(
                                    lang2Code: code,
                                    lang2Name: lang.name,
                                    autoDetect: false,
                                  ));
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
              const SizedBox(height: 36),

              // ── CTA ────────────────────────────────────────────────────
              FilledButton.icon(
                onPressed: _start,
                icon: Icon(
                  _mode == AppMode.subtitles
                      ? Icons.closed_caption_outlined
                      : Icons.play_arrow_rounded,
                  size: 24,
                ),
                label: Text(_mode == AppMode.subtitles
                    ? 'Start Subtitles'
                    : 'Start Conversation'),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 280.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, delay: 280.ms),
              const SizedBox(height: 12),
              Text(
                _mode == AppMode.subtitles
                    ? 'Speak and see translations appear in real time.'
                    : 'Place the phone between both speakers.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ).animate().fadeIn(duration: 400.ms, delay: 340.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.selected, required this.onChanged});
  final AppMode selected;
  final ValueChanged<AppMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeCard(
            mode: AppMode.translator,
            selected: selected == AppMode.translator,
            icon: Icons.translate,
            title: 'Translator',
            subtitle: 'Two-person voice\ntranslation',
            onTap: () => onChanged(AppMode.translator),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ModeCard(
            mode: AppMode.subtitles,
            selected: selected == AppMode.subtitles,
            icon: Icons.closed_caption_outlined,
            title: 'Subtitles',
            subtitle: 'Live text translation\non screen',
            onTap: () => onChanged(AppMode.subtitles),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final AppMode mode;
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                color: selected ? color : theme.colorScheme.onSurfaceVariant,
                size: 28),
            const SizedBox(height: 10),
            Text(title,
                style: theme.textTheme.titleSmall?.copyWith(
                    color: selected ? color : null,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.translate, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        Text('Grok Translate',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Real-time voice translation powered by Grok AI',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _ProxyBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final host = Uri.parse(GrokApiService.kProxyUrl).host;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Secure proxy active',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                Text(host,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
        ],
      ),
    );
  }
}

class _ApiKeyBadge extends StatelessWidget {
  const _ApiKeyBadge({required this.hasKey, required this.onTap});
  final bool hasKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = hasKey ? Colors.green : theme.colorScheme.error;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(hasKey ? Icons.vpn_key : Icons.vpn_key_outlined,
                color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasKey ? 'API key configured' : 'API key required',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    hasKey
                        ? 'Tap to change your xAI API key'
                        : 'Tap to enter your xAI API key',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

class _SwapDivider extends StatelessWidget {
  const _SwapDivider();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child:
            Icon(Icons.swap_vert, color: theme.colorScheme.primary, size: 20),
      ),
      Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
    ]);
  }
}

class _ArrowDivider extends StatelessWidget {
  const _ArrowDivider();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Icon(Icons.arrow_downward,
            color: theme.colorScheme.primary, size: 20),
      ),
      Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
    ]);
  }
}
