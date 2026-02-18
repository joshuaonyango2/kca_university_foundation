// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kca_university_foundation/main.dart' as app;

void main() {
  testWidgets('App loads successfully', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // ✅ Fixed: use app.MyApp (matches the 'as app' import alias)
    await tester.pumpWidget(app.MyApp(prefs: prefs));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('Login screen displays correctly', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // ✅ Fixed: use app.MyApp
    await tester.pumpWidget(app.MyApp(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Can type in email field', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // ✅ Fixed: use app.MyApp
    await tester.pumpWidget(app.MyApp(prefs: prefs));
    await tester.pumpAndSettle();

    final emailField = find.byType(TextField).first;
    await tester.enterText(emailField, 'test@example.com');
    await tester.pump();

    expect(find.text('test@example.com'), findsOneWidget);
  });
}