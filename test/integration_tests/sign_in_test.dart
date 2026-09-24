// test/integration_tests/sign_in_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rugged/features/auth/screen/login_screen.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'test_helpers.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(SignUpMode.email);

  group('Test #2: Sign In Process Integration Test', () {
    late MockAuthProvider mockAuth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAuth = MockAuthProvider();
      when(() => mockAuth.isLoading).thenReturn(false);
      when(() => mockAuth.isPro).thenReturn(false);
      when(() => mockAuth.isCooldownActive(any())).thenReturn(false);
      when(() => mockAuth.emailCooldownSeconds).thenReturn(0);
      when(() => mockAuth.signIn(any(), any())).thenAnswer((_) async => {});
      AuthProvider.setMockInstance(mockAuth);
    });

    testWidgets('Renders LoginScreen, accepts credentials, and triggers sign in', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const LoginScreen(),
          authProvider: mockAuth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);

      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'member@rugged.app');
      await tester.enterText(textFields.at(1), 'ValidPassword123');
      await tester.pumpAndSettle();

      final signInButton = find.text('LOG IN').first;
      expect(signInButton, findsOneWidget);

      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      verify(() => mockAuth.signIn('member@rugged.app', 'ValidPassword123')).called(1);

      // Advance timer past EliteSnackbar duration (4s)
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Validates empty login credentials and shows warning snackbar', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const LoginScreen(),
          authProvider: mockAuth,
        ),
      );
      await tester.pumpAndSettle();

      final signInButton = find.text('LOG IN').first;
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      verifyNever(() => mockAuth.signIn(any(), any()));

      // Advance timer past EliteSnackbar duration (4s)
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
