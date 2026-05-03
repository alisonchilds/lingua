import 'package:go_router/go_router.dart';

import '../screens/conversation_screen.dart';
import '../screens/language_setup_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/subtitles_screen.dart';

class AppRouter {
  AppRouter._();

  static const pathSetup = '/';
  static const pathConversation = '/conversation';
  static const pathSubtitles = '/subtitles';
  static const pathSettings = '/settings';

  static final router = GoRouter(
    initialLocation: pathSetup,
    routes: [
      GoRoute(
        path: pathSetup,
        builder: (context, state) => const LanguageSetupScreen(),
      ),
      GoRoute(
        path: pathConversation,
        builder: (context, state) => const ConversationScreen(),
      ),
      GoRoute(
        path: pathSubtitles,
        builder: (context, state) => const SubtitlesScreen(),
      ),
      GoRoute(
        path: pathSettings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
