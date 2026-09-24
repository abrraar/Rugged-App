// main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:rugged/core/constants/app_constants.dart';
import 'package:rugged/core/theme/app_picker_theme.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/tracker/hydration/provider/hydration_provider.dart';
import 'package:rugged/features/tracker/sleep/provider/sleep_provider.dart';
import 'package:rugged/features/tracker/sleep/provider/sleep_alarm_provider.dart';
import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:rugged/features/exercise/provider/exercise_provider.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/navigation/app_router.dart';
import 'package:rugged/core/services/notification_service.dart';
import 'package:rugged/core/services/connectivity_service.dart';
import 'package:rugged/core/services/deeplink_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alarm/alarm.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'core/ads/ad_service.dart';

import 'features/tracker/body_composition/provider/body_comp_provider.dart';
import 'features/affirmation/provider/affirmation_provider.dart';
import 'core/providers/ui_provider.dart';
import 'features/tracker/supplement/provider/supplement_provider.dart';
import 'core/providers/update_provider.dart';
import 'core/providers/sync_provider.dart';
import 'core/providers/ad_unlock_provider.dart';
import 'core/providers/iap_provider.dart';
import 'core/widgets/sync_status_overlay.dart';

void main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized(); // Ensure this is first

  await _initializeAdsWithConsent();
  
  // ELITE RELIABILITY: Add your phone's Hashed ID here to see ads on a real device
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: [
      "PASTE_YOUR_COPIED_ID_HERE", 
      // You can add more device IDs here later
    ]),
  );

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  // ELITE INITIALIZATION SEQUENCE
  AdService().loadInterstitialAd(); 
  await Alarm.init();
  await NotificationService().init();
  ConnectivityService().init();
  await DeepLinkService().init();

  // LOCK TO PORTRAIT MODE
  // Ensures the app stays in portrait even if auto-rotate is enabled
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SupplementProvider()),
        ChangeNotifierProvider(create: (_) => HydrationProvider()),
        ChangeNotifierProvider(create: (_) => SleepProvider()),
        ChangeNotifierProvider(create: (_) => SleepAlarmProvider()),
        ChangeNotifierProvider(create: (_) => CalorieProvider()),
        ChangeNotifierProvider(create: (_) => BodyCompProvider()),
        ChangeNotifierProvider(create: (_) => CycleProvider()),
        ChangeNotifierProvider(create: (_) => ExerciseProvider()),
        ChangeNotifierProvider(create: (_) => UiProvider()),
        ChangeNotifierProvider(create: (_) => AffirmationProvider()),
        ChangeNotifierProvider(create: (_) => UpdateProvider()),
        ChangeNotifierProvider(create: (_) => AdUnlockProvider()..loadUnlockState()),
        ChangeNotifierProvider(create: (_) => IAPProvider()),
      ],
      child: const AuthWrapper(child: MyApp()),
    ),
  );
}

Future<void> _initializeAdsWithConsent() async {
  final Completer<void> completer = Completer<void>();

  final params = ConsentRequestParameters();

  ConsentInformation.instance.requestConsentInfoUpdate(
    params,
    () async {
      await ConsentForm.loadAndShowConsentFormIfRequired(
        (formError) async {
          if (formError != null) {
            debugPrint("UMP Consent Form Error: ${formError.message}");
          }
          final canRequest = await ConsentInformation.instance.canRequestAds();
          if (canRequest) {
            await MobileAds.instance.initialize();
          }
          completer.complete();
        },
      );
    },
    (formError) {
      debugPrint("UMP Consent Info Update Error: ${formError.message}");
      completer.complete();
    },
  );

  return completer.future;
}

// Added an AuthWrapper to listen to auth changes and trigger DB initialization
class AuthWrapper extends StatefulWidget {
  final Widget child;
  const AuthWrapper({super.key, required this.child});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    
    // Initialize Alarms
    context.read<SleepAlarmProvider>().init();

    // Check for Updates
    context.read<UpdateProvider>().init();
    
    // Listen to Auth changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final user = data.session?.user;
      final suppProvider = Provider.of<SupplementProvider>(context, listen: false);
      final hydrationProvider = Provider.of<HydrationProvider>(context, listen: false);
      final sleepProvider = Provider.of<SleepProvider>(context, listen: false);
      final sleepAlarmProvider = Provider.of<SleepAlarmProvider>(context, listen: false);
      final calorieProvider = Provider.of<CalorieProvider>(context, listen: false);
      final bodyCompProvider = Provider.of<BodyCompProvider>(context, listen: false);
      final cycleProvider = Provider.of<CycleProvider>(context, listen: false);
      final exerciseProvider = Provider.of<ExerciseProvider>(context, listen: false);
      final uiProvider = Provider.of<UiProvider>(context, listen: false);
      final affirmationProvider = Provider.of<AffirmationProvider>(context, listen: false);

      if (user != null) {
        suppProvider.initializeForUser(user.id);
        hydrationProvider.initializeForUser(user.id);
        sleepProvider.initializeForUser(user.id);
        sleepAlarmProvider.initializeForUser(user.id);
        calorieProvider.initializeForUser(user.id);
        bodyCompProvider.initializeForUser(user.id);
        cycleProvider.initializeForUser(user.id);
        exerciseProvider.initializeForUser(user.id);
        uiProvider.initializeForUser(user.id);
        affirmationProvider.initializeForUser(user.id);
      } else {
        suppProvider.clearUserData();
        hydrationProvider.clearUserData();
        sleepProvider.clearUserData();
        calorieProvider.clearUserData();
        bodyCompProvider.clearUserData();
        cycleProvider.clearUserData();
        exerciseProvider.clearUserData();
        uiProvider.clearUserData();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) => MaterialApp.router(
        title: 'Rugged',
        debugShowCheckedModeBanner: false,
        routerConfig: appRouter,
        theme: AppPickerTheme.theme(context),
        builder: (context, routerChild) => Stack(
          children: [
            routerChild!,
            const SyncStatusOverlay(),
          ],
        ),
      ),
    );
  }
}
