// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Initialize SharedPreferences with mock values
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // Build our app and trigger a frame
    await tester.pumpWidget(MyApp(prefs: prefs));

    // Verify that the splash screen loads
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for navigation
    await tester.pumpAndSettle();

    // Verify that we navigated to login screen (since user is not authenticated)
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('Login screen displays correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(MyApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Verify login screen elements
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Email and password fields
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Can type in email field', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(MyApp(prefs: prefs));
    await tester.pumpAndSettle();

    // Find email field and enter text
    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'test@example.com');
    await tester.pump();

    // Verify text was entered
    expect(find.text('test@example.com'), findsOneWidget);
  });
}