/// Post-processing for model translation text shown in the UI.
class TranslationTextCleanup {
  TranslationTextCleanup._();

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();

  /// Collapse exact duplicate phrases the model or API sometimes echoes twice.
  static String deduplicateRepeatedPhrase(String text) {
    var t = text.trim();
    if (t.length < 4) return t;

    t = deduplicateConsecutiveEcho(t);

    final sentences = t
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (sentences.length >= 2) {
      while (sentences.length >= 2) {
        final a = _norm(sentences[sentences.length - 2]);
        final b = _norm(sentences[sentences.length - 1]);
        if (a.isNotEmpty && (a == b || b.startsWith(a))) {
          sentences.removeLast();
        } else {
          break;
        }
      }
      if (sentences.length == 1) return sentences[0];
      if (sentences.length == 2 &&
          _norm(sentences[0]) == _norm(sentences[1])) {
        return sentences[0];
      }
      t = sentences.join(' ');
    }

    if (t.length < 8) return t;

    final mid = t.length ~/ 2;
    final first = t.substring(0, mid).trim();
    final second = t.substring(mid).trim();
    if (first.isNotEmpty &&
        (first == second ||
            second.startsWith(first) ||
            _norm(first) == _norm(second))) {
      return first;
    }
    return t;
  }

  /// Remove consecutive sentence repetitions (Whisper / room echo).
  ///
  /// "anything, Jeff? anything, Jeff?" → "anything, Jeff?"
  static String deduplicateConsecutiveEcho(String text) {
    final t = text.trim();
    if (t.length < 6) return t;

    final boundary = RegExp(r'[.!?]\s+');
    final m = boundary.firstMatch(t);
    if (m == null) return t;

    final first = t.substring(0, m.end).trim();
    final rest = t.substring(m.end).trim();

    final nFirst = _norm(first);
    final nRest = _norm(rest);
    if (nRest == nFirst || nRest.startsWith(nFirst)) {
      return first;
    }
    return t;
  }

  /// Append a streaming transcript delta without doubling when the API sends
  /// the same content on multiple event channels or re-sends cumulative text.
  static String appendTranscriptDelta(String current, String delta) {
    if (delta.isEmpty) return current;
    if (current.isEmpty) return delta;
    if (current.endsWith(delta)) return current;
    if (delta.startsWith(current)) return delta;
    return current + delta;
  }
}
