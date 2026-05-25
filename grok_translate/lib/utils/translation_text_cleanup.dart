/// Post-processing for model translation text shown in the UI.
class TranslationTextCleanup {
  TranslationTextCleanup._();

  /// Collapse exact duplicate phrases the model sometimes echoes twice.
  static String deduplicateRepeatedPhrase(String text) {
    var t = text.trim();
    if (t.length < 8) return t;

    final sentences = t.split(RegExp(r'(?<=[.!?])\s+')).map((s) => s.trim()).toList();
    if (sentences.length == 2 &&
        sentences[0].isNotEmpty &&
        sentences[0].toLowerCase() == sentences[1].toLowerCase()) {
      return sentences[0];
    }

    final mid = t.length ~/ 2;
    final first = t.substring(0, mid).trim();
    final second = t.substring(mid).trim();
    if (first.isNotEmpty &&
        (first == second ||
            second.startsWith(first) ||
            first.toLowerCase() == second.toLowerCase())) {
      return first;
    }
    return t;
  }
}
