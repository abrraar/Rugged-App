import 'dart:io';
import 'package:flutter/foundation.dart';

/// ELITE AD HELPER
/// 
/// Manages AdMob Unit IDs for development and production.
/// Use Test IDs during development to avoid account suspension.
class AdHelper {
  
  static String get bannerAdUnitId {
    if (kDebugMode) {
      // Android Test Banner ID
      return 'ca-app-pub-3940256099942544/6300978111';
    }
    
    if (Platform.isAndroid) {
      // PROD ANDROID BANNER ID
      return 'ca-app-pub-4330528996980931/7774778696';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // Android Test Interstitial ID
      return 'ca-app-pub-3940256099942544/1033173712';
    }
    
    if (Platform.isAndroid) {
      // PROD ANDROID INTERSTITIAL ID
      return 'ca-app-pub-4330528996980931/2602343067';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      // Android Test Rewarded ID
      return 'ca-app-pub-3940256099942544/5224354917';
    }
    
    if (Platform.isAndroid) {
      // PROD ANDROID REWARDED ID
      return 'ca-app-pub-4330528996980931/4674112253';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get nativeAdUnitId {
    if (kDebugMode) {
      // Android Test Native Ad ID
      return 'ca-app-pub-3940256099942544/2247696110';
    }
    
    if (Platform.isAndroid) {
      // PROD ANDROID NATIVE AD ID
      return 'ca-app-pub-4330528996980931/2247696110';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
