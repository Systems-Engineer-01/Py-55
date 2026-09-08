import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:py55/shared/widgets/verified_badge.dart';

void main() {
  testWidgets('VerifiedBadge muestra check azul cuando está verificado',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerifiedBadge(verificado: true),
        ),
      ),
    );

    expect(find.text('Verificado'), findsOneWidget);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
  });

  testWidgets('VerifiedBadge muestra estado pendiente cuando no está verificado',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerifiedBadge(verificado: false),
        ),
      ),
    );

    expect(find.text('Pendiente de verificación'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
  });
}
