/// Build-time configuration injected via --dart-define.
///
/// All three proxy endpoints (Realtime WS, STT WS, translate REST) derive
/// from a single [proxyHost] value so there is exactly one place to change
/// when deploying your own Cloudflare Worker.
///
/// ── How to set your proxy host ───────────────────────────────────────────────
///
///   Development (uses the default value below):
///     flutter run
///
///   Custom proxy at build time:
///     flutter run  --dart-define=PROXY_HOST=your-worker.workers.dev
///     flutter build web --dart-define=PROXY_HOST=your-worker.workers.dev
///     flutter build apk --dart-define=PROXY_HOST=your-worker.workers.dev
///     flutter build ios --dart-define=PROXY_HOST=your-worker.workers.dev
///
///   Or store the flag in a launch config / CI secret so it is never
///   hardcoded in source:
///     # .vscode/launch.json  →  "toolArgs": ["--dart-define=PROXY_HOST=..."]
///     # GitHub Actions       →  env: PROXY_HOST: ${{ secrets.PROXY_HOST }}
///     #                         run: flutter build web --dart-define=PROXY_HOST=$PROXY_HOST
///
/// ─────────────────────────────────────────────────────────────────────────────
class AppConfig {
  AppConfig._();

  /// Cloudflare Worker hostname — no protocol prefix, no trailing slash.
  /// Example: "your-worker.your-account.workers.dev"
  static const String proxyHost = String.fromEnvironment(
    'PROXY_HOST',
    defaultValue: 'grok-voice-proxy.alison-ade.workers.dev',
  );

  /// WebSocket URL for the Grok Realtime API (translator mode).
  static const String realtimeProxyWs = 'wss://$proxyHost';

  /// WebSocket URL for the STT streaming endpoint (subtitles mode captions).
  static const String sttProxyWs = 'wss://$proxyHost/stt';

  /// HTTPS URL for the chat-completions translation endpoint (subtitles mode).
  static const String translateProxyHttp = 'https://$proxyHost/translate';
}
