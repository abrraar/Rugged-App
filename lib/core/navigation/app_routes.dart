class AppRoutes {
  AppRoutes._();

  // ── Auth ──────────────────────────────────────────────
  static const String root                  = '/';
  static const String signin                = '/signin';
  static const String login                 = '/login';
  static const String splash                = '/splash';
  static const String forgotPass            = '/forgot-password';
  static const String otp                   = '/otp';
  static const String resetPass             = '/reset-password';

  // ── Create Profile ────────────────────────────────────
  static const String createProfileCred     = '/create-profile/credentials';
  static const String createProfilePersonal = '/create-profile/personal';

  // ── Main App ──────────────────────────────────────────
  static const String home      = '/home';
  static const String exercises = '/exercises';
  static const String tracker   = '/tracker'; 
  static const String profile   = '/profile';
  static const String editProfile = '/profile/edit';
  static const String changeUsername = '/profile/change-username';
  
  // ── Settings ──────────────────────────────────────────
  static const String settings = '/settings';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsCycle = '/settings/cycle';
  static const String settingsCalorie = '/settings/calorie';
  static const String settingsHydration = '/settings/hydration';
  static const String settingsSupplement = '/settings/supplement';
  static const String settingsSleep = '/settings/sleep';
  static const String settingsBodyComp = '/settings/body-comp';
  static const String manageEmail = '/settings/manage-email';
  static const String changePassword = '/settings/change-password';
  static const String deleteAccount = '/settings/delete-account';
  static const String proUpgrade    = '/pro-upgrade';

  static const String authCallback = '/auth/callback';
  static const String verifyEmail  = '/verify-email';
  static const String verifySecondaryEmail = '/verify-secondary-email';
  static const String confirmEmail = '/confirm-email';

  static const String alarmRinging = '/alarm-ringing';
  static const String shareCycle = '/share/cycle';
  static const String shareMeal = '/share/meal';
  static const String shareSupplement = '/share/supplement';
  static const String shareStack = '/share/stack';
  static const String shareExercise = '/share/exercise';
  static const String cycleTracking = '/tracker/cycle';
  static const String calorieTracking = '/tracker/calorie';
  static const String supplementTracking = '/tracker/supplement';

}
