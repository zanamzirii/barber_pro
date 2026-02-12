import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barber_pro/features/auth/splash_screen.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen(autoNavigate: false)),
    );
    expect(find.text('Midnight Barber'), findsOneWidget);
  });
}
