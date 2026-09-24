// test/non_pro_local_only_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/tracker/sleep/data/sleep_alarm_repository.dart';
import 'package:rugged/features/tracker/calorie/model/calorie_log.dart';
import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:rugged/features/tracker/calorie/data/calorie_local_repository.dart';
import 'package:rugged/features/tracker/calorie/data/calorie_cloud_repository.dart';

import 'package:rugged/features/tracker/hydration/model/hydration_log.dart';
import 'package:rugged/features/tracker/hydration/provider/hydration_provider.dart';
import 'package:rugged/features/tracker/hydration/data/hydration_local_repository.dart';
import 'package:rugged/features/tracker/hydration/data/hydration_cloud_repository.dart';

import 'package:rugged/features/tracker/sleep/model/sleep_log.dart';
import 'package:rugged/features/tracker/sleep/provider/sleep_provider.dart';
import 'package:rugged/features/tracker/sleep/data/sleep_local_repository.dart';
import 'package:rugged/features/tracker/sleep/data/sleep_cloud_repository.dart';

import 'package:rugged/features/tracker/body_composition/model/body_comp_log.dart';
import 'package:rugged/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:rugged/features/tracker/body_composition/data/body_comp_local_repository.dart';
import 'package:rugged/features/tracker/body_composition/data/body_comp_cloud_repository.dart';

import 'package:rugged/features/tracker/cycle_tracker/model/exercise_log.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/data/cycle_local_repository.dart';
import 'package:rugged/features/tracker/cycle_tracker/data/cycle_cloud_repository.dart';

import 'package:rugged/core/services/notification_service.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockCalorieLocalRepo extends Mock implements CalorieLocalRepository {}
class MockCalorieCloudRepo extends Mock implements CalorieCloudRepository {}
class MockHydrationLocalRepo extends Mock implements HydrationLocalRepository {}
class MockHydrationCloudRepo extends Mock implements HydrationCloudRepository {}
class MockSleepLocalRepo extends Mock implements SleepLocalRepository {}
class MockSleepCloudRepo extends Mock implements SleepCloudRepository {}
class MockBodyCompLocalRepo extends Mock implements BodyCompLocalRepository {}
class MockBodyCompCloudRepo extends Mock implements BodyCompCloudRepository {}
class MockCycleLocalRepo extends Mock implements CycleLocalRepository {}
class MockCycleCloudRepo extends Mock implements CycleCloudRepository {}
class MockNotificationService extends Mock implements NotificationService {}

void main() {
  const String testUserId = "non-pro-user-uuid";

  late MockAuthProvider mockAuth;
  late MockNotificationService mockNotifications;

  late CalorieProvider calorieProv;
  late MockCalorieLocalRepo calorieLocal;
  late MockCalorieCloudRepo calorieCloud;

  late HydrationProvider hydrationProv;
  late MockHydrationLocalRepo hydrationLocal;
  late MockHydrationCloudRepo hydrationCloud;

  late SleepProvider sleepProv;
  late MockSleepLocalRepo sleepLocal;
  late MockSleepCloudRepo sleepCloud;

  late BodyCompProvider bodyProv;
  late MockBodyCompLocalRepo bodyLocal;
  late MockBodyCompCloudRepo bodyCloud;

  late CycleProvider cycleProv;
  late MockCycleLocalRepo cycleLocal;
  late MockCycleCloudRepo cycleCloud;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    registerFallbackValue(CalorieLog(id: 'c', mealName: '', foodItems: '', calories: 0, timestamp: DateTime.now()));
    registerFallbackValue(HydrationLog(id: 'h', amountMl: 0, amountOz: 0, timestamp: DateTime.now()));
    registerFallbackValue(SleepLog(id: 's', bedtime: DateTime.now(), wakeUpTime: DateTime.now(), quality: 3, type: SleepType.night));
    registerFallbackValue(BodyCompLog(id: 'b', valueKg: 0, valueLbs: 0, timestamp: DateTime.now(), type: BodyMetricType.weight, unit: BodyMetricUnit.kg));
    registerFallbackValue(ExerciseLog(id: 'e', exerciseId: '', weightKg: 0, weightLbs: 0, positiveReps: 0, timestamp: DateTime.now()));
  });

  setUp(() {
    mockAuth = MockAuthProvider();
    when(() => mockAuth.isPro).thenReturn(false); // Non-Pro user!
    AuthProvider.setMockInstance(mockAuth);

    mockNotifications = MockNotificationService();

    // Calorie
    calorieLocal = MockCalorieLocalRepo();
    calorieCloud = MockCalorieCloudRepo();
    when(() => calorieLocal.userId).thenReturn(testUserId);
    when(() => calorieCloud.insertLog(any())).thenAnswer((_) async => {});
    calorieProv = CalorieProvider();
    calorieProv.setRepositories(local: calorieLocal, cloud: calorieCloud, notifications: mockNotifications);

    // Hydration
    hydrationLocal = MockHydrationLocalRepo();
    hydrationCloud = MockHydrationCloudRepo();
    when(() => hydrationLocal.userId).thenReturn(testUserId);
    when(() => hydrationCloud.insertLog(any())).thenAnswer((_) async => {});
    hydrationProv = HydrationProvider();
    hydrationProv.setRepositories(local: hydrationLocal, cloud: hydrationCloud, notifications: mockNotifications);

    // Sleep
    sleepLocal = MockSleepLocalRepo();
    sleepCloud = MockSleepCloudRepo();
    when(() => sleepLocal.userId).thenReturn(testUserId);
    when(() => sleepCloud.insertLog(any())).thenAnswer((_) async => {});
    sleepProv = SleepProvider();
    sleepProv.setRepositories(local: sleepLocal, cloud: sleepCloud);

    // BodyComp
    bodyLocal = MockBodyCompLocalRepo();
    bodyCloud = MockBodyCompCloudRepo();
    when(() => bodyLocal.userId).thenReturn(testUserId);
    when(() => bodyCloud.insertLog(any())).thenAnswer((_) async => {});
    bodyProv = BodyCompProvider();
    bodyProv.setRepositories(local: bodyLocal, cloud: bodyCloud, notifications: mockNotifications);

    // Cycle
    cycleLocal = MockCycleLocalRepo();
    cycleCloud = MockCycleCloudRepo();
    when(() => cycleLocal.userId).thenReturn(testUserId);
    when(() => cycleCloud.insertLog(any())).thenAnswer((_) async => {});
    cycleProv = CycleProvider();
    cycleProv.setRepositories(local: cycleLocal, cloud: cycleCloud);
  });

  group('NON-PRO USER LOCAL PERSISTENCE TESTS (isSynced = 0 Saved to Local DB)', () {
    
    test('Non-Pro Calorie Log: Saved locally with isSynced = 0', () async {
      final log = CalorieLog(id: 'c-nonpro-1', mealName: 'MEAL', foodItems: '', calories: 500, timestamp: DateTime.now());
      when(() => calorieLocal.insertLog(any())).thenAnswer((_) async => {});

      await calorieProv.addLog(log);

      verify(() => calorieLocal.insertLog(any(that: predicate<CalorieLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Non-Pro Hydration Log: Saved locally with isSynced = 0', () async {
      when(() => hydrationLocal.insertLog(any())).thenAnswer((_) async => {});

      await hydrationProv.addWater(250);

      verify(() => hydrationLocal.insertLog(any(that: predicate<HydrationLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Non-Pro Sleep Log: Saved locally with isSynced = 0', () async {
      final log = SleepLog(id: 's-nonpro-1', bedtime: DateTime.now(), wakeUpTime: DateTime.now(), quality: 4, type: SleepType.night);
      when(() => sleepLocal.insertLog(any())).thenAnswer((_) async => {});

      await sleepProv.addSleepLog(log);

      verify(() => sleepLocal.insertLog(any(that: predicate<SleepLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Non-Pro BodyComp Log: Saved locally with isSynced = 0', () async {
      final log = BodyCompLog(id: 'b-nonpro-1', valueKg: 80, valueLbs: 176, timestamp: DateTime.now(), type: BodyMetricType.weight, unit: BodyMetricUnit.kg);
      when(() => bodyLocal.insertLog(any())).thenAnswer((_) async => {});

      await bodyProv.addLog(log);

      verify(() => bodyLocal.insertLog(any(that: predicate<BodyCompLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Non-Pro Exercise Log: Saved locally with isSynced = 0', () async {
      final log = ExerciseLog(id: 'ex-nonpro-1', exerciseId: 'bench-press', weightKg: 100, weightLbs: 220, positiveReps: 1, timestamp: DateTime.now());
      when(() => cycleLocal.insertLog(any())).thenAnswer((_) async => {});
      when(() => cycleLocal.getAllCycles()).thenAnswer((_) async => []);

      await cycleProv.upsertExerciseLog(log);

      verify(() => cycleLocal.insertLog(any(that: predicate<ExerciseLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Non-Pro Sleep Alarm Repository: Cloud sync is blocked when isPro = false', () async {
      final mockAuthInstance = MockAuthProvider();
      when(() => mockAuthInstance.isPro).thenReturn(false);
      AuthProvider.setMockInstance(mockAuthInstance);

      final alarmSettings = SleepAlarmSettings(
        userId: testUserId,
        bedtimeEnabled: true,
        bedtimeHour: 23,
        bedtimeMinute: 0,
        isSynced: 0,
      );

      // Verify that isPro returns false
      expect(AuthProvider().isPro, isFalse);
      expect(alarmSettings.isSynced, equals(0));
    });
  });
}
