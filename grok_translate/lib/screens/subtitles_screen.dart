import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/conversation_controller.dart';
import '../models/conversation_models.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

class SubtitlesScreen extends ConsumerStatefulWidget {
  const SubtitlesScreen({super.key});

  @override
  ConsumerState<SubtitlesScreen> createState() => _SubtitlesScreenState();
}

class _SubtitlesScreenState extends ConsumerState<SubtitlesScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = ref.read(conversationControllerProvider.notifier);
      // Always ensure subtitles mode — covers direct URL loads and page refresh
      // where the setup screen's setAppMode() was never called.
      ctrl.setAppMode(AppMode.subtitles);
      ctrl.startSession();
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
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _stop() async {
    await ref.read(conversationControllerProvider.notifier).endSession();
    if (mounted) context.go(AppRouter.pathSetup);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationControllerProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    ref.listen(conversationControllerProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Mic status dot
                  _StatusDot(status: state.status),
                  const SizedBox(width: 12),
                  // Stop button
                  GestureDetector(
                    onTap: _stop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: theme.colorScheme.error
                                .withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop_circle_outlined,
                              size: 14,
                              color: theme.colorScheme.error),
                          const SizedBox(width: 6),
                          Text('Stop',
                              style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Debug status bar ─────────────────────────────────────────
            _DebugBar(state: state),
            const Divider(height: 1),

            // ── Subtitle log ─────────────────────────────────────────────
            Expanded(
              child: state.messages.isEmpty && state.partialTranscript.isEmpty
                  ? _EmptyState(status: state.status)
                  : ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        horizontal: size.width > 700 ? size.width * 0.1 : 20,
                        vertical: 24,
                      ),
                      children: [
                        ...state.messages.map(
                          (msg) => _SubtitleLine(
                            text: msg.translatedText,
                            fromLang: msg.fromLanguage,
                            toLang: msg.toLanguage,
                          ),
                        ),
                        // Streaming partial text
                        if (state.partialTranscript.isNotEmpty)
                          _PartialLine(text: state.partialTranscript),
                      ],
                    ),
            ),

            // ── Bottom waveform strip ─────────────────────────────────────
            _WaveStrip(status: state.status),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Thin diagnostic bar showing the session's internal state so that
/// screenshots make it immediately obvious where the pipeline has stalled.
class _DebugBar extends StatelessWidget {
  const _DebugBar({required this.state});
  final ConversationState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusStr = switch (state.status) {
      ConversationStatus.listening   => '🎙 listening',
      ConversationStatus.translating => '⚙ translating',
      ConversationStatus.speaking    => '🔊 speaking',
      ConversationStatus.error       => '✗ error',
      ConversationStatus.idle        => '— idle',
    };
    final conn = state.isConnected ? '✓ connected' : '✗ disconnected';
    final phrases = '${state.messages.length} phrase${state.messages.length == 1 ? '' : 's'}';
    final errPart = state.status == ConversationStatus.error && state.errorMessage != null
        ? ' | ${state.errorMessage}'
        : '';

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        '$statusStr  |  $conn  |  $phrases$errPart',
        style: theme.textTheme.labelSmall?.copyWith(
          color: state.status == ConversationStatus.error
              ? theme.colorScheme.error
              : theme.colorScheme.onSurfaceVariant,
          fontFamily: 'monospace',
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final ConversationStatus status;

  Color _color() => switch (status) {
        ConversationStatus.listening => AppTheme.listeningColor,
        ConversationStatus.translating => AppTheme.translatingColor,
        ConversationStatus.speaking => AppTheme.speakingColor,
        ConversationStatus.error => AppTheme.errorColor,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final c = _color();
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    )
        .animate(onPlay: (ctrl) => ctrl.repeat(reverse: true))
        .fade(begin: 0.4, end: 1.0, duration: 800.ms);
  }
}

class _SubtitleLine extends StatelessWidget {
  const _SubtitleLine({
    required this.text,
    required this.fromLang,
    required this.toLang,
  });
  final String text;
  final String fromLang;
  final String toLang;

  static final _boundary = RegExp(r'[.!?]\s+(?=[A-Z])');
  static String _mainPart(String t) {
    final m = _boundary.firstMatch(t);
    return m == null ? t : t.substring(0, m.start + 1).trim();
  }
  static String? _notePart(String t) {
    final m = _boundary.firstMatch(t);
    if (m == null) return null;
    final rest = t.substring(m.start + 1).trim();
    return rest.isEmpty ? null : rest;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detected source language label (small, muted)
          // Only show when we have a real language name (not a fallback string).
          if (fromLang.isNotEmpty && !fromLang.toLowerCase().contains('detected')) ...[
            Text(
              'Translated from $fromLang',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Pure translation — large and clean
          Text(
            _mainPart(text),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w300,
              height: 1.3,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (_notePart(text) != null) ...[
            const SizedBox(height: 4),
            Text(
              _notePart(text)!,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w300,
                height: 1.3,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.15, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
}

class _PartialLine extends StatelessWidget {
  const _PartialLine({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w300,
        height: 1.3,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        fontStyle: FontStyle.italic,
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
        begin: 0.5, end: 1.0, duration: 600.ms);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.status});
  final ConversationStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = status == ConversationStatus.listening;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isListening ? Icons.mic : Icons.mic_off,
            size: 48,
            color: isListening
                ? AppTheme.listeningColor
                : theme.colorScheme.outlineVariant,
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.05, 1.05),
                  duration: 1000.ms,
                  curve: Curves.easeInOut),
          const SizedBox(height: 16),
          Text(
            isListening ? 'Listening…' : 'Starting…',
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 6),
          Text(
            'Subtitles will appear here as you speak',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

class _WaveStrip extends StatelessWidget {
  const _WaveStrip({required this.status});
  final ConversationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ConversationStatus.listening => AppTheme.listeningColor,
      ConversationStatus.translating => AppTheme.translatingColor,
      _ => Theme.of(context).colorScheme.outlineVariant,
    };
    final active = status == ConversationStatus.listening;

    return Container(
      height: 48,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(18, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: AnimatedContainer(
              duration: Duration(milliseconds: active ? 300 + i * 40 : 200),
              curve: Curves.easeInOut,
              width: 3,
              height: active ? (4.0 + (i % 5) * 5.0) : 4.0,
              decoration: BoxDecoration(
                color: color.withValues(alpha: active ? 0.8 : 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
