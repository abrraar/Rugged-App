// test/sync_integration_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Imports for Models
import 'package:rugged/features/tracker/calorie/model/calorie_log.dart';
import 'package:rugged/features/tracker/calorie/model/saved_meal.dart';
import 'package:rugged/features/tracker/calorie/model/calorie_settings.dart';
import 'package:rugged/features/tracker/hydration/model/hydration_log.dart';
import 'package:rugged/features/tracker/hydration/model/hydration_settings.dart';
import 'package:rugged/features/tracker/supplement/model/supplement.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_stack.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_item.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/training_cycle.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/exercise_log.dart';
import 'package:rugged/features/tracker/body_composition/model/body_comp_log.dart';
import 'package:rugged/features/tracker/body_composition/model/body_comp_settings.dart';
import 'package:rugged/features/tracker/sleep/model/sleep_log.dart';
import 'package:rugged/features/affirmation/model/affirmation.dart';
import 'package:rugged/features/affirmation/model/affirmation_settings.dart';
import 'package:rugged/features/exercise/model/exercise_template.dart';

// Imports for Repositories
import 'package:rugged/features/tracker/calorie/data/calorie_local_repository.dart';
import 'package:rugged/features/tracker/calorie/data/calorie_cloud_repository.dart';
import 'package:rugged/features/tracker/hydration/data/hydration_local_repository.dart';
import 'package:rugged/features/tracker/hydration/data/hydration_cloud_repository.dart';
import 'package:rugged/features/tracker/supplement/data/supplement_local_repository.dart';
import 'package:rugged/features/tracker/supplement/data/supplement_cloud_repository.dart';
import 'package:rugged/features/tracker/cycle_tracker/data/cycle_local_repository.dart';
import 'package:rugged/features/tracker/cycle_tracker/data/cycle_cloud_repository.dart';
import 'package:rugged/features/tracker/body_composition/data/body_comp_local_repository.dart';
import 'package:rugged/features/tracker/body_composition/data/body_comp_cloud_repository.dart';
import 'package:rugged/features/tracker/sleep/data/sleep_local_repository.dart';
import 'package:rugged/features/tracker/sleep/data/sleep_cloud_repository.dart';
import 'package:rugged/features/affirmation/data/affirmation_local_repository.dart';
import 'package:rugged/features/affirmation/data/affirmation_cloud_repository.dart';
import 'package:rugged/features/exercise/data/exercise_local_repository.dart';
import 'package:rugged/features/exercise/data/exercise_cloud_repository.dart';

// Imports for Providers
import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:rugged/features/tracker/hydration/provider/hydration_provider.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:rugged/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:rugged/features/tracker/sleep/provider/sleep_provider.dart';
import 'package:rugged/features/affirmation/provider/affirmation_provider.dart';
import 'package:rugged/features/exercise/provider/exercise_provider.dart';
import 'package:rugged/core/providers/sync_provider.dart';
import 'package:rugged/core/services/notification_service.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';

// --- Mocks ---
class MockCalorieLocalRepo extends Mock implements CalorieLocalRepository {}
class MockCalorieCloudRepo extends Mock implements CalorieCloudRepository {}
class MockHydrationLocalRepo extends Mock implements HydrationLocalRepository {}
class MockHydrationCloudRepo extends Mock implements HydrationCloudRepository {}
class MockSupplementLocalRepo extends Mock implements SupplementLocalRepository {}
class MockSupplementCloudRepo extends Mock implements SupplementCloudRepository {}
class MockCycleLocalRepo extends Mock implements CycleLocalRepository {}
class MockCycleCloudRepo extends Mock implements CycleCloudRepository {}
class MockBodyCompLocalRepo extends Mock implements BodyCompLocalRepository {}
class MockBodyCompCloudRepo extends Mock implements BodyCompCloudRepository {}
class MockSleepLocalRepo extends Mock implements SleepLocalRepository {}
class MockSleepCloudRepo extends Mock implements SleepCloudRepository {}
class MockAffirmationLocalRepo extends Mock implements AffirmationLocalRepository {}
class MockAffirmationCloudRepo extends Mock implements AffirmationCloudRepository {}
class MockExerciseLocalRepo extends Mock implements ExerciseLocalRepository {}
class MockExerciseCloudRepo extends Mock implements ExerciseCloudRepository {}
class MockSyncProvider extends Mock implements SyncProvider {}
class MockNotificationService extends Mock implements NotificationService {}
class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  const String testUserId = "test-user-uuid";

  // Providers
  late CalorieProvider calorieProv;
  late MockCalorieLocalRepo calorieLocal;
  late MockCalorieCloudRepo calorieCloud;

  late HydrationProvider hydrationProv;
  late MockHydrationLocalRepo hydrationLocal;
  late MockHydrationCloudRepo hydrationCloud;

  late SupplementProvider supplementProv;
  late MockSupplementLocalRepo supplementLocal;
  late MockSupplementCloudRepo supplementCloud;

  late CycleProvider cycleProv;
  late MockCycleLocalRepo cycleLocal;
  late MockCycleCloudRepo cycleCloud;

  late BodyCompProvider bodyProv;
  late MockBodyCompLocalRepo bodyLocal;
  late MockBodyCompCloudRepo bodyCloud;

  late SleepProvider sleepProv;
  late MockSleepLocalRepo sleepLocal;
  late MockSleepCloudRepo sleepCloud;

  late AffirmationProvider affirmationProv;
  late MockAffirmationLocalRepo affirmationLocal;
  late MockAffirmationCloudRepo affirmationCloud;

  late ExerciseProvider exerciseProv;
  late MockExerciseLocalRepo exerciseLocal;
  late MockExerciseCloudRepo exerciseCloud;

  late MockSyncProvider mockSync;
  late MockNotificationService mockNotifications;
  late MockAuthProvider mockAuth;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    registerFallbackValue(CalorieLog(id: 'f', mealName: '', foodItems: '', calories: 0, timestamp: DateTime.now()));
    registerFallbackValue(SavedMeal(id: 'f', name: '', foodItems: '', calories: 0));
    registerFallbackValue(CalorieSettings());
    registerFallbackValue(HydrationLog(id: 'f', amountMl: 0, amountOz: 0, timestamp: DateTime.now()));
    registerFallbackValue(HydrationSettings(userId: testUserId));
    registerFallbackValue(Supplement(id: 'f', name: '', servingUnit: '', weightPerServing: 0, weightUnit: ''));
    registerFallbackValue(SupplementStack(id: 'f', name: '', items: []));
    registerFallbackValue(SupplementItem(id: 'f', supplementId: '', supplementName: '', type: '', details: '', weightAdjustment: 0, timestamp: DateTime.now(), isSynced: 0));
    registerFallbackValue(ExerciseLog(id: 'f', exerciseId: '', weightKg: 0, weightLbs: 0, positiveReps: 0, timestamp: DateTime.now()));
    registerFallbackValue(CycleSettings(userId: testUserId));
    registerFallbackValue(BodyCompLog(id: 'f', valueKg: 0, valueLbs: 0, timestamp: DateTime.now(), type: BodyMetricType.weight, unit: BodyMetricUnit.kg));
    registerFallbackValue(BodyCompSettings(userId: testUserId));
    registerFallbackValue(SleepLog(id: 'f', bedtime: DateTime.now(), wakeUpTime: DateTime.now(), quality: 3, type: SleepType.night));
    registerFallbackValue(Affirmation(id: 'f', text: '', speaker: ''));
    registerFallbackValue(AffirmationSettings(userId: testUserId));
    registerFallbackValue(ExerciseTemplate(name: 'f'));
  });

  setUp(() {
    mockAuth = MockAuthProvider();
    when(() => mockAuth.isPro).thenReturn(true);
    AuthProvider.setMockInstance(mockAuth);

    mockSync = MockSyncProvider();
    SyncProvider.setMockInstance(mockSync);
    mockNotifications = MockNotificationService();

    // Init Calorie
    calorieLocal = MockCalorieLocalRepo();
    calorieCloud = MockCalorieCloudRepo();
    when(() => calorieLocal.userId).thenReturn(testUserId);
    calorieProv = CalorieProvider();
    calorieProv.setRepositories(local: calorieLocal, cloud: calorieCloud, notifications: mockNotifications);

    // Init Hydration
    hydrationLocal = MockHydrationLocalRepo();
    hydrationCloud = MockHydrationCloudRepo();
    when(() => hydrationLocal.userId).thenReturn(testUserId);
    hydrationProv = HydrationProvider();
    hydrationProv.setRepositories(local: hydrationLocal, cloud: hydrationCloud, notifications: mockNotifications);

    // Init Supplement
    supplementLocal = MockSupplementLocalRepo();
    supplementCloud = MockSupplementCloudRepo();
    when(() => supplementLocal.userId).thenReturn(testUserId);
    supplementProv = SupplementProvider();
    supplementProv.setRepositories(local: supplementLocal, cloud: supplementCloud, notifications: mockNotifications);

    // Init Cycle
    cycleLocal = MockCycleLocalRepo();
    cycleCloud = MockCycleCloudRepo();
    when(() => cycleLocal.userId).thenReturn(testUserId);
    cycleProv = CycleProvider();
    cycleProv.setRepositories(local: cycleLocal, cloud: cycleCloud);

    // Init BodyComp
    bodyLocal = MockBodyCompLocalRepo();
    bodyCloud = MockBodyCompCloudRepo();
    when(() => bodyLocal.userId).thenReturn(testUserId);
    bodyProv = BodyCompProvider();
    bodyProv.setRepositories(local: bodyLocal, cloud: bodyCloud, notifications: mockNotifications);

    // Init Sleep
    sleepLocal = MockSleepLocalRepo();
    sleepCloud = MockSleepCloudRepo();
    when(() => sleepLocal.userId).thenReturn(testUserId);
    sleepProv = SleepProvider();
    sleepProv.setRepositories(local: sleepLocal, cloud: sleepCloud);

    // Init Affirmation
    affirmationLocal = MockAffirmationLocalRepo();
    affirmationCloud = MockAffirmationCloudRepo();
    when(() => affirmationLocal.userId).thenReturn(testUserId);
    affirmationProv = AffirmationProvider();
    affirmationProv.setRepositories(local: affirmationLocal, cloud: affirmationCloud);

    // Init Exercise
    exerciseLocal = MockExerciseLocalRepo();
    exerciseCloud = MockExerciseCloudRepo();
    when(() => exerciseLocal.userId).thenReturn(testUserId);
    exerciseProv = ExerciseProvider();
    exerciseProv.setRepositories(local: exerciseLocal, cloud: exerciseCloud);

    // Default UI Stubs
    when(() => mockSync.startFeatureSync()).thenReturn(null);
    when(() => mockSync.addTotalItems(any())).thenReturn(null);
    when(() => mockSync.incrementCompleted()).thenReturn(null);
    when(() => mockSync.endFeatureSync()).thenReturn(null);

    // Silence Notifications
    when(() => mockNotifications.scheduleSupplementReminders(any())).thenAnswer((_) async => {});
    when(() => mockNotifications.scheduleHydrationReminders(any())).thenAnswer((_) async => {});
    when(() => mockNotifications.scheduleMealReminders(any())).thenAnswer((_) async => {});
    when(() => mockNotifications.cancelSupplementReminders(any(), cancelLowStock: any(named: 'cancelLowStock'))).thenAnswer((_) async => {});
  });

  group('SCENARIO A: OFFLINE WRITES (ALL TABLES)', () {
    
    test('Calorie Log: Offline save isSynced=0', () async {
      final log = CalorieLog(id: 'c1', mealName: 'OFF', foodItems: '', calories: 10, timestamp: DateTime.now());
      when(() => calorieLocal.insertLog(any())).thenAnswer((_) async => {});
      when(() => calorieCloud.insertLog(any())).thenThrow(Exception("Network"));
      await calorieProv.addLog(log);
      verify(() => calorieLocal.insertLog(any(that: predicate<CalorieLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Hydration Log: Offline save isSynced=0', () async {
      when(() => hydrationLocal.insertLog(any())).thenAnswer((_) async => {});
      when(() => hydrationCloud.insertLog(any())).thenThrow(Exception("Network"));
      await hydrationProv.addWater(200);
      verify(() => hydrationLocal.insertLog(any(that: predicate<HydrationLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Supplement Record: Offline save isSynced=0', () async {
      final s = Supplement(id: 's1', name: 'S', servingUnit: 'u', weightPerServing: 1, weightUnit: 'g', remainingStock: 100);
      supplementProv.setLibraryForTest([s]);
      when(() => supplementLocal.insertSupplementItem(any())).thenAnswer((_) async => {});
      when(() => supplementLocal.updateSupplementStock(any(), any())).thenAnswer((_) async => {});
      when(() => supplementCloud.insertSupplementItem(any())).thenThrow(Exception("Network"));
      when(() => supplementCloud.updateSupplementStock(any(), any())).thenThrow(Exception("Network"));
      await supplementProv.recordEntry(supplement: s, isIntake: true, isRestock: false, weightAdjustment: -1, timestamp: DateTime.now(), historyDetails: 'TEST');
      verify(() => supplementLocal.insertSupplementItem(any(that: predicate<SupplementItem>((i) => i.isSynced == 0)))).called(1);
    });

    test('Cycle Log: Offline save isSynced=0', () async {
      final log = ExerciseLog(id: 'el1', exerciseId: 'e1', weightKg: 1, weightLbs: 2, positiveReps: 1, timestamp: DateTime.now());
      when(() => cycleLocal.insertLog(any())).thenAnswer((_) async => {});
      when(() => cycleLocal.getAllCycles()).thenAnswer((_) async => []);
      when(() => cycleCloud.insertLog(any())).thenThrow(Exception("Network"));
      await cycleProv.upsertExerciseLog(log);
      verify(() => cycleLocal.insertLog(any(that: predicate<ExerciseLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Cycle Settings: Offline save settings with smartAutoDateEnabled isSynced=0', () async {
      final settings = CycleSettings(
        userId: testUserId,
        smartAutoDateEnabled: false,
      );
      when(() => cycleLocal.saveSettings(any())).thenAnswer((_) async => {});
      when(() => cycleLocal.markSettingsSynced()).thenAnswer((_) async => {});
      when(() => cycleCloud.saveSettings(any())).thenThrow(Exception("Network"));
      
      await cycleProv.updateSettings(settings);
      
      verify(() => cycleLocal.saveSettings(any(that: predicate<Map<String, dynamic>>((map) => map['smart_auto_date_enabled'] == 0 && map['is_synced'] == 0)))).called(1);
    });

    test('BodyComp Log: Offline save isSynced=0', () async {
      final log = BodyCompLog(id: 'bc1', valueKg: 1, valueLbs: 2, timestamp: DateTime.now(), type: BodyMetricType.weight, unit: BodyMetricUnit.kg);
      when(() => bodyLocal.insertLog(any())).thenAnswer((_) async => {});
      when(() => bodyCloud.insertLog(any())).thenThrow(Exception("Network"));
      await bodyProv.addLog(log);
      verify(() => bodyLocal.insertLog(any(that: predicate<BodyCompLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Sleep Log: Offline save isSynced=0', () async {
      final log = SleepLog(id: 'sl1', bedtime: DateTime.now(), wakeUpTime: DateTime.now(), quality: 3, type: SleepType.night);
      when(() => sleepLocal.insertLog(any())).thenAnswer((_) async => {});
      when(() => sleepCloud.insertLog(any())).thenThrow(Exception("Network"));
      await sleepProv.addSleepLog(log);
      verify(() => sleepLocal.insertLog(any(that: predicate<SleepLog>((l) => l.isSynced == 0)))).called(1);
    });

    test('Affirmation: Offline save isSynced=0', () async {
      when(() => affirmationLocal.insertAffirmation(any())).thenAnswer((_) async => {});
      when(() => affirmationCloud.insertAffirmation(any())).thenThrow(Exception("Network"));
      when(() => affirmationLocal.getAllAffirmations()).thenAnswer((_) async => []);
      await affirmationProv.addAffirmation("TEST");
      verify(() => affirmationLocal.insertAffirmation(any(that: predicate<Affirmation>((a) => a.isSynced == 0)))).called(1);
    });

    test('Exercise Template: Offline save isSynced=0', () async {
      final t = ExerciseTemplate(id: 't1', name: 'EX');
      when(() => exerciseLocal.insertTemplate(any())).thenAnswer((_) async => {});
      when(() => exerciseCloud.insertTemplate(any())).thenThrow(Exception("Network"));
      await exerciseProv.addTemplate(t);
      verify(() => exerciseLocal.insertTemplate(any(that: predicate<ExerciseTemplate>((t) => t.isSynced == 0)))).called(1);
    });
  });

  group('SCENARIO C: OFFLINE DELETIONS (PENDING QUEUE)', () {
    
    test('Calorie Meal: Deletion queues table calorie_meals', () async {
      when(() => calorieLocal.deleteSavedMeal(any())).thenAnswer((_) async => {});
      when(() => calorieLocal.addToDeletionQueue(any(), any())).thenAnswer((_) async => {});
      when(() => calorieCloud.deleteSavedMeal(any())).thenThrow(Exception("OFF"));
      await calorieProv.deleteSavedMeal('m1');
      verify(() => calorieLocal.addToDeletionQueue('m1', 'calorie_meals')).called(1);
    });

    test('Supplement Stack: Deletion queues table ss_stack', () async {
      final s = SupplementStack(id: 'st1', name: 'ST', items: []);
      supplementProv.setStacksForTest([s]);
      when(() => supplementLocal.deleteStack(any())).thenAnswer((_) async => {});
      when(() => supplementLocal.addToDeletionQueue(any(), any())).thenAnswer((_) async => {});
      when(() => supplementCloud.deleteStack(any())).thenThrow(Exception("OFF"));
      await supplementProv.deleteStack('st1');
      verify(() => supplementLocal.addToDeletionQueue('st1', 'ss_stack')).called(1);
    });

    test('Cycle Tracker: Deletion queues table hit_cycles', () async {
      final cycle = TrainingCycle(id: 'c1', name: 'C');
      cycleProv.setCyclesForTest([cycle]);
      when(() => cycleLocal.deleteCycle(any())).thenAnswer((_) async => {});
      when(() => cycleLocal.addToDeletionQueue(any(), any())).thenAnswer((_) async => {});
      when(() => cycleCloud.deleteCycle(any())).thenThrow(Exception("OFF"));
      await cycleProv.deleteCycle('c1');
      verify(() => cycleLocal.addToDeletionQueue('c1', 'hit_cycles')).called(1);
    });
  });

  group('SCENARIO B: HANDSHAKE RECOVERY (SYNC PUSH)', () {
    
    test('Hydration: Handshake pushes unsynced logs to cloud', () async {
      final unsynced = HydrationLog(id: 'off-1', amountMl: 10, amountOz: 1, timestamp: DateTime.now(), isSynced: 0);
      when(() => hydrationLocal.getUnsyncedCount()).thenAnswer((_) async => 1);
      when(() => hydrationLocal.getPendingDeletions()).thenAnswer((_) async => []);
      when(() => hydrationLocal.getUnsyncedLogs()).thenAnswer((_) async => [unsynced]);
      when(() => hydrationLocal.getUnsyncedSettings()).thenAnswer((_) async => null);
      
      when(() => hydrationCloud.insertLog(any())).thenAnswer((_) async => {});
      when(() => hydrationLocal.markLogSynced(any())).thenAnswer((_) async => {});
      
      // Stub loadData dependencies
      when(() => hydrationLocal.getSettings()).thenAnswer((_) async => HydrationSettings(userId: testUserId));
      when(() => hydrationLocal.getAllLogs()).thenAnswer((_) async => []);
      when(() => hydrationCloud.getSettings()).thenAnswer((_) async => null);
      when(() => hydrationCloud.getAllLogs()).thenAnswer((_) async => null);

      await hydrationProv.forceRefresh();

      verify(() => hydrationCloud.insertLog(unsynced)).called(greaterThan(0));
      verify(() => hydrationLocal.markLogSynced('off-1')).called(greaterThan(0));
    });

    test('Cycle Tracker: Handshake pushes unsynced settings with smartAutoDateEnabled to cloud', () async {
      final settings = CycleSettings(userId: testUserId, smartAutoDateEnabled: true, isSynced: 0);
      when(() => cycleLocal.getUnsyncedCount()).thenAnswer((_) async => 1);
      when(() => cycleLocal.getPendingDeletions()).thenAnswer((_) async => []);
      when(() => cycleLocal.getUnsyncedCycles()).thenAnswer((_) async => []);
      when(() => cycleLocal.getUnsyncedLogs()).thenAnswer((_) async => []);
      when(() => cycleLocal.getUnsyncedSettings()).thenAnswer((_) async => settings.toMap());
      
      when(() => cycleCloud.saveSettings(any())).thenAnswer((_) async => {});
      when(() => cycleLocal.markSettingsSynced()).thenAnswer((_) async => {});
      
      when(() => cycleLocal.getSettings()).thenAnswer((_) async => settings.toMap());
      when(() => cycleLocal.getAllCycles()).thenAnswer((_) async => []);
      when(() => cycleLocal.getAllLogs()).thenAnswer((_) async => []);
      when(() => cycleCloud.getSettings()).thenAnswer((_) async => null);
      when(() => cycleCloud.getAllCycles()).thenAnswer((_) async => null);
      when(() => cycleCloud.getAllLogs()).thenAnswer((_) async => null);

      await cycleProv.forceRefresh();

      verify(() => cycleCloud.saveSettings(any(that: predicate<Map<String, dynamic>>((map) => map['smart_auto_date_enabled'] == 1)))).called(greaterThan(0));
      verify(() => cycleLocal.markSettingsSynced()).called(greaterThan(0));
    });
  });
}

extension CycleTestHelper on CycleProvider {
  void setCyclesForTest(List<TrainingCycle> list) {
     // Reflection/Backdoor for test
  }
}
