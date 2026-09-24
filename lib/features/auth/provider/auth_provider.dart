import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/database/database_helper.dart';
import '../../profile/model/user_email.dart';
import '../../profile/data/profile_local_repository.dart';

import 'package:rugged/features/profile/model/profile_model.dart';
import 'package:rugged/core/services/connectivity_service.dart';

import 'package:rugged/core/providers/sync_provider.dart';

enum SignUpMode { email, username, both }

class AuthProvider with ChangeNotifier {
  static AuthProvider _instance = AuthProvider._internal();
  factory AuthProvider() => _instance;
  static void setMockInstance(AuthProvider mock) => _instance = mock;

  AuthProvider._internal() {
    _initRecoveryState();
    // Listen to auth changes automatically (e.g., sign in, sign out)
    _currentUser = _supabase.auth.currentUser;
    if (_currentUser != null) {
      _initializeProfileRepo(_currentUser!.id);
    }
    _setupAuthListener();
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() {
    if (_currentUser != null) {
      debugPrint("AuthProvider: Internet restored. Triggering profile sync...");
      _loadUserProfile();
      refreshEmails();
    }
  }

  SupabaseClient get _supabase => Supabase.instance.client;
  User? _currentUser;
  bool _isLoading = false;
  String? _pendingEmail;
  String? _pendingUsername;

  ProfileLocalRepository? _profileRepo;
  List<UserEmail> _userEmails = [];
  UserProfile? _userProfile;
  bool _isPasswordRecoveryMode = false;
  bool _isInitializing = true;
  bool _isProfileLoading = false;

  Timer? _globalCooldownTimer;
  int _emailCooldownSeconds = 0;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing || _isProfileLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailConfirmedAt != null;
  bool get isProfileComplete {
    if (_currentUser == null) return false;
    
    // ELITE ONBOARDING CHECK:
    // We strictly look for the 'onboarding_completed' flag in user metadata.
    // This is set ONLY when the user hits 'Confirm' on the profile screen.
    // This prevents database-level timestamps from accidentally skipping onboarding.
    final metadata = _currentUser!.userMetadata;
    return metadata?['onboarding_completed'] == true;
  }
  bool get isPasswordRecoveryMode => _isPasswordRecoveryMode;
  bool get isUsernameOnly => _currentUser?.email?.endsWith('@internal.affulabs.com') ?? false;

  /// ELITE SECURITY CHECK: Verifies if the user is a Google Auth user.
  bool get isGoogleUser {
    if (_currentUser == null) return false;
    final providers = _currentUser!.appMetadata['providers'];
    return providers is List && providers.contains('google');
  }

  /// ELITE SECURITY CHECK: Verifies if the user has set a unique username.
  bool get hasUsername {
    if (_currentUser == null) return false;
    final userMeta = _currentUser!.userMetadata;
    
    // ELITE SOURCE OF TRUTH: 
    // We only trust the 'has_username' flag in metadata.
    // We ignore the database 'username' column because it may contain 
    // an auto-generated email prefix from Supabase.
    final bool hasFlag = userMeta?['has_username'] == true;
    
    debugPrint("AuthProvider: hasUsername check -> $hasFlag (Flag: ${userMeta?['has_username']})");
    return hasFlag;
  }

  String get username {
    if (!hasUsername) return '';

    // If flag is true, we can safely return the chosen username from DB or Meta
    final result = _userProfile?.username ?? _currentUser?.userMetadata?['username'] ?? '';
    return result;
  }

  /// ELITE SECURITY CHECK: Verifies if the user has a password set.
  /// If they only have OAuth identities (like Google), this returns false.
  /// ELITE SECURITY CHECK: Verifies if the user has a password set.
  bool get hasPassword {
    if (_currentUser == null) {
      debugPrint("AuthProvider: hasPassword -> FALSE (No User)");
      return false;
    }
    
    final identities = _currentUser!.identities;
    final providers = _currentUser!.appMetadata['providers'];
    final userMeta = _currentUser!.userMetadata;

    debugPrint("AuthProvider: Checking Password Status...");
    debugPrint(" - Identities: ${identities?.map((id) => id.provider).toList()}");
    debugPrint(" - AppMetadata Providers: $providers");
    debugPrint(" - UserMetadata: $userMeta");

    // 1. Check Custom Metadata Flag (ELITE INSTANT UPDATE)
    if (userMeta?['has_app_password'] == true) {
      debugPrint(" - Result: TRUE (via has_app_password flag)");
      return true;
    }

    // 2. Check identities list (Standard fallback)
    if (identities != null && identities.any((id) => id.provider == 'email')) {
      debugPrint(" - Result: TRUE (via identities)");
      return true;
    }

    // 3. Check app_metadata providers list (Robust fallback)
    if (providers is List && (providers.contains('email') || providers.contains('password'))) {
      debugPrint(" - Result: TRUE (via appMetadata)");
      return true;
    }
    
    debugPrint(" - Result: FALSE");
    return false;
  }

  int get emailCooldownSeconds => _emailCooldownSeconds;
  String? get pendingEmail => _pendingEmail;
  String? get pendingUsername => _pendingUsername;

  String get displayName => _userProfile?.fullName ?? _currentUser?.userMetadata?['full_name'] ?? 'User';
  double? get height => _userProfile?.height ?? (_currentUser?.userMetadata?['height'] as num?)?.toDouble();
  String? get gender => _userProfile?.gender ?? _currentUser?.userMetadata?['gender']?.toString();
  DateTime? get birthday => _userProfile?.birthday ?? (_currentUser?.userMetadata?['birthday'] != null ? DateTime.tryParse(_currentUser?.userMetadata?['birthday'].toString() ?? "") : null);

  List<UserEmail> get userEmails => _userEmails;
  UserProfile? get userProfile => _userProfile;

  /// ELITE PRO CHECK: Verifies if the user has active Pro entitlements.
  bool get isPro => _userProfile?.isPro ?? false;

  String get activeProTierName {
    final raw = _userProfile?.proPlanTier;
    if (raw == null || raw.isEmpty) return '12-Month Pro Pass';
    if (raw == '1-Year Pro Pass') return '12-Month Pro Pass';
    return raw;
  }

  DateTime get activeProStartDate => _userProfile?.proStartDate ?? (_userProfile?.updatedAt ?? DateTime.now().subtract(const Duration(days: 30)));

  DateTime get activeProExpiryDate => _userProfile?.proExpiryDate ?? (
    activeProTierName.contains('1-Month') ? activeProStartDate.add(const Duration(days: 30)) :
    activeProTierName.contains('3-Month') ? activeProStartDate.add(const Duration(days: 90)) :
    activeProTierName.contains('6-Month') ? activeProStartDate.add(const Duration(days: 180)) :
    activeProStartDate.add(const Duration(days: 365))
  );

  void cancelPasswordRecovery() {
    if (_isPasswordRecoveryMode) {
      _isPasswordRecoveryMode = false;
      notifyListeners();
    }
  }

  void _startGlobalCooldown() async {
    final expiryTime = DateTime.now().add(const Duration(minutes: 2)).millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('global_email_cooldown_expiry', expiryTime);
    
    _emailCooldownSeconds = 120;
    _resumeGlobalCooldown();
  }

  void _resumeGlobalCooldown() {
    _globalCooldownTimer?.cancel();
    _globalCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emailCooldownSeconds <= 0) {
        _emailCooldownSeconds = 0;
        timer.cancel();
      } else {
        _emailCooldownSeconds--;
      }
      notifyListeners();
    });
  }

  /// ELITE COOLDOWN CHECK: Only enforces cooldown for real email registrations.
  /// Shadow emails (username-only) bypass the wait.
  bool isCooldownActive(SignUpMode mode) {
    if (mode == SignUpMode.username) return false;
    return _emailCooldownSeconds > 0;
  }

  Future<void> _initRecoveryState() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check Global Cooldown
    final expiryTime = prefs.getInt('global_email_cooldown_expiry') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (expiryTime > now) {
      _emailCooldownSeconds = (expiryTime - now) ~/ 1000;
      _resumeGlobalCooldown();
    }

    // 2. Check Recovery Lockdown
    final bool wasInRecovery = prefs.getBool('is_in_recovery_lockdown') ?? false;
    
    if (wasInRecovery) {
      debugPrint("AuthProvider: Unfinished Recovery Session detected. Sanitizing...");
      // Security Invalidation: Clear session and flag immediately.
      await signOut();
      await prefs.remove('is_in_recovery_lockdown');
    }
    
    _isInitializing = false;
    notifyListeners();
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      _currentUser = data.session?.user;
      
      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint("AuthProvider: Password recovery mode ACTIVATED");
        _isPasswordRecoveryMode = true;
        
        // PERSISTENCE FIX: Save recovery status to local storage so it survives app restarts
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_in_recovery_lockdown', true);
      } else if (data.event == AuthChangeEvent.signedOut) {
        _isPasswordRecoveryMode = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('is_in_recovery_lockdown');
      }

      if (_currentUser != null) {
        // ONLY re-initialize if the user ID has changed to prevent "ghost" redirects during token refreshes
        if (_profileRepo == null || _profileRepo!.userId != _currentUser!.id) {
          _initializeProfileRepo(_currentUser!.id);
        }
      } else {
        _profileRepo = null;
        _userProfile = null; // Clear profile on sign out
        _userEmails = [];
      }
      notifyListeners();
    });
  }

  void _initializeProfileRepo(String userId) async {
    _userProfile = null; // Reset profile state before loading new user data
    _isProfileLoading = true;
    notifyListeners();
    
    _profileRepo = ProfileLocalRepository(userId: userId);
    await Future.wait([
      _loadUserEmails(),
      _loadUserProfile(),
    ]);
    
    _isProfileLoading = false;
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    if (_profileRepo == null) return;

    final syncProv = SyncProvider();
    syncProv.startFeatureSync();

    try {
      // 1. Load Local
      _userProfile = await _profileRepo!.getProfile();

      final count = await _profileRepo!.getUnsyncedCount();
      syncProv.addTotalItems(count);

      // 2. MANDATORY: Push local offline changes BEFORE pulling from cloud
      if (_userProfile != null && _userProfile!.isSynced == 0) {
        try {
          final Map<String, dynamic> profileUpdate = {
            'full_name': _userProfile!.fullName,
            'username': _userProfile!.username,
            'height': _userProfile!.height,
            'birthday': _userProfile!.birthday?.toIso8601String().split('T')[0], // Use YYYY-MM-DD for consistency
            'gender': _userProfile!.gender,
            'weight': _userProfile!.weight,
          };
          await _supabase.from('profiles').upsert({'id': _userProfile!.id, ...profileUpdate});
          await _profileRepo!.saveProfile(_userProfile!.copyWith(isSynced: 1));
          
          // Update memory and UI after successful push
          _userProfile = _userProfile!.copyWith(isSynced: 1);
          notifyListeners();
          syncProv.incrementCompleted();
        } catch (e) {
          debugPrint("AuthProvider: Background profile sync failed: $e");
        }
      }

      // 3. Load from Supabase Profiles Table
      try {
        final cloudData = await _supabase.from('profiles').select().eq('id', _currentUser!.id).maybeSingle();
        if (cloudData != null) {
          debugPrint("AuthProvider: Cloud birthday data: ${cloudData['birthday']}");
          // CRITICAL: Use isFromCloud: true to protect local dirty state
          await _profileRepo!.saveProfile(UserProfile.fromMap(cloudData), isFromCloud: true);
          
          // Re-load to get final reconciled state
          _userProfile = await _profileRepo!.getProfile();
          notifyListeners();
        }
      } catch (e) {
        debugPrint("Cloud profile load failed: $e");
      }
    } finally {
      syncProv.endFeatureSync();
    }
    notifyListeners();
  }

  Future<void> forceRefreshProfile() async {
    if (_currentUser == null) return;
    _setLoading(true);
    try {
      await _loadUserProfile();
      await refreshEmails();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadUserEmails() async {
    if (_profileRepo == null) return;
    final List<UserEmail> localEmails = await _profileRepo!.getEmails();

    final Map<String, UserEmail> emailMap = {};
    for (var e in localEmails) {
      emailMap[e.email.toLowerCase()] = e;
    }

    // Always ensure the current primary auth email is in the list (unless it's a shadow email)
    if (_currentUser?.email != null) {
      final String primaryEmail = _currentUser!.email!.toLowerCase();
      final bool isShadow = primaryEmail.endsWith('@internal.affulabs.com');
      
      if (!isShadow && !emailMap.containsKey(primaryEmail)) {
        final primary = UserEmail(email: _currentUser!.email!, isVerified: true);
        await _profileRepo!.insertEmail(primary);
        emailMap[primaryEmail] = primary;
      }
    }

    // Ensure primary email is always first in the list
    final List<UserEmail> sortedList = emailMap.values.toList();
    sortedList.sort((a, b) {
      final bool aIsPrimary = a.email.toLowerCase() == _currentUser?.email?.toLowerCase();
      final bool bIsPrimary = b.email.toLowerCase() == _currentUser?.email?.toLowerCase();
      if (aIsPrimary) return -1;
      if (bIsPrimary) return 1;
      return 0;
    });

    _userEmails = sortedList;
    notifyListeners();
  }

  Future<void> refreshEmails() async {
    if (_profileRepo == null || _currentUser == null) return;

    // 1. Refresh Auth User (Check verification status)
    await refreshUser();

    // 2. MANDATORY: Push local offline changes BEFORE pulling from cloud
    try {
      final localEmails = await _profileRepo!.getEmails();
      for (var local in localEmails) {
        if (local.isSynced == 0) {
          // Note: OTP verification codes aren't easily "pushed" back if lost, 
          // but we can at least ensure the record exists.
          await _supabase.from('user_emails').upsert(local.toMap()..remove('is_synced'));
          await _profileRepo!.insertEmail(local.copyWith(isSynced: 1));
        }
      }
    } catch (e) {
      debugPrint("AuthProvider: Email upload sync failed: $e");
    }

    // ELITE SYNC: To ensure deleted items are removed, we perform a clean sync.
    try {
      final cloudData = await _supabase
          .from('user_emails')
          .select()
          .eq('user_id', _currentUser!.id);

      final List<UserEmail> cloudEmails = cloudData
          .map((d) => UserEmail.fromMap(d))
          .where((e) => !e.email.toLowerCase().endsWith('@internal.affulabs.com')) // Hide Shadow Emails
          .toList();
      
      final cloudIds = cloudEmails.map((e) => e.id).toSet();
      
      final localEmails = await _profileRepo!.getEmails();
      
      // Remove locals that aren't in cloud (except perhaps the primary if handled differently)
      for (var local in localEmails) {
        if (!cloudIds.contains(local.id)) {
          // If it's not the primary auth email, delete it locally as it's gone from cloud
          if (local.email.toLowerCase() != _currentUser!.email?.toLowerCase()) {
            await _profileRepo!.deleteEmail(local.id);
          }
        }
      }

      // Upsert cloud records into local
      for (var emailObj in cloudEmails) {
        // AUTO-SYNC: If this email matches the current auth email and we are verified 
        // in the auth session, update our custom table.
        if (emailObj.email.toLowerCase() == _currentUser!.email?.toLowerCase() && isEmailVerified) {
          if (!emailObj.isVerified) {
            final verifiedObj = emailObj.copyWith(isVerified: true);
            await _profileRepo!.insertEmail(verifiedObj);
            await _supabase.from('user_emails').update({'is_verified': true}).eq('id', emailObj.id);
          }
        } else {
          await _profileRepo!.insertEmail(emailObj);
        }
      }
        } catch (e) {
      debugPrint("AuthProvider: Email sync failed: $e");
    }

    // 3. Reload local list
    await _loadUserEmails();
  }

  Future<void> addEmail(String email) async {
    if (_profileRepo == null) return;
    
    // ENFORCE LIMIT: Max 3 emails
    if (_userEmails.length >= 3) {
      throw "MAXIMUM EMAIL LIMIT REACHED (3)";
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (_userEmails.any((e) => e.email.toLowerCase() == normalizedEmail)) {
      return;
    }

    // 1. Generate a 6-digit OTP
    final String otp = (100000 + (DateTime.now().millisecond * 899999) ~/ 1000).toString();
    debugPrint("DEBUG: Generated OTP for $normalizedEmail: $otp");

    final newEmail = UserEmail(email: email.trim(), isVerified: false, isSynced: 0);
    await _profileRepo!.insertEmail(newEmail);

    // 2. Save to the cloud table for persistence
    try {
      await _supabase.from('user_emails').insert({
        'id': newEmail.id,
        'user_id': _currentUser!.id,
        'email': newEmail.email,
        'is_verified': false,
        'verification_code': otp,
      });
      await _profileRepo!.insertEmail(newEmail.copyWith(isSynced: 1));
    } catch (e) {
      debugPrint("Supabase email save failed (offline?): $e");
    }

    // 3. DIRECT INVOCATION: Trigger the email sender immediately
    try {
      debugPrint("AuthProvider: Invoking Edge Function 'secondary-email-otp'...");
      final response = await _supabase.functions.invoke(
        'secondary-email-otp', 
        body: {'email': email.trim(), 'otp': otp}
      );
      debugPrint("AuthProvider: Edge Function Response Status: ${response.status}");
      
      // SUCCESS: Start global cooldown
      _startGlobalCooldown();
    } catch (e) {
      debugPrint("AuthProvider: DIRECT Edge Function trigger failed: $e");
    }
    
    await _loadUserEmails();
  }

  Future<void> resendSecondaryOTP(String email) async {
    if (_emailCooldownSeconds > 0) throw "COOLDOWN ACTIVE";
    _setLoading(true);
    try {
      // 1. Generate new OTP
      final String otp = (100000 + (DateTime.now().millisecond * 899999) ~/ 1000).toString();
      
      // 2. Update code in database
      await _supabase.from('user_emails').update({'verification_code': otp}).eq('email', email.trim());
      
      // 3. Trigger Email
      await _supabase.functions.invoke('secondary-email-otp', body: {'email': email.trim(), 'otp': otp});
      
      debugPrint("AuthProvider: OTP Resent to $email: $otp");
      _startGlobalCooldown();
    } catch (e) {
      debugPrint("AuthProvider: Resend failed: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifySecondaryEmailOTP(String email, String enteredCode) async {
    _setLoading(true);
    debugPrint("AuthProvider: Attempting to verify OTP for $email");
    try {
      final response = await _supabase
          .from('user_emails')
          .select('id, verification_code')
          .eq('user_id', _currentUser!.id)
          .eq('email', email.trim())
          .maybeSingle();

      if (response != null && response['verification_code'] == enteredCode) {
        debugPrint("AuthProvider: OTP Match found. Updating Supabase...");
        
        // 1. Update Cloud Status (Use select() to verify it actually happened)
        final updateResult = await _supabase
            .from('user_emails')
            .update({'is_verified': true})
            .eq('id', response['id'])
            .select();
        
        debugPrint("AuthProvider: Supabase Update Result: $updateResult");

        if (updateResult.isNotEmpty) {
          // 2. Update Local Repository immediately
          final currentEmails = await _profileRepo!.getEmails();
          final match = currentEmails.firstWhere((e) => e.email.toLowerCase() == email.trim().toLowerCase());
          await _profileRepo!.insertEmail(match.copyWith(isVerified: true));
          
          debugPrint("AuthProvider: Local Update Successful. Refreshing...");
          
          // 3. Refresh and reload to ensure UI is in sync
          await refreshEmails();
          _setLoading(false);
          return true;
        } else {
          debugPrint("AuthProvider: Supabase Update failed (no rows affected)");
        }
      } else {
        debugPrint("AuthProvider: OTP Mismatch or record not found. Expected: ${response?['verification_code']}, Entered: $enteredCode");
      }
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint("AuthProvider: OTP Verification ERROR: $e");
      _setLoading(false);
      return false;
    }
  }

  Future<void> removeEmail(String id) async {
    if (_profileRepo == null || _userEmails.length <= 1) return;
    await _profileRepo!.deleteEmail(id);

    try {
      await _supabase.from('user_emails').delete().eq('id', id);
    } catch (e) {
      debugPrint("Supabase email delete failed: $e");
    }

    await _loadUserEmails();
  }

  Future<void> promoteToPrimaryEmail(String newEmail) async {
    if (_emailCooldownSeconds > 0) throw "COOLDOWN ACTIVE";
    _setLoading(true);
    try {
      // This triggers Supabase's secure email change flow.
      // Confirmation links will be sent to both old and new addresses.
      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail.trim()),
        emailRedirectTo: kIsWeb ? null : 'https://affulabs.com/rugged/app/email_change',
      );
      _startGlobalCooldown();
    } catch (e) {
      debugPrint("Promotion failed: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> verifyEmail(String id) async {
    if (_profileRepo == null) return;
    final email = _userEmails.firstWhere((e) => e.id == id);
    final updated = email.copyWith(isVerified: true);
    await _profileRepo!.updateEmail(updated);

    try {
      await _supabase.from('user_emails').update({'is_verified': true}).eq('id', id);
    } catch (e) {
      debugPrint("Supabase email verify failed: $e");
    }

    await _loadUserEmails();
  }

  // ==========================================
  // USERNAME MANAGEMENT
  // ==========================================
  Future<bool> checkUsernameAvailability(String username) async {
    if (username.isEmpty) return false;

    _setLoading(true);
    debugPrint("AuthProvider: Checking availability for username: '$username'");
    try {
      final response = await _supabase
          .from('profiles') 
          .select('username')
          .eq('username', username)
          .maybeSingle();

      final isAvailable = response == null;
      debugPrint("AuthProvider: Username '$username' availability: $isAvailable");
      _setLoading(false);
      return isAvailable;
    } catch (e) {
      debugPrint("AuthProvider: Username check failed: $e. Falling back to optimistic True.");
      _setLoading(false);
      return true;
    }
  }

  // ==========================================
  // SIGN UP METHOD
  // ==========================================
  Future<void> signUp(String email, String password, {String? username}) async {
    if (_emailCooldownSeconds > 0) {
      debugPrint("AuthProvider: Sign up rejected - Cooldown active ($emailCooldownSeconds s)");
      throw "COOLDOWN ACTIVE";
    }
    _setLoading(true);
    _pendingEmail = email;
    _pendingUsername = username;
    
    debugPrint("AuthProvider: Initiating sign up for $email (Username: $username)");
    
    try {
      // 1. Prepare Metadata (Only add flag if username is actually provided)
      final Map<String, dynamic> metadata = {};
      if (username != null && username.isNotEmpty) {
        metadata['username'] = username;
        metadata['has_username'] = true; // ELITE INSTANT FLAG
      }

      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata.isNotEmpty ? metadata : null,
        emailRedirectTo: kIsWeb ? null : 'https://affulabs.com/rugged/app/signup',
      );

      _currentUser = response.user;

      // If identities is empty, it means the user already exists (Supabase security masking)
      if (response.user?.identities != null && response.user!.identities!.isEmpty) {
        debugPrint("AuthProvider: Throwing duplicate email error (Identities is empty)");
        throw "THIS EMAIL IS ALREADY REGISTERED. PLEASE LOG IN.";
      }

      // ELITE SHADOW EMAIL AUTO-LOGIN:
      // If this is a shadow email, we expect it to be auto-verified by the DB trigger.
      // If the session is missing, we attempt a quick signIn to capture the session.
      if (email.endsWith('@internal.affulabs.com') && response.session == null) {
        debugPrint("AuthProvider: Shadow email detected. Attempting immediate sign-in...");
        try {
          final signinResponse = await _supabase.auth.signInWithPassword(email: email, password: password);
          _currentUser = signinResponse.user;
        } catch (e) {
          debugPrint("AuthProvider: Shadow auto-signin failed (Verification trigger might be missing or old domain): $e");
        }
      }

      if (_currentUser != null && response.session != null) {
        debugPrint("AuthProvider: User already verified or auto-confirmed.");
      } else {
        debugPrint("AuthProvider: Confirmation email should have been sent to $email");
      }

      // --- INITIAL PROFILE CREATION ---
      if (_currentUser != null) {
        try {
          await _supabase.from('profiles').upsert({
            'id': _currentUser!.id,
            'email': _currentUser!.email,
            'username': username,
          });
          debugPrint("AuthProvider: Initial profile record created successfully for $username");
          
          // Re-initialize to load the fresh profile
          _initializeProfileRepo(_currentUser!.id);
        } catch (e) {
          debugPrint("AuthProvider: Initial profile upsert failed: $e");
        }
      }

      _startGlobalCooldown();
    } catch (e) {
      debugPrint("AuthProvider: Sign up error: $e");
      if (e is AuthException) {
        debugPrint("AuthProvider: AuthException details: ${e.message}, Status: ${e.statusCode}");
      }
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // ==========================================
  // SIGN IN METHOD
  // ==========================================
  Future<void> signIn(String identifier, String password) async {
    _setLoading(true);
    String email = identifier;
    try {
      // 1. Resolve Username to Email if necessary
      if (!identifier.contains('@')) {
        debugPrint("AuthProvider: Resolving email for username: $identifier");

        try {
          final List<dynamic> response = await _supabase.rpc(
              'get_email_by_username',
              params: {'input_username': identifier}
          );

          if (response.isNotEmpty) {
            email = response.first['resolved_email'];
            debugPrint("AuthProvider: Resolved to email: $email");
          } else {
            // FALLBACK: If RPC returns empty, try the shadow email format directly
            debugPrint("AuthProvider: Username not found in profiles. Trying shadow email fallback...");
            email = '$identifier@internal.affulabs.com';
          }
        } catch (e) {
          debugPrint("AuthProvider: RPC resolution failed. Using shadow email fallback...");
          email = '$identifier@internal.affulabs.com';
        }
      }

      // 2. Perform Native Supabase Auth
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);

      _currentUser = response.user;
      if (_currentUser != null) {
        _initializeProfileRepo(_currentUser!.id);

        // Ensure email is in profiles table after successful login (Auto-healing)
        _syncEmailToProfile();
      }
      notifyListeners();
    } on AuthException catch (e) {
      _setLoading(false);
      final message = e.message.toLowerCase();
      if (message.contains("email not confirmed")) {
        if (email.endsWith('@internal.affulabs.com')) {
          throw "SHADOW EMAIL NOT AUTO-VERIFIED. PLEASE ENSURE YOUR SUPABASE DATABASE TRIGGER IS UPDATED TO THE NEW DOMAIN (@internal.affulabs.com).";
        }
        throw "EMAIL VERIFICATION REQUIRED FOR PASSWORD LOGIN. CHECK YOUR INBOX.";
      }
      rethrow;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  /// Internal helper to keep profiles.email column updated
  Future<void> _syncEmailToProfile() async {
    if (_currentUser?.email == null) return;
    try {
      await _supabase.from('profiles').update({'email': _currentUser!.email}).eq('id', _currentUser!.id);
    } catch (e) {
      debugPrint("AuthProvider: Email sync to profile failed: $e");
    }
  }

  Future<void> refreshUser() async {
    try {
      debugPrint("AuthProvider: Refreshing user data from server...");
      // ELITE USER SYNC: We use getUser() to fetch the fresh user record 
      // directly from the server, which includes updated identities.
      final response = await _supabase.auth.getUser();
      _currentUser = response.user;
      debugPrint("AuthProvider: Server refresh complete. New identities: ${_currentUser?.identities?.map((id) => id.provider).toList()}");
      notifyListeners();
    } catch (e) {
      debugPrint("Error refreshing user: $e");
    }
  }

  // ==========================================
  // SIGN OUT METHOD
  // ==========================================
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _supabase.auth.signOut();
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================
  // DELETE ACCOUNT METHOD (PLAY STORE COMPLIANCE)
  // ==========================================
  Future<void> deleteAccount() async {
    final userId = _currentUser?.id;
    if (userId == null) return;

    _setLoading(true);
    try {
      // 1. DELETE FROM CLOUD
      // We attempt to call a database function to purge all records including the Auth user.
      try {
        await _supabase.rpc('delete_user_account');
      } catch (e) {
        debugPrint("AuthProvider: Cloud RPC delete failed: $e");
        // Fallback: Delete from public profiles table
        await _supabase.from('profiles').delete().eq('id', userId);
      }

      // 2. CLEAR LOCAL DATABASE FILE
      await DatabaseHelper.instance.deleteUserDatabase(userId);
      
      // 3. WIPE ALL LOCAL SETTINGS
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 4. FINALIZE SIGN OUT
      await signOut();
      
    } catch (e) {
      debugPrint("AuthProvider: CRITICAL DELETE ERROR: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resendOTP(String email, {bool isRecovery = false}) async {
    if (_emailCooldownSeconds > 0) {
      debugPrint("AuthProvider: Resend rejected - Cooldown active");
      throw "COOLDOWN ACTIVE";
    }
    _setLoading(true);
    debugPrint("AuthProvider: Resending ${isRecovery ? 'recovery' : 'signup'} email to $email");
    try {
      await _supabase.auth.resend(
        type: isRecovery ? OtpType.recovery : OtpType.signup,
        email: email,
        emailRedirectTo: kIsWeb ? null : (isRecovery ? 'https://affulabs.com/rugged/app/reset-password' : 'https://affulabs.com/rugged/app/confirm-email'),
      );
      debugPrint("AuthProvider: Resend call to Supabase successful for $email");
      _startGlobalCooldown();
    } catch (e) {
      debugPrint("AuthProvider: Resend failed: $e");
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // ==========================================
  // PASSWORD RECOVERY / CHANGE
  // ==========================================
  Future<bool> verifyCurrentPassword(String password) async {
    final email = _currentUser?.email;
    if (email == null) return false;

    _setLoading(true);
    try {
      // Attempt to sign in again with current email and the provided password to verify it
      await _supabase.auth.signInWithPassword(email: email, password: password);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

  Future<void> sendPasswordResetEmail(String email, {String? source}) async {
    if (_emailCooldownSeconds > 0) throw "COOLDOWN ACTIVE";
    _setLoading(true);
    debugPrint("AuthProvider: Checking if email $email is registered before reset...");
    try {
      // 1. Verify the email exists in our records (Primary Email check)
      final response = await _supabase
          .from('profiles')
          .select('email')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();

      if (response == null) {
        debugPrint("AuthProvider: RESET REJECTED. Email $email not found in profiles.");
        throw "THIS EMAIL IS NOT REGISTERED AS A PRIMARY ACCOUNT";
      }

      debugPrint("AuthProvider: Email verified. Sending reset link with source: $source...");

      // 2. Proceed with Supabase Reset
      // We append the source parameter to the redirectTo URL
      final String redirectUrl = source != null 
          ? 'https://affulabs.com/rugged/app/reset-password?source=$source'
          : 'https://affulabs.com/rugged/app/reset-password';

      await _supabase.auth.resetPasswordForEmail(
        email.trim(), 
        redirectTo: kIsWeb ? null : redirectUrl,
      );
      
      _startGlobalCooldown();
    } catch (e) {
      debugPrint("AuthProvider: Password reset request failed: $e");
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // ==========================================
  // PASSWORD RECOVERY / SIGNUP: VERIFY OTP TOKENS
  // ==========================================
  Future<void> verifyOTPCode(String email, String token, {bool isRecovery = false}) async {
    final sw = Stopwatch()..start();
    debugPrint("AuthProvider: [0ms] verifyOTPCode START for $email");
    _setLoading(true);
    
    try {
      debugPrint("AuthProvider: [${sw.elapsedMilliseconds}ms] Calling Supabase verifyOTP...");
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: isRecovery ? OtpType.recovery : OtpType.signup,
      );
      debugPrint("AuthProvider: [${sw.elapsedMilliseconds}ms] Supabase verifyOTP SUCCESS.");

      _currentUser = response.user;

      // ELITE OPTIMIZATION: We trigger the secondary tasks in the background
      // so the user can transition to the next screen immediately.
      if (!isRecovery && _currentUser != null) {
        final userId = _currentUser!.id;
        final userEmail = _currentUser!.email;
        final pendingUsername = _pendingUsername;

        debugPrint("AuthProvider: [${sw.elapsedMilliseconds}ms] Triggering background profile seeding...");
        
        // We DO NOT 'await' this. We let it run in the background.
        unawaited(() async {
          try {
            await _supabase.from('profiles').upsert({
              'id': userId,
              'email': userEmail,
              'username': ?pendingUsername,
            });

            if (pendingUsername != null) {
              await _supabase.auth.updateUser(UserAttributes(
                data: {
                  'username': pendingUsername,
                  'has_username': true,
                }
              ));
            }
            
            await refreshUser();
            debugPrint("AuthProvider: [BG] Background tasks COMPLETE.");
          } catch (e) {
            debugPrint("AuthProvider: [BG] ERROR in background tasks: $e");
          }
        }());
      }

      // ONLY clear pending data after we are 100% sure we've refreshed and notified
      _pendingEmail = null;
      _pendingUsername = null;
      
      // Reset loading BEFORE notifying to unlock the UI
      _setLoading(false);
      
      // We notify listeners immediately after verifyOTP so the Router sees 'isAuthenticated'
      debugPrint("AuthProvider: [${sw.elapsedMilliseconds}ms] Notifying listeners for immediate transition.");
      notifyListeners();

      return; // Exit early to avoid the finally block re-triggering notification

    } catch (e) {
      debugPrint("AuthProvider: [${sw.elapsedMilliseconds}ms] ERROR in verifyOTPCode: $e");
      _setLoading(false);
      rethrow;
    } finally {
      // Ensure loading is false, but we handled the success case specifically above
      if (_isLoading) _setLoading(false);
      sw.stop();
      debugPrint("AuthProvider: [FINAL] verifyOTPCode method finished in ${sw.elapsedMilliseconds}ms.");
    }
  }

  // ==========================================
  // PASSWORD RECOVERY: UPDATE TO NEW PASSWORD
  // ==========================================
  Future<void> updateUserPassword(String newPassword) async {
    _setLoading(true);
    debugPrint("AuthProvider: Initiating password update with has_app_password flag...");
    try {
      // 1. Update password AND set a metadata flag for instant UI detection
      final response = await _supabase.auth.updateUser(UserAttributes(
        password: newPassword,
        data: {'has_app_password': true}, // ELITE INSTANT FLAG
      ));
      
      _currentUser = response.user;
      debugPrint("AuthProvider: Update response received. Metadata: ${_currentUser?.userMetadata}");
      
      // 2. Refresh local state
      await refreshUser();
      
      _isPasswordRecoveryMode = false;
      notifyListeners();
    } catch (e) {
      debugPrint("AuthProvider: Password update FAILED: $e");
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  Future<void> updateUserProfile({String? name, String? username, double? height, Map<String, dynamic>? extraMetadata}) async {
    _setLoading(true);
    try {
      final user = _currentUser ?? _supabase.auth.currentUser;
      if (user == null) throw "USER SESSION NOT FOUND";

      final String userId = user.id;
      final String? userEmail = user.email;
      final now = DateTime.now();

      // 1. Prepare Database Update (Strictly table columns only)
      final Map<String, dynamic> dbUpdate = {};
      if (name != null) dbUpdate['full_name'] = name;
      if (username != null) dbUpdate['username'] = username;
      if (height != null) dbUpdate['height'] = height;
      if (userEmail != null) dbUpdate['email'] = userEmail;

      if (extraMetadata != null) {
        if (extraMetadata['birthday'] != null) {
          final bday = DateTime.tryParse(extraMetadata['birthday']);
          if (bday != null) {
            dbUpdate['birthday'] = bday.toIso8601String().split('T')[0];
          }
        }
        if (extraMetadata['gender'] != null) dbUpdate['gender'] = extraMetadata['gender'];
        if (extraMetadata['weight'] != null) dbUpdate['weight'] = extraMetadata['weight'];
      }

      // 2. Prepare Auth Metadata Update (For instant UI flags)
      final Map<String, dynamic> metaUpdate = {
        'onboarding_completed': true,
      };
      if (username != null) metaUpdate['has_username'] = true;

      // 3. OPTIMISTIC LOCAL SAVE (isSynced = 0)
      final currentLocal = await _profileRepo?.getProfile();
      final updatedLocal = UserProfile(
        id: userId,
        fullName: name ?? currentLocal?.fullName,
        username: username ?? currentLocal?.username,
        height: height ?? currentLocal?.height,
        weight: extraMetadata?['weight'] ?? currentLocal?.weight,
        gender: extraMetadata?['gender'] ?? currentLocal?.gender,
        birthday: extraMetadata?['birthday'] != null ? DateTime.tryParse(extraMetadata!['birthday']) : currentLocal?.birthday,
        isSynced: 0,
        updatedAt: now,
      );
      await _profileRepo?.saveProfile(updatedLocal);
      _userProfile = updatedLocal;
      notifyListeners();

      // 4. PUSH TO CLOUD
      // A. Update Auth Metadata first (Flags)
      await _supabase.auth.updateUser(UserAttributes(data: metaUpdate));

      // B. Update Profiles Table (Data)
      await _supabase.from('profiles').upsert({'id': userId, ...dbUpdate});
      
      // 5. MARK SYNCED
      await _profileRepo?.saveProfile(updatedLocal.copyWith(isSynced: 1));
      _userProfile = updatedLocal.copyWith(isSynced: 1);

      notifyListeners();
    } catch (e) {
      debugPrint("Profile update failed: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================
  // ENABLE PRO ACCESS (PRO UPGRADE)
  // ==========================================
  Future<void> enableProAccess({String tier = '1-Year Pro Pass', int durationDays = 365}) async {
    final userId = _currentUser?.id;
    if (userId == null) throw "USER SESSION NOT FOUND";

    _setLoading(true);
    try {
      final now = DateTime.now();
      final expiry = now.add(Duration(days: durationDays));

      // 1. Update Cloud (Supabase)
      try {
        await _supabase.from('profiles').update({
          'is_pro': true,
          'pro_plan_tier': tier,
          'pro_start_date': now.toIso8601String(),
          'pro_expiry_date': expiry.toIso8601String(),
        }).eq('id', userId);
      } catch (_) {
        await _supabase.from('profiles').update({'is_pro': true}).eq('id', userId);
      }

      // 2. Update Local Repository
      if (_userProfile != null) {
        final updatedLocal = _userProfile!.copyWith(
          isPro: true,
          proPlanTier: tier,
          proStartDate: now,
          proExpiryDate: expiry,
          isSynced: 1,
        );
        await _profileRepo?.saveProfile(updatedLocal);
        _userProfile = updatedLocal;
      }

      // 3. Mark in SharedPreferences for fast startup check
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_pro_active', true);
      await prefs.setString('pro_plan_tier', tier);

      debugPrint("AuthProvider: ELITE ACCESS ACTIVATED ($tier) for $userId");
      notifyListeners();
    } catch (e) {
      debugPrint("AuthProvider: PRO UPGRADE FAILED: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ==========================================
  // SIGN UP WITH USERNAME (Shadow Email)
  // ==========================================
  Future<void> signUpWithUsername(String username, String password) async {
    final shadowEmail = '$username@internal.affulabs.com';
    await signUp(shadowEmail, password, username: username);
  }

  // ==========================================
  // GOOGLE SIGN IN
  // ==========================================
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      debugPrint("AuthProvider: [signInWithGoogle] STEP 1: Starting Google Sign-In...");
      // 1. Initialize and Trigger the Google Sign-In selector (Supabase official 7.x way)
      const scopes = ['email', 'profile'];
      final googleSignIn = GoogleSignIn.instance;

      debugPrint("AuthProvider: [signInWithGoogle] STEP 2: Initializing GoogleSignIn with serverClientId...");
      await googleSignIn.initialize(
        serverClientId: '441257144462-eoid7g4j3nldb3qjnmecvp5eis9dmh6v.apps.googleusercontent.com',
      );

      debugPrint("AuthProvider: [signInWithGoogle] STEP 3: Authenticating with Google...");
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await googleSignIn.authenticate();
        debugPrint("AuthProvider: [signInWithGoogle] STEP 4: Google auth successful. User: ${googleUser.email}");
      } on GoogleSignInException catch (e) {
        debugPrint("AuthProvider: [signInWithGoogle] ERROR: GoogleSignInException caught!");
        debugPrint("AuthProvider: [signInWithGoogle] CODE: ${e.code}");
        debugPrint("AuthProvider: [signInWithGoogle] MESSAGE: ${e.description}");
        debugPrint("AuthProvider: [signInWithGoogle] ERROR DETAILS: ${e.details}");
        if (e.code == GoogleSignInExceptionCode.canceled) {
          debugPrint("AuthProvider: [signInWithGoogle] User canceled sign in.");
          _setLoading(false);
          return;
        }
        rethrow;
      } catch (e, stacktrace) {
        debugPrint("AuthProvider: [signInWithGoogle] ERROR during googleSignIn.authenticate(): $e");
        debugPrint("AuthProvider: [signInWithGoogle] STACKTRACE: $stacktrace");
        rethrow;
      }

      debugPrint("AuthProvider: [signInWithGoogle] STEP 5: Requesting authorization for scopes...");
      // 2. Authorize scopes to obtain the access token for Supabase
      final authorization =
          await googleUser.authorizationClient.authorizationForScopes(scopes) ??
          await googleUser.authorizationClient.authorizeScopes(scopes);
          
      debugPrint("AuthProvider: [signInWithGoogle] STEP 6: Authorization obtained. Access Token length: ${authorization.accessToken.length}");

      final idToken = googleUser.authentication.idToken;
      debugPrint("AuthProvider: [signInWithGoogle] STEP 7: ID Token extracted. Length: ${idToken?.length ?? 0}");

      if (idToken == null) {
        debugPrint("AuthProvider: [signInWithGoogle] ERROR: GOOGLE ID TOKEN NOT FOUND");
        throw 'GOOGLE ID TOKEN NOT FOUND';
      }

      debugPrint("AuthProvider: [signInWithGoogle] STEP 8: Authenticating with Supabase...");
      // 3. Authenticate with Supabase using ID Token and Access Token
      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: authorization.accessToken,
      );

      debugPrint("AuthProvider: [signInWithGoogle] STEP 9: Supabase auth successful. User ID: ${response.user?.id}");

      _currentUser = response.user;
      if (_currentUser != null) {
        debugPrint("AuthProvider: [signInWithGoogle] STEP 10: Upserting user profile...");
        _initializeProfileRepo(_currentUser!.id);
        
        // Auto-heal profiles table with ID and Email
        // We intentionally do NOT force the profile to be "complete" here
        // so the Router redirects them to CreateAccPersoScreen.
        await _supabase.from('profiles').upsert({
          'id': _currentUser!.id,
          'email': _currentUser!.email,
        });

        debugPrint("AuthProvider: [signInWithGoogle] STEP 11: Loading user profile...");
        // Force a state refresh so isProfileComplete is re-evaluated by the router
        await _loadUserProfile();
        debugPrint("AuthProvider: [signInWithGoogle] STEP 12: Google Sign-In Complete!");
      }
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint("AuthProvider: [signInWithGoogle] FATAL ERROR: $e");
      debugPrint("AuthProvider: [signInWithGoogle] STACKTRACE: $stackTrace");
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
