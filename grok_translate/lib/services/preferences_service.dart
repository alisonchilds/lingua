import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation_models.dart';

/// Thin wrapper around SharedPreferences for persisting user settings.
///
/// API keys are managed exclusively server-side via the Cloudflare Worker
/// proxy. No API key is ever stored on device.
///
/// ── Future: per-user defaults ────────────────────────────────────────────────
/// TODO: When user accounts are added, migrate these preferences to a user
/// profile stored server-side (e.g. Supabase / Firebase). Each user should
/// be able to set:
///   - defaultTargetLanguage  (e.g. "English")
///   - defaultSourceLanguage  (e.g. "French")
///   - preferredAppMode       (translator | subtitles)
///   - preferredVadSettings   (threshold, silenceDuration)
/// Until then, preferences are device-local via SharedPreferences.
/// ─────────────────────────────────────────────────────────────────────────────
class PreferencesService {
  static const _keyLanguageConfig = 'language_config';
  static const _keyVadSettings = 'vad_settings';
  static const _keySubtitlesEnabled = 'subtitles_enabled';
  static const _keyMyLanguageCode = 'my_language_code';
  static const _keyMyLanguageName = 'my_language_name';

  final SharedPreferences _prefs;
  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  // Language config
  LanguageConfig getLanguageConfig() {
    final raw = _prefs.getString(_keyLanguageConfig);
    if (raw == null) return const LanguageConfig();
    try {
      return LanguageConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const LanguageConfig();
    }
  }

  Future<void> setLanguageConfig(LanguageConfig cfg) =>
      _prefs.setString(_keyLanguageConfig, jsonEncode(cfg.toJson()));

  // VAD settings
  VadSettings getVadSettings() {
    final raw = _prefs.getString(_keyVadSettings);
    if (raw == null) return const VadSettings();
    try {
      return VadSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const VadSettings();
    }
  }

  Future<void> setVadSettings(VadSettings settings) =>
      _prefs.setString(_keyVadSettings, jsonEncode(settings.toJson()));

  // Subtitles
  bool getSubtitlesEnabled() => _prefs.getBool(_keySubtitlesEnabled) ?? true;
  Future<void> setSubtitlesEnabled(bool value) =>
      _prefs.setBool(_keySubtitlesEnabled, value);

  // Voice — built-in voice name ('eve', 'ara', 'rex', 'sal', 'leo') or a
  // custom voice_id created in the xAI console. Defaults to 'eve'.
  static const _keyVoiceId = 'voice_id';

  String getVoiceId() => _prefs.getString(_keyVoiceId) ?? 'eve';
  Future<void> setVoiceId(String id) => _prefs.setString(_keyVoiceId, id);

  // My Language — the user's own primary language.
  // Used as the pre-selected lang1 in the setup screen and as the
  // fallback source language in auto-detect mode before the API identifies
  // the spoken language. Defaults to English.
  String getMyLanguageCode() => _prefs.getString(_keyMyLanguageCode) ?? 'en';
  String getMyLanguageName() => _prefs.getString(_keyMyLanguageName) ?? 'English';

  Future<void> setMyLanguage(String code, String name) async {
    await _prefs.setString(_keyMyLanguageCode, code);
    await _prefs.setString(_keyMyLanguageName, name);
  }
}
