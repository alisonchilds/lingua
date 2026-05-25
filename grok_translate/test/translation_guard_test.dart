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

    test('detects multilingual garbage', () {
      expect(
        TranslationGuard.looksLikeMultilingualGarbage(
          '你好 ? Bonjour. Bonjour. Hello.',
          'English',
        ),
        isTrue,
      );
    });

    test('shouldRetryStrict combines assistant and multilingual checks', () {
      expect(
        TranslationGuard.shouldRetryStrict(
          output: 'Hello! How can I help you today?',
          originalInput: 'Hello',
          targetLanguage: 'French',
        ),
        isTrue,
      );
      expect(
        TranslationGuard.shouldRetryStrict(
          output: 'Bonjour',
          originalInput: 'Hello',
          targetLanguage: 'French',
        ),
        isFalse,
      );
      expect(
        TranslationGuard.shouldRetryStrict(
          output: '',
          originalInput: 'Hello',
          targetLanguage: 'French',
        ),
        isFalse,
      );
    });
  });
}
