import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/conversation_controller.dart';
import '../models/conversation_models.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';
import '../widgets/translation_bubble.dart';
import '../widgets/waveform_indicator.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Auto-start the session when the screen mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(conversationControllerProvider.notifier).startSession();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _endSession() async {
    await ref.read(conversationControllerProvider.notifier).endSession();
    if (mounted) context.go(AppRouter.pathSetup);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationControllerProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    // Auto-scroll when new messages arrive
    ref.listen(conversationControllerProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: _LanguageBadgeRow(state: state),
        actions: [
          // Connection indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Tooltip(
              message: state.isConnected ? 'Connected' : 'Disconnected',
              child: Icon(
                state.isConnected ? Icons.wifi : Icons.wifi_off,
                color: state.isConnected ? Colors.green : theme.colorScheme.error,
                size: 20,
              ),
            ),
          ),
          // Subtitle toggle
          IconButton(
            icon: Icon(state.subtitlesEnabled
                ? Icons.closed_caption
                : Icons.closed_caption_disabled_outlined),
            tooltip:
                state.subtitlesEnabled ? 'Hide subtitles' : 'Show subtitles',
            onPressed: () => ref
                .read(conversationControllerProvider.notifier)
                .toggleSubtitles(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRouter.pathSettings),
          ),
        ],
      ),
      body: Column(
        children: [
          // Error banner
          if (state.status == ConversationStatus.error &&
              state.errorMessage != null)
            _ErrorBanner(message: state.errorMessage!),

          // Main content
          Expanded(
            child: isWide
                ? Row(
                    children: [
                      // Left: waveform + controls
                      SizedBox(
                        width: 340,
                        child: _ControlPanel(state: state, onEnd: _endSession),
                      ),
                      const VerticalDivider(width: 1),
                      // Right: subtitle log
                      Expanded(
                        child: _SubtitleLog(
                          messages: state.messages,
                          scrollController: _scrollController,
                          partialTranscript: state.partialTranscript,
                          subtitlesEnabled: state.subtitlesEnabled,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _ControlPanel(state: state, onEnd: _endSession),
                      Expanded(
                        child: _SubtitleLog(
                          messages: state.messages,
                          scrollController: _scrollController,
                          partialTranscript: state.partialTranscript,
                          subtitlesEnabled: state.subtitlesEnabled,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _LanguageBadgeRow extends StatelessWidget {
  const _LanguageBadgeRow({required this.state});
  final ConversationState state;

  @override
  Widget build(BuildContext context) {
    final cfg = state.languageConfig ?? const LanguageConfig();
    final theme = Theme.of(context);

    // Show detected language if available, otherwise show config or 'Auto'
    final lang1 = state.detectedLang1 ??
        (cfg.autoDetect ? 'Auto' : cfg.lang1Name);
    final lang1Flag = state.detectedLang1Flag ?? (cfg.autoDetect ? '🌐' : '');
    final detected1 = state.detectedLang1 != null;

    final lang2 = state.detectedLang2 ??
        (cfg.autoDetect ? 'Auto' : cfg.lang2Name);
    final lang2Flag = state.detectedLang2Flag ?? (cfg.autoDetect ? '🌐' : '');
    final detected2 = state.detectedLang2 != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LangChip(
          name: lang1Flag.isNotEmpty ? '$lang1Flag $lang1' : lang1,
          color: AppTheme.user1Color,
          detected: detected1,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.sync_alt,
              size: 16, color: theme.colorScheme.onSurfaceVariant),
        ),
        _LangChip(
          name: lang2Flag.isNotEmpty ? '$lang2Flag $lang2' : lang2,
          color: AppTheme.user2Color,
          detected: detected2,
        ),
      ],
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.name,
    required this.color,
    this.detected = false,
  });
  final String name;
  final Color color;
  final bool detected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: detected ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: color.withValues(alpha: detected ? 0.7 : 0.4),
            width: detected ? 1.5 : 1.0),
      ),
      child: Text(
        name,
        style: TextStyle(
            color: color,
            fontWeight: detected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 12),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.state, required this.onEnd});
  final ConversationState state;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Waveform indicator
          WaveformIndicator(status: state.status, size: 180),
          const SizedBox(height: 24),
          // Status badge
          StatusBadge(status: state.status),
          const SizedBox(height: 32),
          // Info row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Speak naturally – Grok detects language automatically.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          // End session button
          OutlinedButton.icon(
            onPressed: onEnd,
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('End Session'),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.6)),
              minimumSize: const Size(180, 48),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtitleLog extends StatelessWidget {
  const _SubtitleLog({
    required this.messages,
    required this.scrollController,
    required this.partialTranscript,
    required this.subtitlesEnabled,
  });

  final List<TranslationMessage> messages;
  final ScrollController scrollController;
  final String partialTranscript;
  final bool subtitlesEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!subtitlesEnabled) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.closed_caption_disabled_outlined,
                size: 48, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text('Subtitles are off',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      );
    }

    if (messages.isEmpty && partialTranscript.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 48, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Translations will appear here',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 16, bottom: 100),
      children: [
        ...messages.map((msg) => TranslationBubble(message: msg)),
        // Partial/streaming transcript
        if (partialTranscript.isNotEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              partialTranscript,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
              begin: 0.6, end: 1.0, duration: 600.ms),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: theme.colorScheme.onErrorContainer, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: theme.colorScheme.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
