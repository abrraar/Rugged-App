// test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'integration_tests/test_helpers.dart';
import 'integration_tests/sign_up_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(SignUpMode.email);
  });

  testWidgets('Rugged App smoke test renders MaterialApp harness', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockAuth = MockAuthProvider();
    when(() => mockAuth.isLoading).thenReturn(false);
    when(() => mockAuth.isPro).thenReturn(false);
    when(() => mockAuth.isCooldownActive(any())).thenReturn(false);
    when(() => mockAuth.emailCooldownSeconds).thenReturn(0);
    AuthProvider.setMockInstance(mockAuth);

    await tester.pumpWidget(
      createTestApp(
        child: const Scaffold(
          body: Center(child: Text('RUGGED PERFORMANCE SYSTEM')),
        ),
        authProvider: mockAuth,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RUGGED PERFORMANCE SYSTEM'), findsOneWidget);
  });
}
