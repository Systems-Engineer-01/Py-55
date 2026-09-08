import 'package:flutter_test/flutter_test.dart';

import 'package:py55/main.dart';

void main() {
  testWidgets('HomeScreen shows app title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Nota: No inicializamos Firebase en tests; probamos solo el widget.
    await tester.pumpWidget(const Py55App());

    // Verify that the home screen shows the expected text.
    expect(find.text('Py55 - vehículo en tiempo real'), findsOneWidget);
  });
}
