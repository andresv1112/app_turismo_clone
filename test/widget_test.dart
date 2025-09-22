// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_turismo/main.dart';

void main() {
  testWidgets('Main scaffold updates when navigating between tabs',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Verify that the bottom navigation items are rendered.
    final bottomNavigationFinder = find.byType(BottomNavigationBar);
    expect(bottomNavigationFinder, findsOneWidget);
    expect(
      find.descendant(
        of: bottomNavigationFinder,
        matching: find.text('Mapa'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomNavigationFinder,
        matching: find.text('Rutas Seguras'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bottomNavigationFinder,
        matching: find.text('Reportes'),
      ),
      findsOneWidget,
    );

    // The initial tab shows the "Mapa" title.
    expect(find.widgetWithText(AppBar, 'Mapa'), findsOneWidget);

    // Navigate to the "Rutas Seguras" tab and verify the content updates.
    await tester.tap(find.text('Rutas Seguras'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(AppBar, 'Rutas Seguras'), findsOneWidget);
    expect(find.text('Contenido de rutas seguras'), findsOneWidget);

    // Navigate to the "Reportes" tab and verify the content updates.
    await tester.tap(find.text('Reportes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(AppBar, 'Reportes'), findsOneWidget);
    expect(find.text('Contenido de reportes'), findsOneWidget);
  });
}