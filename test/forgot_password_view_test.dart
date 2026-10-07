import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resq/views/auth/forgot_password_view.dart';

void main() {
  Future<void> pumpView(WidgetTester tester, {String identifier = '', bool isEmail = true}) {
    return tester.pumpWidget(MaterialApp(
      home: ForgotPasswordView(initialIdentifier: identifier, initialIsEmail: isEmail),
    ));
  }

  testWidgets('pre-fills the identifier passed from the login screen', (tester) async {
    await pumpView(tester, identifier: 'juan@example.com');
    expect(find.text('juan@example.com'), findsOneWidget);
    expect(find.text('SEND CODE'), findsOneWidget);
  });

  testWidgets('rejects an invalid email before calling the backend', (tester) async {
    await pumpView(tester, identifier: 'not-an-email');
    await tester.tap(find.text('SEND CODE'));
    await tester.pump();
    expect(find.text('Please enter a valid email address'), findsOneWidget);
  });

  testWidgets('switching to phone mode clears the field and validates PH numbers', (tester) async {
    await pumpView(tester, identifier: 'juan@example.com');
    await tester.tap(find.text('Phone No.'));
    await tester.pump();
    expect(find.text('juan@example.com'), findsNothing);

    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.tap(find.text('SEND CODE'));
    await tester.pump();
    expect(find.text('Enter a valid PH mobile number (e.g. 09123456789)'), findsOneWidget);
  });

  testWidgets('shows the backend error and stays on step 1 when sending fails', (tester) async {
    // flutter_test answers every real HTTP request with a 400 and no body,
    // so this exercises the ApiException path end to end.
    await pumpView(tester, identifier: 'juan@example.com');
    await tester.runAsync(() async {
      await tester.tap(find.text('SEND CODE'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    expect(find.textContaining('HTTP 400'), findsOneWidget);
    expect(find.text('Verification Code'), findsNothing);
  });
}
