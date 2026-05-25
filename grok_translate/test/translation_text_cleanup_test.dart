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
  });
}
