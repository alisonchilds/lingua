import '../models/conversation_models.dart';
import 'transcript_language_hint.dart';

/// Fixes common Whisper mis-transcriptions before translation and display.
class TranscriptCorrection {
  TranscriptCorrection._();

  /// "Bo Arts", "Bose Arts", "Bozarts" → French [beaux arts].
  static final _beauxArtsMishear = RegExp(
    r'\b(beau|bo|bow|bose)\s*arts?\b|\bbozarts?\b',
    caseSensitive: false,
  );

  static bool sessionIncludesFrench({
    LanguageConfig? cfg,
    String? detectedLang1,
    String? detectedLang2,
  }) {
    if (cfg != null) {
      if (cfg.lang1Code == 'fr' || cfg.lang2Code == 'fr') return true;
      if (_nameIsFrench(cfg.lang1Name) || _nameIsFrench(cfg.lang2Name)) {
        return true;
      }
    }
    if (_nameIsFrench(detectedLang1) || _nameIsFrench(detectedLang2)) {
      return true;
    }
    return false;
  }

  static bool _nameIsFrench(String? name) =>
      name != null && name.toLowerCase().contains('french');

  /// Normalize misheard French phrases when French is in play or text matches.
  static String correct(
    String transcript, {
    LanguageConfig? languageConfig,
    String? detectedLang1,
    String? detectedLang2,
  }) {
    var t = transcript.trim();
    if (t.isEmpty) return t;

    final frenchLikely = sessionIncludesFrench(
          languageConfig: languageConfig,
          detectedLang1: detectedLang1,
          detectedLang2: detectedLang2,
        ) ||
        TranscriptLanguageHint.inferIsoCode(t) == 'fr' ||
        _beauxArtsMishear.hasMatch(t);

    if (!frenchLikely) return t;

    t = t.replaceAllMapped(_beauxArtsMishear, (_) => 'beaux arts');
    return t;
  }
}
