import 'package:flutter_test/flutter_test.dart';
import 'package:grok_translate/models/conversation_models.dart';
import 'package:grok_translate/utils/transcript_correction.dart';

void main() {
  group('TranscriptCorrection', () {
    test('fixes Bo Arts when French is in language pair', () {
      const cfg = LanguageConfig(
        lang1Code: 'en',
        lang2Code: 'fr',
        lang1Name: 'English',
        lang2Name: 'French',
        autoDetect: false,
      );
      expect(
        TranscriptCorrection.correct(
          'So, Bo Arts.',
          languageConfig: cfg,
        ),
        'So, beaux arts.',
      );
    });

    test('fixes Bozarts mishearing', () {
      expect(
        TranscriptCorrection.correct(
          'Bo Arts. Bozarts.',
          languageConfig: const LanguageConfig(
            lang1Name: 'English',
            lang2Name: 'French',
            lang1Code: 'en',
            lang2Code: 'fr',
            autoDetect: false,
          ),
        ),
        'beaux arts. beaux arts.',
      );
    });
  });
}
