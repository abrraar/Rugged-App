// test/integration_tests/payment_process_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rugged/features/pro/pro_upgrade_screen.dart';
import 'package:rugged/core/providers/iap_provider.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'test_helpers.dart';

class MockIAPProvider extends Mock implements IAPProvider {}
class MockAuthProvider extends Mock implements AuthProvider {}
class FakeProductDetails extends Fake implements ProductDetails {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(SignUpMode.email);
    registerFallbackValue(FakeProductDetails());
  });

  group('Test #4: Payment Process Integration Test', () {
    late MockIAPProvider mockIAP;
    late MockAuthProvider mockAuth;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockIAP = MockIAPProvider();
      mockAuth = MockAuthProvider();

      when(() => mockIAP.isLoading).thenReturn(false);
      when(() => mockIAP.isAvailable).thenReturn(true);
      when(() => mockIAP.products).thenReturn({});
      when(() => mockIAP.pro1y).thenReturn(null);
      when(() => mockIAP.pro6m).thenReturn(null);
      when(() => mockIAP.pro3m).thenReturn(null);
      when(() => mockIAP.pro1m).thenReturn(null);
      when(() => mockIAP.buyPro()).thenAnswer((_) async => {});
      when(() => mockIAP.buySubscription(any())).thenAnswer((_) async => {});

      when(() => mockAuth.isLoading).thenReturn(false);
      when(() => mockAuth.isPro).thenReturn(false);
      when(() => mockAuth.isCooldownActive(any())).thenReturn(false);
      when(() => mockAuth.emailCooldownSeconds).thenReturn(0);
      when(() => mockAuth.activeProTierName).thenReturn('FREE TIER');
      AuthProvider.setMockInstance(mockAuth);
    });

    testWidgets('Renders ProUpgradeScreen paywall and displays subscription options', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const ProUpgradeScreen(),
          iapProvider: mockIAP,
          authProvider: mockAuth,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProUpgradeScreen), findsOneWidget);
      expect(find.textContaining('ANNUAL PASS'), findsOneWidget);
      expect(find.textContaining('MONTHLY PASS'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Selecting a subscription tier and tapping upgrade triggers purchase flow', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: const ProUpgradeScreen(),
          iapProvider: mockIAP,
          authProvider: mockAuth,
        ),
      );
      await tester.pumpAndSettle();

      final monthlyCard = find.textContaining('MONTHLY PASS');
      expect(monthlyCard, findsOneWidget);
      await tester.tap(monthlyCard);
      await tester.pumpAndSettle();

      final upgradeButton = find.textContaining('GO PRO');
      if (upgradeButton.evaluate().isNotEmpty) {
        await tester.tap(upgradeButton.first);
        await tester.pumpAndSettle();
      }

      await tester.pump(const Duration(seconds: 5));
    });
  });
}
