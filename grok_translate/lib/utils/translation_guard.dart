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
  ];

  /// True when [output] looks like a chatbot reply rather than a translation.
  static bool looksLikeAssistantReply(String output, String originalInput) {
    final out = output.trim();
    if (out.isEmpty) return false;

    final lower = out.toLowerCase();
    for (final pattern in _assistantPhrases) {
      if (pattern.hasMatch(lower)) return true;
    }

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

  static bool languageNamesMatch(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();
}
