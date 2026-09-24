import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../features/auth/provider/auth_provider.dart';
import 'ad_helper.dart';

/// ELITE BANNER AD WIDGET
/// 
/// A reusable widget to display banner ads with safe loading logic.
class EliteBannerAd extends StatefulWidget {
  const EliteBannerAd({super.key});

  @override
  State<EliteBannerAd> createState() => _EliteBannerAdState();
}

class _EliteBannerAdState extends State<EliteBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Pre-check pro status before loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthProvider>().isPro) {
        _loadAd();
      }
    });
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('EliteBannerAd failed to load: ${err.message}');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isPro = context.watch<AuthProvider>().isPro;
    debugPrint("EliteBannerAd: isPro = $isPro");

    if (isPro) {
      // ELITE SAFETY: If user became pro, immediately dispose and hide
      if (_bannerAd != null) {
        _bannerAd!.dispose();
        _bannerAd = null;
      }
      return const SizedBox.shrink();
    }

    if (_isLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox.shrink(); // Hide if not loaded
  }
}
