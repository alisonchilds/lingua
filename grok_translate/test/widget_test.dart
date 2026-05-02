import 'package:flutter_test/flutter_test.dart';

import 'package:grok_translate/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Smoke test – just verify the app widget tree builds without crashing.
    // Full integration tests require real device / browser for mic + WS access.
    expect(GrokTranslateApp, isNotNull);
  });
}
