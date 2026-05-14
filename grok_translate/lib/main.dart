import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/conversation_controller.dart';
import 'router/app_router.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await PreferencesService.create();

  runApp(
    ProviderScope(
      overrides: [
        preferencesServiceProvider.overrideWithValue(prefs),
      ],
      child: const GrokTranslateApp(),
    ),
  );
}

class GrokTranslateApp extends ConsumerWidget {
  const GrokTranslateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Babelfish',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark_,
      themeMode: ThemeMode.light, // always light — the dark areas are custom-painted
      routerConfig: AppRouter.router,
    );
  }
}
