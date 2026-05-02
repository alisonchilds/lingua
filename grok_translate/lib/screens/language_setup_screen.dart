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
  bool _hasApiKey = false;

  // On web the Cloudflare Worker holds the key — no key required from the user.
  bool get _keyRequired => !kIsWeb;

  @override
  void initState() {
    super.initState();
    _config = ref.read(conversationControllerProvider).languageConfig ??
        const LanguageConfig();
    if (_keyRequired) _checkApiKey();
  }

  Future<void> _checkApiKey() async {
    final prefs = ref.read(preferencesServiceProvider);
    final key = prefs.getApiKey();
    if (mounted) setState(() => _hasApiKey = key != null && key.isNotEmpty);
  }

  Future<void> _promptApiKey() async {
    final prefs = ref.read(preferencesServiceProvider);
    final existing = prefs.getApiKey();
    final key = await ApiKeyDialog.show(context, currentKey: existing);
    if (key != null) {
      await prefs.setApiKey(key);
      if (mounted) setState(() => _hasApiKey = true);
    }
  }

  Future<void> _startConversation() async {
    // Native only: require a key before proceeding.
    if (_keyRequired && !_hasApiKey) {
      await _promptApiKey();
      if (!_hasApiKey) return;
    }
    await ref
        .read(conversationControllerProvider.notifier)
        .setLanguageConfig(_config);
    if (mounted) context.go(AppRouter.pathConversation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 700;

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
          padding: EdgeInsets.symmetric(
              horizontal: isWide ? (width - 600) / 2 : 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero section
              _HeroSection().animate().fadeIn(duration: 400.ms).slideY(
                  begin: -0.2, end: 0, duration: 400.ms, curve: Curves.easeOut),
              const SizedBox(height: 40),

              // API key badge — shown on native only; web uses the proxy
              if (_keyRequired)
                _ApiKeyBadge(
                  hasKey: _hasApiKey,
                  onTap: _promptApiKey,
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms)
              else
                _ProxyBadge()
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 100.ms),
              const SizedBox(height: 32),

              // Auto-detect toggle
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
              ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
              const SizedBox(height: 16),

              // Language selectors (shown when auto-detect is off)
              if (!_config.autoDetect)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        LanguageSelector(
                          label: 'Language 1 (User 1)',
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
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
              const SizedBox(height: 40),

              // Start button
              FilledButton.icon(
                onPressed: _startConversation,
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text('Start Conversation'),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(
                  begin: 0.3, end: 0, duration: 400.ms, delay: 300.ms),
              const SizedBox(height: 12),

              Text(
                'Place the phone between both speakers.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.tertiary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.translate, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        Text(
          'Grok Translate',
          style: theme.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Universal real-time voice translator\npowered by Grok AI',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Shown on web — confirms the Cloudflare Worker proxy is handling auth.
class _ProxyBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Extract just the hostname for display
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
                const Text(
                  'Secure proxy active',
                  style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                ),
                Text(
                  host,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_outline,
              size: 18, color: Colors.green),
        ],
      ),
    );
  }
}

/// Shown on native — prompts the user to enter their xAI API key.
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
                  Text(
                    hasKey ? 'API key configured' : 'API key required',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
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
    return Row(
      children: [
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.swap_vert,
              color: theme.colorScheme.primary, size: 20),
        ),
        Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
      ],
    );
  }
}
