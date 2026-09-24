// test/integration_tests/sign_up_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rugged/features/auth/screen/signin_screen.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'test_helpers.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(SignUpMode.email);

  group('Test #1: Sign Up Process Integration Test', () {
    late MockAuthProvider mockAuth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAuth = MockAuthProvider();
      when(() => mockAuth.isLoading).thenReturn(false);
      when(() => mockAuth.isPro).thenReturn(false);
      when(() => mockAuth.isCooldownActive(any())).thenReturn(false);
      when(() => mockAuth.emailCooldownSeconds).thenReturn(0);
      when(() => mockAuth.checkUsernameAvailability(any())).thenAnswer((_) async => true);
      AuthProvider.setMockInstance(mockAuth);
    });

    testWidgets('Renders sign up form, enters user details, and triggers sign up flow', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const SignInScreen(),
          authProvider: mockAuth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);

      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(2));

      await tester.enterText(textFields.at(0), 'newuser@rugged.app');
      await tester.enterText(textFields.at(1), 'SecurePass123!');
      await tester.pumpAndSettle();

      final signUpButton = find.text('CREATE ACCOUNT').first;
      expect(signUpButton, findsOneWidget);

      await tester.tap(signUpButton);
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
    });
  });
}
