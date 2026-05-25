/// Heuristic language detection from transcript text when Whisper metadata is wrong.
class TranscriptLanguageHint {
  TranscriptLanguageHint._();

  static final _hints = <_Hint>[
    _Hint('de', RegExp(
      r'\b(gutentag|guten\s*tag|guten\s*morgen|guten\s*abend|guten\s*nacht|'
      r'wie\s*geht|wie\s*gehts|hallo|danke|bitte|tschüss|auf\s*wiedersehen|'
      r'entschuldigung|sprechen\s*sie)\b',
      caseSensitive: false,
    )),
    _Hint('fr', RegExp(
      r'\b(bonjour|bonsoir|salut|merci|s il vous plaît|comment allez|'
      r'ça va|comment ça va|au revoir|excusez)\b',
      caseSensitive: false,
    )),
    _Hint('es', RegExp(
      r'\b(hola|buenos días|buenas tardes|gracias|por favor|'
      r'cómo estás|como estas|adiós|disculpe)\b',
      caseSensitive: false,
    )),
    _Hint('it', RegExp(
      r'\b(ciao|buongiorno|buonasera|grazie|prego|come stai|arrivederci)\b',
      caseSensitive: false,
    )),
    _Hint('pt', RegExp(
      r'\b(olá|ola|bom dia|boa tarde|obrigad[oa]|por favor|como vai|tchau)\b',
      caseSensitive: false,
    )),
  ];

  /// ISO-639-1 code if the transcript strongly suggests a non-English language.
  static String? inferIsoCode(String transcript) {
    final t = transcript.trim();
    if (t.length < 3) return null;
    for (final hint in _hints) {
      if (hint.pattern.hasMatch(t)) return hint.code;
    }
    return null;
  }
}

class _Hint {
  const _Hint(this.code, this.pattern);
  final String code;
  final RegExp pattern;
}
