import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/conversation_controller.dart';
import '../models/conversation_models.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import '../widgets/language_selector.dart';
import '../widgets/translation_bubble.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key});

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scrollController = ScrollController();
  // 0 = Translate, 1 = Subtitles, 2 = History, 3 = Discover
  int _currentTab = 0;

  // Test input
  final _testInputController = TextEditingController();
  bool _showTestInput = false;

  @override
  void initState() {
    super.initState();
    // Session starts only when the user taps the Listen circle — not automatically.
  }

  void _startSession() {
    ref.read(conversationControllerProvider.notifier).startSession();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _testInputController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _endSession() async {
    await ref.read(conversationControllerProvider.notifier).endSession();
    // Return to the idle circle — user taps it again to restart.
  }

  /// Called when the user taps a bottom-nav tab.
  /// Ends any active session and switches the app mode to match the new tab.
  Future<void> _onTabChanged(int index) async {
    if (index == _currentTab) return;
    final notifier = ref.read(conversationControllerProvider.notifier);
    final isActive =
        ref.read(conversationControllerProvider).isSessionActive;
    if (isActive) await notifier.endSession();

    if (index == 0) notifier.setAppMode(AppMode.translator);
    if (index == 1) notifier.setAppMode(AppMode.subtitles);

    setState(() => _currentTab = index);
  }

  void _submitTestInput() {
    final text = _testInputController.text.trim();
    if (text.isEmpty) return;
    ref.read(conversationControllerProvider.notifier).translateText(text);
    _testInputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationControllerProvider);

    ref.listen(conversationControllerProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: _BabelfishAppBar(
        state: state,
        onSettings: () => context.push(AppRouter.pathSettings),
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          // ── Tab 0: Translate ─────────────────────────────────────────────
          _TranslateTab(
            state: state,
            scrollController: _scrollController,
            showTestInput: _showTestInput,
            testInputController: _testInputController,
            onToggleTest: () => setState(() => _showTestInput = !_showTestInput),
            onSubmitTest: _submitTestInput,
            onStart: _startSession,
            onEnd: _endSession,
            hasAudio: ref.read(conversationControllerProvider.notifier).hasAudio,
            onReplay: (id) => ref
                .read(conversationControllerProvider.notifier)
                .replayMessage(id),
          ),
          // ── Tab 1: Subtitles ──────────────────────────────────────────────
          _SubtitlesTab(
            state: state,
            scrollController: _scrollController,
            onStart: _startSession,
            onEnd: _endSession,
          ),
          // ── Tab 2: History ────────────────────────────────────────────────
          const _PlaceholderTab(
            icon: Icons.history_rounded,
            label: 'History coming soon',
          ),
          // ── Tab 3: Discover ───────────────────────────────────────────────
          const _PlaceholderTab(
            icon: Icons.language_rounded,
            label: 'Discover coming soon',
          ),
        ],
      ),
      bottomNavigationBar: _BabelfishBottomNav(
        currentIndex: _currentTab,
        onTap: _onTabChanged,
      ),
    );
  }
}

// ── App bar ────────────────────────────────────────────────────────────────────

class _BabelfishAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _BabelfishAppBar({required this.state, required this.onSettings});
  final ConversationState state;
  final VoidCallback onSettings;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.dark,
      leading: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fish logo
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.magenta,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('🐟', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Babelfish',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      leadingWidth: 160,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
          onPressed: onSettings,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Translate tab ──────────────────────────────────────────────────────────────

class _TranslateTab extends StatelessWidget {
  const _TranslateTab({
    required this.state,
    required this.scrollController,
    required this.showTestInput,
    required this.testInputController,
    required this.onToggleTest,
    required this.onSubmitTest,
    required this.onStart,
    required this.onEnd,
    required this.hasAudio,
    required this.onReplay,
  });

  final ConversationState state;
  final ScrollController scrollController;
  final bool showTestInput;
  final TextEditingController testInputController;
  final VoidCallback? onToggleTest;
  final VoidCallback onSubmitTest;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final bool Function(String id) hasAudio;
  final void Function(String id) onReplay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Language pill selector ─────────────────────────────────────────
        _LanguagePills(state: state),

        // ── Error banner ───────────────────────────────────────────────────
        if (state.status == ConversationStatus.error &&
            state.errorMessage != null)
          _ErrorBanner(message: state.errorMessage!),

        if (state.isSessionActive && !state.isConnected)
          const _ReconnectBanner(),

        Expanded(
          child: state.messages.isEmpty &&
                  (!_showLiveText(state) || state.partialTranscript.isEmpty)
              ? _ListenEmptyState(
                  status: state.status,
                  isSessionActive: state.isSessionActive,
                  onStart: onStart,
                )
              : _MessageList(
                  messages: state.messages,
                  scrollController: scrollController,
                  partialTranscript:
                      _showLiveText(state) ? state.partialTranscript : '',
                  showTranslationText: _showLiveText(state),
                  hasAudio: hasAudio,
                  onReplay: onReplay,
                ),
        ),

        if (kDebugMode && showTestInput)
          _TestInputBar(
            controller: testInputController,
            onSubmit: onSubmitTest,
            isActive: state.isSessionActive,
          ),

        _StatusBar(
          status: state.status,
          isSessionActive: state.isSessionActive,
          onEnd: onEnd,
          onToggleTest: kDebugMode ? onToggleTest : null,
          showTestInput: showTestInput,
        ),
      ],
    );
  }

  static bool _showLiveText(ConversationState state) => state.subtitlesEnabled;
}

// ── Language pills ─────────────────────────────────────────────────────────────

class _LanguagePills extends ConsumerWidget {
  const _LanguagePills({required this.state});
  final ConversationState state;

  void _pick(BuildContext context, WidgetRef ref, {required bool isLeft}) {
    final cfg = state.languageConfig ?? const LanguageConfig();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LanguagePickerSheet(
        title: isLeft ? 'My Language' : 'Partner\'s Language',
        selectedCode: isLeft ? cfg.lang1Code : cfg.lang2Code,
        onSelect: (lang) {
          Navigator.of(context).pop();
          final notifier = ref.read(conversationControllerProvider.notifier);
          final newCfg = isLeft
              ? cfg.copyWith(
                  lang1Code: lang.code,
                  lang1Name: lang.name,
                  autoDetect: cfg.lang2Code == 'auto',
                )
              : cfg.copyWith(
                  lang2Code: lang.code,
                  lang2Name: lang.name,
                  autoDetect: lang.code == 'auto',
                );
          notifier.setLanguageConfig(newCfg);
          // Also persist as myLanguage when the user updates the left pill
          if (isLeft && lang.code != 'auto') {
            ref.read(preferencesServiceProvider).setMyLanguage(lang.code, lang.name);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfg = state.languageConfig ?? const LanguageConfig();

    final myLang = ref.read(preferencesServiceProvider).getMyLanguageName();
    final lang1 = cfg.lang1Name == 'Auto Detect' ? myLang : cfg.lang1Name;
    final lang2 = state.detectedLang2 ??
        (cfg.autoDetect ? 'Auto' : cfg.lang2Name);

    return Container(
      color: AppTheme.dark,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Pill(
            label: lang1,
            onTap: () => _pick(context, ref, isLeft: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.swap_horiz_rounded,
                color: Colors.white.withValues(alpha: 0.7), size: 20),
          ),
          _Pill(
            label: lang2,
            onTap: () => _pick(context, ref, isLeft: false),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Language picker sheet ──────────────────────────────────────────────────────

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({
    required this.title,
    required this.selectedCode,
    required this.onSelect,
  });
  final String title;
  final String selectedCode;
  final void Function(SupportedLanguage lang) onSelect;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = kSupportedLanguages
        .where((l) =>
            l.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(widget.title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search language…',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          // Language list
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final lang = filtered[i];
                final selected = lang.code == widget.selectedCode;
                return ListTile(
                  leading: Text(lang.flag,
                      style: const TextStyle(fontSize: 22)),
                  title: Text(lang.name,
                      style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400)),
                  trailing: selected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppTheme.magenta)
                      : null,
                  onTap: () => widget.onSelect(lang),
                  dense: true,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Empty "Listen" state ───────────────────────────────────────────────────────

class _ListenEmptyState extends StatelessWidget {
  const _ListenEmptyState({
    required this.status,
    required this.isSessionActive,
    required this.onStart,
  });
  final ConversationStatus status;
  final bool isSessionActive;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final isListening = status == ConversationStatus.listening;
    final isStarting = isSessionActive && !isListening;

    // Label below the circle
    final label = !isSessionActive
        ? 'Tap to listen'
        : isListening
            ? 'Listening…'
            : 'Starting…';

    // The circle pulses only when actively listening
    Widget circle = Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        color: isSessionActive ? AppTheme.magenta : const Color(0xFFDDDDDD),
        shape: BoxShape.circle,
        boxShadow: isSessionActive
            ? [
                BoxShadow(
                  color: AppTheme.magenta.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ]
            : [],
      ),
      child: Icon(
        isSessionActive ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
        color: Colors.white,
        size: 54,
      ),
    );

    if (isListening) {
      circle = circle
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.07, 1.07),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: isSessionActive ? null : onStart,
            child: circle,
          ),
          const SizedBox(height: 22),
          Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isSessionActive
                  ? AppTheme.magenta
                  : const Color(0xFF888888),
            ),
          ),
          if (!isSessionActive) ...[
            const SizedBox(height: 8),
            const Text(
              'Tap the circle to start',
              style: TextStyle(fontSize: 14, color: Color(0xFFAAAAAA)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Message list ───────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.scrollController,
    required this.partialTranscript,
    required this.showTranslationText,
    required this.hasAudio,
    required this.onReplay,
  });

  final List<TranslationMessage> messages;
  final ScrollController scrollController;
  final String partialTranscript;
  final bool showTranslationText;
  final bool Function(String id) hasAudio;
  final void Function(String id) onReplay;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      children: [
        ...messages.map((msg) => TranslationBubble(
              message: msg,
              showTranslationText: showTranslationText,
              onReplay: hasAudio(msg.id) ? () => onReplay(msg.id) : null,
            )),
        if (partialTranscript.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              partialTranscript,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
              begin: 0.4, end: 1.0, duration: 600.ms),
      ],
    );
  }
}

// ── Status + control bar ───────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.status,
    required this.isSessionActive,
    required this.onEnd,
    required this.onToggleTest,
    required this.showTestInput,
  });

  final ConversationStatus status;
  final bool isSessionActive;
  final VoidCallback onEnd;
  final VoidCallback? onToggleTest;
  final bool showTestInput;

  String _statusLabel() => switch (status) {
        ConversationStatus.listening => 'Listening...',
        ConversationStatus.translating => 'Translating...',
        ConversationStatus.speaking => 'Speaking...',
        ConversationStatus.error => 'Error',
        _ => 'Starting...',
      };

  @override
  Widget build(BuildContext context) {
    if (!isSessionActive) return const SizedBox.shrink();

    return Container(
      color: AppTheme.cream,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          // Test input toggle (small keyboard icon)
          if (onToggleTest != null)
            GestureDetector(
              onTap: onToggleTest,
              child: Icon(
                showTestInput
                    ? Icons.keyboard_hide_outlined
                    : Icons.keyboard_outlined,
                size: 20,
                color: showTestInput
                    ? AppTheme.magenta
                    : const Color(0xFFAAAAAA),
              ),
            )
          else
            const SizedBox(width: 20),
          Expanded(
            child: Center(
              child: Text(
                _statusLabel(),
                style: TextStyle(
                  color: status == ConversationStatus.error
                      ? AppTheme.errorColor
                      : AppTheme.magenta,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          // End button
          GestureDetector(
            onTap: onEnd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: AppTheme.redEnd,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'End',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Test input bar ─────────────────────────────────────────────────────────────

class _TestInputBar extends StatelessWidget {
  const _TestInputBar({
    required this.controller,
    required this.onSubmit,
    required this.isActive,
  });
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.magenta.withValues(alpha: 0.08),
        border: Border(
          top: BorderSide(color: AppTheme.magenta.withValues(alpha: 0.3)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.magenta.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: AppTheme.magenta.withValues(alpha: 0.4)),
            ),
            child: const Text('TEST',
                style: TextStyle(
                    color: AppTheme.magenta,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 0.8)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: isActive,
              decoration: const InputDecoration(
                hintText: 'Type text to translate…',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20))),
              ),
              style: const TextStyle(fontSize: 13),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded),
            iconSize: 20,
            color: AppTheme.magenta,
            onPressed: isActive ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}

// ── Error banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.errorColor.withValues(alpha: 0.1),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.magenta.withValues(alpha: 0.12),
      child: const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.magenta,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Reconnecting to the translation server…',
              style: TextStyle(color: AppTheme.magenta, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom navigation bar ──────────────────────────────────────────────────────

class _BabelfishBottomNav extends StatelessWidget {
  const _BabelfishBottomNav({
    required this.currentIndex,
    required this.onTap,
  });
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.dark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.translate_rounded,
                label: 'Translate',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.closed_caption_outlined,
                label: 'Subtitles',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.history_rounded,
                label: 'History',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.language_rounded,
                label: 'Discover',
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.4);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              )
            else
              Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Subtitles tab ──────────────────────────────────────────────────────────────

class _SubtitlesTab extends StatelessWidget {
  const _SubtitlesTab({
    required this.state,
    required this.scrollController,
    required this.onStart,
    required this.onEnd,
  });

  final ConversationState state;
  final ScrollController scrollController;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = state.status == ConversationStatus.listening;

    return Column(
      children: [
        if (state.isSessionActive && !state.isConnected)
          const _ReconnectBanner(),
        Expanded(
          child: state.messages.isEmpty && state.partialTranscript.isEmpty
              ? _ListenEmptyState(
                  status: state.status,
                  isSessionActive: state.isSessionActive,
                  onStart: onStart,
                )
              : ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  children: [
                    ...state.messages.map((msg) => Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (msg.fromLanguage.isNotEmpty &&
                                  !msg.fromLanguage
                                      .toLowerCase()
                                      .contains('detected') &&
                                  msg.fromLanguage != 'auto-detect') ...[
                                Text(
                                  'From ${msg.fromLanguage}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF999999),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              // Original text (small italic)
                              if (msg.originalText.isNotEmpty) ...[
                                Text(
                                  msg.originalText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF888888),
                                    fontStyle: FontStyle.italic,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              // Translation (large)
                              Text(
                                msg.translatedText,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w300,
                                  height: 1.3,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        )),
                    // Streaming partial
                    if (state.partialTranscript.isNotEmpty)
                      Text(
                        state.partialTranscript,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w300,
                          height: 1.3,
                          color: const Color(0xFF1A1A1A).withValues(alpha: 0.35),
                          fontStyle: FontStyle.italic,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fade(begin: 0.4, end: 1.0, duration: 700.ms),
                  ],
                ),
        ),

        // ── Slim bottom bar ───────────────────────────────────────────────────
        if (state.isSessionActive)
          Container(
            color: AppTheme.cream,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              children: [
                // Listening indicator dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isListening
                        ? AppTheme.magenta
                        : const Color(0xFFCCCCCC),
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(
                        onPlay:
                            isListening ? (c) => c.repeat(reverse: true) : null)
                    .fade(begin: 0.3, end: 1.0, duration: 600.ms),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isListening ? 'Listening for speech…' : 'Translating…',
                    style: TextStyle(
                      color: AppTheme.magenta,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onEnd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.redEnd,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text('End',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Placeholder tabs ───────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFFCCCCCC)),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 16)),
        ],
      ),
    );
  }
}
