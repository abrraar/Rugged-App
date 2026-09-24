// test/integration_tests/test_helpers.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'package:rugged/core/providers/sync_provider.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:rugged/features/tracker/hydration/provider/hydration_provider.dart';
import 'package:rugged/features/tracker/sleep/provider/sleep_provider.dart';
import 'package:rugged/features/tracker/sleep/provider/sleep_alarm_provider.dart';
import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:rugged/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:rugged/features/exercise/provider/exercise_provider.dart';
import 'package:rugged/core/providers/ui_provider.dart';
import 'package:rugged/features/affirmation/provider/affirmation_provider.dart';
import 'package:rugged/core/providers/update_provider.dart';
import 'package:rugged/core/providers/ad_unlock_provider.dart';
import 'package:rugged/core/providers/iap_provider.dart';

Widget createTestApp({
  required Widget child,
  AuthProvider? authProvider,
  IAPProvider? iapProvider,
  ExerciseProvider? exerciseProvider,
  CycleProvider? cycleProvider,
}) {
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    minTextAdapt: true,
    splitScreenMode: true,
    builder: (context, _) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SyncProvider>(create: (_) => SyncProvider()),
          ChangeNotifierProvider<AuthProvider>(create: (_) => authProvider ?? AuthProvider()),
          ChangeNotifierProvider<SupplementProvider>(create: (_) => SupplementProvider()),
          ChangeNotifierProvider<HydrationProvider>(create: (_) => HydrationProvider()),
          ChangeNotifierProvider<SleepProvider>(create: (_) => SleepProvider()),
          ChangeNotifierProvider<SleepAlarmProvider>(create: (_) => SleepAlarmProvider()),
          ChangeNotifierProvider<CalorieProvider>(create: (_) => CalorieProvider()),
          ChangeNotifierProvider<BodyCompProvider>(create: (_) => BodyCompProvider()),
          ChangeNotifierProvider<CycleProvider>(create: (_) => cycleProvider ?? CycleProvider()),
          ChangeNotifierProvider<ExerciseProvider>(create: (_) => exerciseProvider ?? ExerciseProvider()),
          ChangeNotifierProvider<UiProvider>(create: (_) => UiProvider()),
          ChangeNotifierProvider<AffirmationProvider>(create: (_) => AffirmationProvider()),
          ChangeNotifierProvider<UpdateProvider>(create: (_) => UpdateProvider()),
          ChangeNotifierProvider<AdUnlockProvider>(create: (_) => AdUnlockProvider()),
          ChangeNotifierProvider<IAPProvider>(create: (_) => iapProvider ?? IAPProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(body: child),
        ),
      );
    },
  );
}
