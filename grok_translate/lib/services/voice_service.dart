import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import '../config/app_config.dart';

/// A voice available for use in the Realtime API session.
class GrokVoice {
  const GrokVoice({
    required this.id,
    required this.name,
    required this.description,
    this.isCustom = false,
  });

  /// The value passed to session.update `voice` — built-in name or custom voice_id.
  final String id;
  final String name;
  final String description;

  /// True for user-created cloned voices, false for xAI built-in voices.
  final bool isCustom;
}

/// All five built-in xAI voices. These are static and documented; no API
/// call is needed. Each custom cloned voice is fetched via [fetchCustomVoices].
const kBuiltInVoices = [
  GrokVoice(id: 'eve', name: 'Eve',
      description: 'Female · Energetic, upbeat · Default'),
  GrokVoice(id: 'ara', name: 'Ara',
      description: 'Female · Warm, friendly'),
  GrokVoice(id: 'rex', name: 'Rex',
      description: 'Male · Confident, clear'),
  GrokVoice(id: 'sal', name: 'Sal',
      description: 'Neutral · Smooth, balanced'),
  GrokVoice(id: 'leo', name: 'Leo',
      description: 'Male · Authoritative, strong'),
];

/// Fetches the user's custom (cloned) voices via the Cloudflare proxy.
/// Returns an empty list on error.
class VoiceService {
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  Future<List<GrokVoice>> fetchCustomVoices() async {
    try {
      final response = await http
          .get(Uri.parse(AppConfig.customVoicesProxyHttp))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final list = json['voices'] as List? ?? [];
        return list.map((v) {
          final name = (v['name'] as String?)?.trim();
          final gender = (v['gender'] as String?);
          final tone = (v['tone'] as String?);
          final desc = [
            if (gender != null) gender,
            if (tone != null) tone,
          ].join(' · ');
          return GrokVoice(
            id: v['voice_id'] as String,
            name: name?.isNotEmpty == true ? name! : v['voice_id'] as String,
            description: desc.isNotEmpty ? desc : 'Custom voice',
            isCustom: true,
          );
        }).toList();
      } else if (response.statusCode == 403) {
        // Enterprise-only API or feature not enabled — not an error for most users
        _log.d('Custom voices API returned 403 (feature may not be enabled).');
      } else {
        _log.w('Custom voices fetch failed: ${response.statusCode}');
      }
    } catch (e) {
      _log.w('Custom voices fetch error: $e');
    }
    return [];
  }
}
