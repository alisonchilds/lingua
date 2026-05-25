/// Detects and mitigates Grok "assistant mode" — conversational replies instead
/// of pure translations.
class TranslationGuard {
  TranslationGuard._();

  static final _assistantPhrases = [
    RegExp(r"how can i help", caseSensitive: false),
    RegExp(r"how may i help", caseSensitive: false),
    RegExp(r"what can i do for you", caseSensitive: false),
    RegExp(r"what would you like", caseSensitive: false),
    RegExp(r"i'?m (doing )?well", caseSensitive: false),
    RegExp(r"i am (doing )?well", caseSensitive: false),
    RegExp(r"glad you (said|asked)", caseSensitive: false),
    RegExp(r"it'?s a pleasure", caseSensitive: false),
    RegExp(r"nice to (meet|hear|talk)", caseSensitive: false),
    RegExp(r"anything else", caseSensitive: false),
    RegExp(r"let me know if", caseSensitive: false),
    RegExp(r"as an ai", caseSensitive: false),
    RegExp(r"i'?m grok", caseSensitive: false),
    RegExp(r"can you hear me", caseSensitive: false),
    RegExp(r"how about you\??\s*$", caseSensitive: false),
    RegExp(
      r"hello[!,.]?\s+how can",
      caseSensitive: false,
    ),
    RegExp(r"how are you", caseSensitive: false),
    RegExp(r"how'?s it going", caseSensitive: false),
    RegExp(r"what'?s up", caseSensitive: false),
    RegExp(r"good (morning|afternoon|evening)", caseSensitive: false),
    RegExp(r"nice to see you", caseSensitive: false),
    RegExp(r"great to (meet|hear|see)", caseSensitive: false),
  ];

  /// True when [output] should trigger one automatic strict-prompt retry.
  static bool shouldRetryStrict({
    required String output,
    required String originalInput,
    required String targetLanguage,
  }) {
    if (output.trim().isEmpty) return false;
    return looksLikeAssistantReply(output, originalInput) ||
        looksLikeMultilingualGarbage(output, targetLanguage);
  }

  /// True when [output] looks like a chatbot reply rather than a translation.
  static bool looksLikeAssistantReply(String output, String originalInput) {
    final out = output.trim();
    if (out.isEmpty) return false;

    final lower = out.toLowerCase();
    for (final pattern in _assistantPhrases) {
      if (pattern.hasMatch(lower)) return true;
    }

    if (_outputAddsGreetingChatNotInInput(lower, orig)) return true;

    // Short social input answered with a long conversational reply.
    final orig = originalInput.trim().toLowerCase();
    if (orig.length <= 40 && out.length > orig.length * 2.5) {
      const social = [
        'hello',
        'hi',
        'hey',
        'thanks',
        'thank you',
        'bonjour',
        'hola',
        'how are you',
        'ça va',
        'come va',
      ];
      if (social.any((s) => orig == s || orig.startsWith('$s '))) {
        if (lower.contains('help') ||
            lower.contains('assist') ||
            lower.contains('pleasure') ||
            lower.contains('mind')) {
          return true;
        }
      }
    }

    return false;
  }

  /// Model replied with small-talk phrases that are not in the source utterance.
  static bool _outputAddsGreetingChatNotInInput(String lowerOut, String lowerOrig) {
    const chatPhrases = [
      'how are you',
      "how's it going",
      'hows it going',
      "what's up",
      'whats up',
      'how can i help',
      'what can i do',
    ];
    for (final phrase in chatPhrases) {
      if (lowerOut.contains(phrase) && !lowerOrig.contains(phrase)) {
        return true;
      }
    }
    // Multiple questions in the output but not in the input → likely a reply, not a translation.
    final outQs = '?'.allMatches(lowerOut).length;
    final origQs = '?'.allMatches(lowerOrig).length;
    if (outQs >= 2 && outQs > origQs) return true;
    return false;
  }

  static bool languageNamesMatch(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  static final _cjk = RegExp(r'[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]');

  /// True when the model mixed multiple languages in one reply (e.g. 你好 + Bonjour).
  static bool looksLikeMultilingualGarbage(String output, String targetLanguage) {
    final text = output.trim();
    if (text.length < 8) return false;

    final target = targetLanguage.toLowerCase();
    final lower = text.toLowerCase();
    var families = 0;

    if (_cjk.hasMatch(text)) families++;
    if (RegExp(r'[a-zA-Z]').hasMatch(text)) families++;
    if (RegExp(r'\b(bonjour|salut|merci|euh|oui|non|ça)\b', caseSensitive: false)
        .hasMatch(lower)) {
      families++;
    }
    if (RegExp(r'\b(hola|gracias|sí)\b', caseSensitive: false).hasMatch(lower)) {
      families++;
    }

    if (families >= 2) return true;
    if (target.contains('english') && _cjk.hasMatch(text)) return true;
    return false;
  }
}
