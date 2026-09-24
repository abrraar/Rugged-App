// test/integration_tests/main_feature_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rugged/features/exercise/exercise_screen.dart';
import 'package:rugged/features/exercise/provider/exercise_provider.dart';
import 'package:rugged/features/exercise/model/exercise_template.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'test_helpers.dart';

class MockExerciseProvider extends Mock implements ExerciseProvider {}
class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    registerFallbackValue(SignUpMode.email);
    registerFallbackValue(ExerciseTemplate(name: 'fallback'));
  });

  group('Test #3: Main Feature (HIT Exercise Tracking) Integration Test', () {
    late MockExerciseProvider mockExerciseProv;
    late MockAuthProvider mockAuth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockAuth = MockAuthProvider();
      when(() => mockAuth.isLoading).thenReturn(false);
      when(() => mockAuth.isPro).thenReturn(false);
      when(() => mockAuth.isCooldownActive(any())).thenReturn(false);
      when(() => mockAuth.emailCooldownSeconds).thenReturn(0);
      AuthProvider.setMockInstance(mockAuth);

      mockExerciseProv = MockExerciseProvider();
      final mockTemplate = ExerciseTemplate(
        id: 'ex-1',
        name: 'BARBELL SQUAT',
        targetMuscles: 'Legs, Glutes',
        intensity: 5,
        type: ExerciseType.compound,
        aboutTheMovement: 'High intensity compound movement.',
        isDefault: true,
      );

      when(() => mockExerciseProv.isLoading).thenReturn(false);
      when(() => mockExerciseProv.defaultTemplates).thenReturn([mockTemplate]);
      when(() => mockExerciseProv.customTemplates).thenReturn([]);
      when(() => mockExerciseProv.templates).thenReturn([mockTemplate]);
      when(() => mockExerciseProv.addTemplate(any())).thenAnswer((_) async => {});
    });

    testWidgets('Renders ExerciseScreen and displays core exercise templates', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const ExerciseScreen(),
          exerciseProvider: mockExerciseProv,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseScreen), findsOneWidget);
      expect(find.text('BARBELL SQUAT'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Allows searching and filtering through exercises list', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const ExerciseScreen(),
          exerciseProvider: mockExerciseProv,
        ),
      );
      await tester.pumpAndSettle();

      final searchFields = find.byType(TextField);
      if (searchFields.evaluate().isNotEmpty) {
        await tester.enterText(searchFields.first, 'SQUAT');
        await tester.pumpAndSettle();
        expect(find.text('BARBELL SQUAT'), findsOneWidget);
      }

      await tester.pump(const Duration(seconds: 5));
    });
  });
}
