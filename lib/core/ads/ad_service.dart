import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/provider/auth_provider.dart';
import 'ad_helper.dart';
import 'custom_native_interstitial_dialog.dart';

/// ELITE AD SERVICE
/// 
/// Manages Interstitial & Rewarded Ad lifecycles to ensure pre-loading
/// and seamless playback.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  DateTime? _lastAdShownTime;

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;

  /// Helper to check if user is PRO
  bool get _isUserPro {
    try {
      // We check if Supabase is initialized by attempting to access instance.
      // This prevents a crash during early app initialization in main().
      Supabase.instance;
      return AuthProvider().isPro;
    } catch (_) {
      return false;
    }
  }

  /// Minimum interval between interstitial ads to prevent user fatigue
  static const Duration cooldownDuration = Duration(minutes: 10);

  /// Call this to pre-load Interstitial and Rewarded Ads on app init.
  void init() {
    if (_isUserPro) {
      debugPrint('AdService: USER IS PRO. Skipping Ad initialization.');
      return;
    }
    loadInterstitialAd();
    loadRewardedAd();
  }

  /// Call this to pre-load the next Interstitial Ad.
  void loadInterstitialAd() {
    if (_isUserPro) return;
    if (_isInterstitialAdLoading || _interstitialAd != null) return;

    debugPrint('AdService: Starting to load Interstitial Ad...');
    _isInterstitialAdLoading = true;
    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Elite Interstitial Ad Loaded.');
          _interstitialAd = ad;
          _isInterstitialAdLoading = false;
          
          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Elite Interstitial Ad failed to show: $error');
              ad.dispose();
              _interstitialAd = null;
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('AdService: Interstitial Ad failed to load: ${err.message}');
          _isInterstitialAdLoading = false;
          _interstitialAd = null;
          if (err.code == 3) {
            Future.delayed(const Duration(seconds: 5), () => loadInterstitialAd());
          }
        },
      ),
    );
  }

  /// Shows the pre-loaded Interstitial Ad if available and cooldown has passed.
  void showInterstitialAd({bool ignoreCooldown = false}) {
    if (_isUserPro) {
      debugPrint('AdService: USER IS PRO. Ad bypassed.');
      return;
    }
    if (!ignoreCooldown && _lastAdShownTime != null) {
      final elapsed = DateTime.now().difference(_lastAdShownTime!);
      if (elapsed < cooldownDuration) {
        final remaining = (cooldownDuration - elapsed).inMinutes + 1;
        debugPrint('AdService: Cooldown active (${remaining}m remaining). Skipping ad.');
        return;
      }
    }

    if (_interstitialAd != null) {
      debugPrint('AdService: Showing Elite Interstitial Ad...');
      _lastAdShownTime = DateTime.now();
      _interstitialAd!.show();
    } else {
      debugPrint('AdService: NO INTERSTITIAL AD READY TO SHOW. Loading now...');
      loadInterstitialAd();
    }
  }

  /// Shows the Custom Native Interstitial Ad overlay with empathetic message & dark styling.
  void showCustomNativeInterstitial(BuildContext context, {bool ignoreCooldown = false}) {
    if (_isUserPro) {
      debugPrint('AdService: USER IS PRO. Custom Native Ad bypassed.');
      return;
    }
    if (!ignoreCooldown && _lastAdShownTime != null) {
      final elapsed = DateTime.now().difference(_lastAdShownTime!);
      if (elapsed < cooldownDuration) {
        final remaining = (cooldownDuration - elapsed).inMinutes + 1;
        debugPrint('AdService: Cooldown active (${remaining}m remaining). Skipping Custom Native Interstitial.');
        return;
      }
    }

    _lastAdShownTime = DateTime.now();
    CustomNativeInterstitialDialog.show(context);
  }

  /// Pre-loads the next Rewarded Ad.
  void loadRewardedAd() {
    if (_isUserPro) return;
    if (_isRewardedAdLoading || _rewardedAd != null) return;

    debugPrint('AdService: Loading Rewarded Ad...');
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('Elite Rewarded Ad Loaded.');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (err) {
          debugPrint('AdService: Rewarded Ad failed to load: ${err.message}');
          _isRewardedAdLoading = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Shows a Rewarded Ad and invokes [onRewardEarned] when the user finishes watching.
  void showRewardedAd({required VoidCallback onRewardEarned, VoidCallback? onAdFailed}) {
    if (_isUserPro) {
      debugPrint('AdService: USER IS PRO. Reward granted immediately.');
      onRewardEarned();
      return;
    }
    if (_rewardedAd != null) {
      bool rewardGranted = false;

      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd(); // Pre-load next
          if (rewardGranted) {
            onRewardEarned();
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('Rewarded Ad failed to show: $error');
          ad.dispose();
          _rewardedAd = null;
          loadRewardedAd();
          if (onAdFailed != null) onAdFailed();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('Rewarded Ad: Reward Earned! (${reward.amount} ${reward.type})');
          rewardGranted = true;
        },
      );
    } else {
      debugPrint('AdService: Rewarded Ad not ready. Attempting fallback/load...');
      loadRewardedAd();
      if (onAdFailed != null) onAdFailed();
    }
  }

  /// Cleans up resources.
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
  }
}
