// test/widget_test.dart
//
// ✅ FIX: Package name in pubspec.yaml is 'kca_foundation' (not 'kca_university_foundation').
//    Corrected the import on line 21.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kca_foundation/main.dart' as app; // ✅ FIXED package name

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App loads and shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const app.MyApp());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Navigates to login after onboarding is done',
          (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({'onboarding_done': true});

        await tester.pumpWidget(const app.MyApp());
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        expect(find.text('Welcome Back'), findsOneWidget);
        expect(find.byType(TextField), findsNWidgets(2));
        expect(find.text('Login'), findsOneWidget);
      });

  testWidgets('Can type in email field on login screen',
          (WidgetTester tester) async {
        SharedPreferences.setMockInitialValues({'onboarding_done': true});

        await tester.pumpWidget(const app.MyApp());
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        final emailField = find.byType(TextField).first;
        await tester.enterText(emailField, 'test@example.com');
        await tester.pump();

        expect(find.text('test@example.com'), findsOneWidget);
      });
}