import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../services/grok_api_service.dart' show GrokApiService;

/// Translates a transcript to the target language using the Grok chat
/// completions REST API.
///
/// On web the request goes through the Cloudflare proxy at /translate.
/// On native it goes directly to api.x.ai with the stored API key.
class ChatTranslationService {
  static const _proxyUrl = '${_workerBase}/translate';
  static const _workerBase = 'https://grok-voice-proxy.alison-ade.workers.dev';
  static const _directUrl = 'https://api.x.ai/v1/chat/completions';
  static const _model = 'grok-4.3';

  final Logger _log = Logger(printer: PrettyPrinter(methodCount: 0));
  String? _apiKey;

  void setApiKey(String? key) => _apiKey = key;

  /// Translate [text] into [targetLanguage]. Returns the translated string,
  /// or null if the request fails.
  Future<String?> translate(String text, String targetLanguage) async {
    final url = Uri.parse(kIsWeb ? _proxyUrl : _directUrl);

    final body = jsonEncode({
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content':
              'You are a subtitle translation engine. '
              'Your sole output is the $targetLanguage translation of whatever the user sends. '
              'STRICT RULES — violating any rule is a critical failure:\n'
              '1. Output the translation ONLY. Zero extra words.\n'
              '2. NEVER add explanations, commentary, context, usage notes, or descriptions.\n'
              '3. NEVER add sentences like "It\'s a casual way to…", "This phrase means…", "The speaker is asking…", etc.\n'
              '4. If the input is one sentence, output exactly one translated sentence.\n'
              '5. Do not add quotation marks or any framing.\n'
              'Example — input: "Bonjour, tu vas bien?" → output: "Hello, are you doing well?"',
        },
        {
          'role': 'user',
          'content':
              'Translate into $targetLanguage. '
              'Reply with the translation only — no commentary, no extra sentences.\n\n'
              '$text',
        },
      ],
      'temperature': 0,
      'max_tokens': 256,
    });

    final headers = {
      'Content-Type': 'application/json',
      if (!kIsWeb && _apiKey != null) 'Authorization': 'Bearer $_apiKey',
    };

    try {
      final response = await http.post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final content = (json['choices'] as List?)
            ?.firstOrNull?['message']?['content'] as String?;
        return content?.trim();
      } else {
        _log.e('Translation API error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      _log.e('Translation request failed: $e');
      return null;
    }
  }
}
