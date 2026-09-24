import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'ad_helper.dart';

class CustomNativeInterstitialDialog extends StatefulWidget {
  const CustomNativeInterstitialDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.background.withValues(alpha: 0.95),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const CustomNativeInterstitialDialog(),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<CustomNativeInterstitialDialog> createState() => _CustomNativeInterstitialDialogState();
}

class _CustomNativeInterstitialDialogState extends State<CustomNativeInterstitialDialog> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;
  bool _adFailed = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    _nativeAd = NativeAd(
      adUnitId: AdHelper.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: AppColors.surface,
        cornerRadius: 16.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.crimson,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textSecondary,
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textSecondary,
          style: NativeTemplateFontStyle.normal,
          size: 12.0,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('CustomNativeInterstitialDialog: Native Ad failed to load: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _adFailed = true;
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 24.w : 32.0,
                vertical: isCompact ? 16.h : 20.0,
              ),
              child: Column(
                children: [
                  // --- TOP HEADER: DISMISS & EMPATHETIC MESSAGE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 12.w : 12.0,
                          vertical: isCompact ? 6.h : 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.crimson.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.favorite_rounded,
                              color: AppColors.crimson,
                              size: isCompact ? 14.r : 14.0,
                            ),
                            SizedBox(width: isCompact ? 6.w : 6.0),
                            Text(
                              "SUPPORT RUGGED",
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.crimson,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: isCompact ? 28.r : 24.0,
                        ),
                        tooltip: "Close",
                      ),
                    ],
                  ),

                  SizedBox(height: isCompact ? 20.h : 20.0),

                  // --- EMPATHETIC MESSAGE ---
                  Text(
                    "THIS AD HELPS US KEEP RUGGED 100% FREE FOR YOUR TRAINING",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      height: 1.4,
                    ),
                  ),

                  const Spacer(),

                  // --- NATIVE AD CONTAINER ---
                  if (_isAdLoaded && _nativeAd != null)
                    Container(
                      height: isCompact ? 360.h : 320.0,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: 320,
                            minHeight: 320,
                            maxWidth: isCompact ? 400.w : 500.0,
                            maxHeight: isCompact ? 360.h : 320.0,
                          ),
                          child: AdWidget(ad: _nativeAd!),
                        ),
                      ),
                    )
                  else if (_adFailed)
                    Container(
                      padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fitness_center_rounded,
                            color: AppColors.crimson,
                            size: isCompact ? 40.r : 36.0,
                          ),
                          SizedBox(height: isCompact ? 16.h : 16.0),
                          Text(
                            "STAY RUGGED",
                            style: AppTextStyles.h3.adaptive(context).copyWith(
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                          SizedBox(height: isCompact ? 8.h : 8.0),
                          Text(
                            "Thank you for supporting independent fitness development.",
                            textAlign: TextAlign.center,
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      height: isCompact ? 320.h : 280.0,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.crimson,
                            strokeWidth: 2.5,
                          ),
                          SizedBox(height: isCompact ? 16.h : 16.0),
                          Text(
                            "LOADING AD...",
                            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),

                  // --- FOOTER ATTRIBUTION ---
                  Text(
                    "THANK YOU FOR SUPPORTING INDEPENDENT SOFTWARE",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.3),
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: isCompact ? 12.h : 12.0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
