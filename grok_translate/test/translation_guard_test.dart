import 'package:flutter_test/flutter_test.dart';
import 'package:grok_translate/utils/translation_guard.dart';

void main() {
  group('TranslationGuard', () {
    test('detects common assistant phrases', () {
      expect(
        TranslationGuard.looksLikeAssistantReply(
          'Hello! How can I help you today?',
          'Hello',
        ),
        isTrue,
      );
      expect(
        TranslationGuard.looksLikeAssistantReply('Bonjour', 'Hello'),
        isFalse,
      );
    });

    test('languageNamesMatch is case insensitive', () {
      expect(
        TranslationGuard.languageNamesMatch('English', 'english'),
        isTrue,
      );
    });
  });
}
