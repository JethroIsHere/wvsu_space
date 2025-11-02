// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:wvsu_space/main.dart';

void main() {
  testWidgets('Getting Started flow renders and navigates', (tester) async {
    // Build app
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // First page visible
    expect(find.text('Share at your own pace'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    // Continue to page 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Chat randomly and freely'), findsOneWidget);

    // Skip to last page
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Choose'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });
}
