import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wvsu_space/choose.dart';

void main() {
  testWidgets('Choose screen shows logo and action buttons', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChooseScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Choose'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
    // Image widget should be present for the logo
    expect(find.byType(Image), findsWidgets);
  });
}
