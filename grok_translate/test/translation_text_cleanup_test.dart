import 'package:flutter_test/flutter_test.dart';
import 'package:grok_translate/utils/translation_text_cleanup.dart';

void main() {
  group('TranslationTextCleanup', () {
    test('removes duplicated sentences', () {
      expect(
        TranslationTextCleanup.deduplicateRepeatedPhrase(
          'Hello, how are you? Hello, how are you?',
        ),
        'Hello, how are you?',
      );
    });

    test('removes trailing duplicate sentence only', () {
      expect(
        TranslationTextCleanup.deduplicateRepeatedPhrase(
          'Bo Arts. Bozarts. Fine Arts. Fine Arts.',
        ),
        'Bo Arts. Bozarts. Fine Arts.',
      );
    });

    test('removes comma phrase echo', () {
      expect(
        TranslationTextCleanup.deduplicateRepeatedPhrase(
          'So, Bo Arts. So, Bo Arts.',
        ),
        'So, Bo Arts.',
      );
    });

    test('deduplicateConsecutiveEcho strips whisper echo', () {
      expect(
        TranslationTextCleanup.deduplicateConsecutiveEcho(
          'anything, Jeff? anything, Jeff?',
        ),
        'anything, Jeff?',
      );
    });

    test('appendTranscriptDelta avoids duplicate suffix', () {
      expect(
        TranslationTextCleanup.appendTranscriptDelta('So, Bo', ' Bo'),
        'So, Bo',
      );
    });

    test('appendTranscriptDelta replaces with cumulative delta', () {
      expect(
        TranslationTextCleanup.appendTranscriptDelta('So,', 'So, Bo Arts.'),
        'So, Bo Arts.',
      );
    });
  });
}
