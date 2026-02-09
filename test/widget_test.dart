import 'package:flutter_test/flutter_test.dart';

import 'package:barber_pro/main.dart';

void main() {
  testWidgets('App loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.text('Midnight Barber'), findsOneWidget);
  });
}
