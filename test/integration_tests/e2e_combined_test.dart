// test/integration_tests/e2e_combined_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rugged/features/auth/screen/signin_screen.dart';
import 'package:rugged/features/auth/screen/login_screen.dart';
import 'package:rugged/features/exercise/exercise_screen.dart';
import 'package:rugged/features/pro/pro_upgrade_screen.dart';

import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/exercise/provider/exercise_provider.dart';
import 'package:rugged/core/providers/iap_provider.dart';
import 'package:rugged/features/exercise/model/exercise_template.dart';
import 'test_helpers.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockExerciseProvider extends Mock implements ExerciseProvider {}
class MockIAPProvider extends Mock implements IAPProvider {}
class FakeProductDetails extends Fake implements ProductDetails {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(SignUpMode.email);
    registerFallbackValue(ExerciseTemplate(name: 'fallback'));
    registerFallbackValue(FakeProductDetails());
  });

  group('Test #5: Continuous End-to-End User Journey Integration Test', () {
    late MockAuthProvider mockAuth;
    late MockExerciseProvider mockExercise;
    late MockIAPProvider mockIAP;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAuth = MockAuthProvider();
      mockExercise = MockExerciseProvider();
      mockIAP = MockIAPProvider();

      // Auth Stubs
      when(() => mockAuth.isLoading).thenReturn(false);
      when(() => mockAuth.isPro).thenReturn(false);
      when(() => mockAuth.isCooldownActive(any())).thenReturn(false);
      when(() => mockAuth.emailCooldownSeconds).thenReturn(0);
      when(() => mockAuth.activeProTierName).thenReturn('FREE TIER');
      when(() => mockAuth.checkUsernameAvailability(any())).thenAnswer((_) async => true);
      when(() => mockAuth.signUp(any(), any(), username: any(named: 'username'))).thenAnswer((_) async => {});
      when(() => mockAuth.signIn(any(), any())).thenAnswer((_) async => {});
      AuthProvider.setMockInstance(mockAuth);

      // Exercise Stubs
      final mockTemplate = ExerciseTemplate(
        id: 'ex-e2e',
        name: 'INCLINE PRESS',
        targetMuscles: 'Chest, Shoulders',
        intensity: 4,
        type: ExerciseType.compound,
        aboutTheMovement: 'High intensity upper body pressing.',
        isDefault: true,
      );
      when(() => mockExercise.isLoading).thenReturn(false);
      when(() => mockExercise.defaultTemplates).thenReturn([mockTemplate]);
      when(() => mockExercise.customTemplates).thenReturn([]);
      when(() => mockExercise.templates).thenReturn([mockTemplate]);

      // IAP Stubs
      when(() => mockIAP.isLoading).thenReturn(false);
      when(() => mockIAP.isAvailable).thenReturn(true);
      when(() => mockIAP.products).thenReturn({});
      when(() => mockIAP.pro1y).thenReturn(null);
      when(() => mockIAP.pro6m).thenReturn(null);
      when(() => mockIAP.pro3m).thenReturn(null);
      when(() => mockIAP.pro1m).thenReturn(null);
      when(() => mockIAP.buyPro()).thenAnswer((_) async => {});
      when(() => mockIAP.buySubscription(any())).thenAnswer((_) async => {});
    });

    testWidgets('Complete user journey: Sign Up -> Sign In -> Core Feature -> Payment Checkout', (WidgetTester tester) async {
      // PHASE 1: SIGN UP FLOW
      await tester.pumpWidget(
        createTestApp(
          child: const SignInScreen(),
          authProvider: mockAuth,
          exerciseProvider: mockExercise,
          iapProvider: mockIAP,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      final signUpFields = find.byType(TextField);
      if (signUpFields.evaluate().length >= 2) {
        await tester.enterText(signUpFields.at(0), 'e2e_user@rugged.app');
        await tester.enterText(signUpFields.at(1), 'E2E_Pass123!');
        await tester.pumpAndSettle();
      }

      // PHASE 2: SIGN IN FLOW
      await tester.pumpWidget(
        createTestApp(
          child: const LoginScreen(),
          authProvider: mockAuth,
          exerciseProvider: mockExercise,
          iapProvider: mockIAP,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      final loginFields = find.byType(TextField);
      if (loginFields.evaluate().length >= 2) {
        await tester.enterText(loginFields.at(0), 'e2e_user@rugged.app');
        await tester.enterText(loginFields.at(1), 'E2E_Pass123!');
        await tester.pumpAndSettle();

        final loginButton = find.text('LOG IN').first;
        await tester.tap(loginButton);
        await tester.pumpAndSettle();
        verify(() => mockAuth.signIn('e2e_user@rugged.app', 'E2E_Pass123!')).called(1);
      }

      // PHASE 3: CORE FEATURE USE (EXERCISES & WORKOUTS)
      await tester.pumpWidget(
        createTestApp(
          child: const ExerciseScreen(),
          authProvider: mockAuth,
          exerciseProvider: mockExercise,
          iapProvider: mockIAP,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseScreen), findsOneWidget);
      expect(find.text('INCLINE PRESS'), findsOneWidget);

      // PHASE 4: PAYMENT PROCESS (PRO PAYWALL CHECKOUT)
      await tester.pumpWidget(
        createTestApp(
          child: const ProUpgradeScreen(),
          authProvider: mockAuth,
          exerciseProvider: mockExercise,
          iapProvider: mockIAP,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProUpgradeScreen), findsOneWidget);
      final annualCard = find.textContaining('ANNUAL PASS');
      expect(annualCard, findsOneWidget);
      await tester.tap(annualCard, warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.pump(const Duration(seconds: 5));
    });
  });
}
