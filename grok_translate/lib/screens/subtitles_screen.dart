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
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  // Language badges
                  _LangPill(
                    label: state.detectedLang1 ??
                        (state.languageConfig?.autoDetect == false
                            ? state.languageConfig!.lang1Name
                            : 'Listening…'),
                    flag: state.detectedLang1Flag ?? '🎙️',
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  _LangPill(
                    label: state.detectedLang2 ??
                        (state.languageConfig?.autoDetect == false
                            ? state.languageConfig!.lang2Name
                            : 'Auto'),
                    flag: state.detectedLang2Flag ?? '💬',
                  ),
                  const Spacer(),
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

class _LangPill extends StatelessWidget {
  const _LangPill({required this.label, required this.flag});
  final String label;
  final String flag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$flag $label',
          style: theme.textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w600)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language label
          Text(
            '$fromLang → $toLang',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          // Translation text — large and clean
          Text(
            text,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w300,
              height: 1.3,
              color: theme.colorScheme.onSurface,
            ),
          ),
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
            'Translations will appear here',
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
