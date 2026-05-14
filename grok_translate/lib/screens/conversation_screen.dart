import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/conversation_controller.dart';
import '../models/conversation_models.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/translation_bubble.dart';

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

    ref.listen(conversationControllerProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      // ── Top bar ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        title: _LanguageBadgeRow(state: state),
        actions: [
          // Connection dot
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Tooltip(
              message: state.isConnected ? 'Connected' : 'Disconnected',
              child: Icon(
                state.isConnected ? Icons.wifi : Icons.wifi_off,
                color: state.isConnected ? Colors.green : theme.colorScheme.error,
                size: 18,
              ),
            ),
          ),
          // CC toggle
          IconButton(
            icon: Icon(state.subtitlesEnabled
                ? Icons.closed_caption
                : Icons.closed_caption_disabled_outlined),
            tooltip: state.subtitlesEnabled ? 'Hide subtitles' : 'Show subtitles',
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

      // ── Full-screen message log ──────────────────────────────────────────────
      body: Column(
        children: [
          if (state.status == ConversationStatus.error &&
              state.errorMessage != null)
            _ErrorBanner(message: state.errorMessage!),
          Expanded(
            child: _MessageLog(
              messages: state.messages,
              scrollController: _scrollController,
              partialTranscript: state.partialTranscript,
              subtitlesEnabled: state.subtitlesEnabled,
              hasAudio: ref
                  .read(conversationControllerProvider.notifier)
                  .hasAudio,
              onReplayMessage: (id) => ref
                  .read(conversationControllerProvider.notifier)
                  .replayMessage(id),
            ),
          ),
        ],
      ),

      // ── Compact bottom status bar ────────────────────────────────────────────
      bottomNavigationBar: _BottomBar(
        status: state.status,
        onEnd: _endSession,
      ),
    );
  }
}

// ── Bottom status bar ──────────────────────────────────────────────────────────
// Replaces the old full-height ControlPanel. Shows a compact animated status
// indicator in the centre and the End Session button on the right.

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.status, required this.onEnd});
  final ConversationStatus status;
  final VoidCallback onEnd;

  Color _statusColor() => switch (status) {
        ConversationStatus.listening => AppTheme.listeningColor,
        ConversationStatus.translating => AppTheme.translatingColor,
        ConversationStatus.speaking => AppTheme.speakingColor,
        ConversationStatus.error => AppTheme.errorColor,
        _ => Colors.grey,
      };

  String _statusLabel() => switch (status) {
        ConversationStatus.listening => 'Listening…',
        ConversationStatus.translating => 'Translating…',
        ConversationStatus.speaking => 'Speaking…',
        ConversationStatus.error => 'Error',
        _ => 'Idle',
      };

  IconData _statusIcon() => switch (status) {
        ConversationStatus.listening => Icons.mic,
        ConversationStatus.translating => Icons.translate,
        ConversationStatus.speaking => Icons.volume_up,
        ConversationStatus.error => Icons.error_outline,
        _ => Icons.mic_off,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor();
    final isActive = status == ConversationStatus.listening ||
        status == ConversationStatus.speaking;

    return SafeArea(
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          children: [
            // ── Status indicator (centre, takes flex space) ──────────────────
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated status dot
                    _StatusDot(color: color, isActive: isActive),
                    const SizedBox(width: 8),
                    // Animated waveform bars (only when listening)
                    if (status == ConversationStatus.listening)
                      _MiniWaveform(color: color),
                    // Mic/translate/speaker icon (other states)
                    if (status != ConversationStatus.listening)
                      Icon(
                        _statusIcon(),
                        color: color,
                        size: 18,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      _statusLabel(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── End Session button (right) ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextButton.icon(
                onPressed: onEnd,
                icon: Icon(Icons.stop_circle_outlined,
                    size: 16, color: theme.colorScheme.error),
                label: Text('End',
                    style: TextStyle(
                        color: theme.colorScheme.error, fontSize: 13)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color, required this.isActive});
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    )
        .animate(onPlay: isActive ? (c) => c.repeat(reverse: true) : null)
        .fade(
          begin: isActive ? 0.4 : 1.0,
          end: 1.0,
          duration: 700.ms,
        );
  }
}

class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    const heights = [10.0, 16.0, 10.0, 18.0, 12.0];
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(heights.length, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Container(
            width: 3,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleY(
                begin: 0.3,
                end: heights[i] / 8,
                duration: Duration(milliseconds: 380 + i * 70),
                curve: Curves.easeInOut,
              ),
        );
      }),
    );
  }
}

// ── Language badges in AppBar ──────────────────────────────────────────────────

class _LanguageBadgeRow extends StatelessWidget {
  const _LanguageBadgeRow({required this.state});
  final ConversationState state;

  @override
  Widget build(BuildContext context) {
    final cfg = state.languageConfig ?? const LanguageConfig();
    final theme = Theme.of(context);

    // Show detected name if available, otherwise configured name, otherwise 'Auto'
    final lang1 = state.detectedLang1 ??
        (cfg.autoDetect ? 'Auto' : cfg.lang1Name);
    final lang1Flag =
        state.detectedLang1Flag ?? (cfg.autoDetect ? '🌐' : '');
    final detected1 = state.detectedLang1 != null;

    final lang2 = state.detectedLang2 ??
        (cfg.autoDetect ? 'Detecting…' : cfg.lang2Name);
    final lang2Flag =
        state.detectedLang2Flag ?? (cfg.autoDetect ? '🌐' : '');
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
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.sync_alt,
              size: 14, color: theme.colorScheme.onSurfaceVariant),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: detected ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: color.withValues(alpha: detected ? 0.7 : 0.4),
            width: detected ? 1.5 : 1.0),
      ),
      child: Text(
        name,
        style: TextStyle(
            color: color,
            fontWeight: detected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 11),
      ),
    );
  }
}

// ── Full-screen message log ────────────────────────────────────────────────────

class _MessageLog extends StatelessWidget {
  const _MessageLog({
    required this.messages,
    required this.scrollController,
    required this.partialTranscript,
    required this.subtitlesEnabled,
    required this.hasAudio,
    required this.onReplayMessage,
  });

  final List<TranslationMessage> messages;
  final ScrollController scrollController;
  final String partialTranscript;
  final bool subtitlesEnabled;
  final bool Function(String id) hasAudio;
  final void Function(String id) onReplayMessage;

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
                size: 40, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Translations will appear here',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              'Speak naturally — Grok translates automatically',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outlineVariant),
            ),
          ],
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        ...messages.map((msg) => TranslationBubble(
              message: msg,
              onReplay: hasAudio(msg.id) ? () => onReplayMessage(msg.id) : null,
            )),
        if (partialTranscript.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              partialTranscript,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
              begin: 0.5, end: 1.0, duration: 600.ms),
      ],
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

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
