import 'package:flutter_test/flutter_test.dart';
import 'package:grok_translate/utils/transcript_language_hint.dart';

void main() {
  group('TranscriptLanguageHint', () {
    test('detects German phrases and common misspellings', () {
      expect(TranscriptLanguageHint.inferIsoCode('Gutentag'), 'de');
      expect(TranscriptLanguageHint.inferIsoCode('Guten Tag Wie Gehts'), 'de');
      expect(TranscriptLanguageHint.inferIsoCode('Hello'), isNull);
      expect(TranscriptLanguageHint.inferIsoCode('Bo Arts'), 'fr');
      expect(TranscriptLanguageHint.inferIsoCode('beaux arts'), 'fr');
    });
  });
}
