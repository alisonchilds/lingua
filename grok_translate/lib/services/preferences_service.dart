import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation_models.dart';

/// Thin wrapper around SharedPreferences for persisting user settings.
///
/// ── Future: per-user defaults ────────────────────────────────────────────────
/// TODO: When user accounts are added, migrate these preferences to a user
/// profile stored server-side (e.g. Supabase / Firebase). Each user should
/// be able to set:
///   - defaultTargetLanguage  (e.g. "English") — used as the default "translate into"
///     language in subtitles mode and as the pre-selected lang2 in translator mode.
///   - defaultSourceLanguage  (e.g. "French") — pre-fill lang1 on setup.
///   - preferredAppMode       (translator | subtitles) — open directly to their mode.
///   - preferredVadSettings   (threshold, silenceDuration) — per-user VAD tuning.
/// Until then, preferences are device-local via SharedPreferences.
/// ─────────────────────────────────────────────────────────────────────────────
class PreferencesService {
  static const _keyApiKey = 'grok_api_key';
  static const _keyLanguageConfig = 'language_config';
  static const _keyVadSettings = 'vad_settings';
  static const _keySubtitlesEnabled = 'subtitles_enabled';

  final SharedPreferences _prefs;
  PreferencesService(this._prefs);

  static Future<PreferencesService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService(prefs);
  }

  // API Key
  String? getApiKey() => _prefs.getString(_keyApiKey);
  Future<void> setApiKey(String key) => _prefs.setString(_keyApiKey, key);

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
}
