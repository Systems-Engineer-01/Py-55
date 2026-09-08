import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:py55/features/auth/screens/phone_input_screen.dart';

void main() {
  testWidgets('PhoneInputScreen muestra elementos básicos',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PhoneInputScreen()),
    );

    // Verifica que el título y el botón estén presentes.
    expect(find.text('Ingresa tu número'), findsOneWidget);
    expect(find.text('Enviar código'), findsOneWidget);
  });
}
