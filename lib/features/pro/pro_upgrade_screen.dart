import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/core/providers/iap_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ProUpgradeScreen extends StatefulWidget {
  final bool isEmbedded;
  const ProUpgradeScreen({super.key, this.isEmbedded = false});

  @override
  State<ProUpgradeScreen> createState() => _ProUpgradeScreenState();
}

class _ProUpgradeScreenState extends State<ProUpgradeScreen> {
  // 0 = 1 Year, 1 = 6 Months, 2 = 3 Months, 3 = 1 Month
  int _selectedPlanIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleUpgrade(IAPProvider iapProv) async {
    final targetProduct = _getSelectedProduct(iapProv);

    if (targetProduct == null) {
      // Fallback checkout
      try {
        await iapProv.buyPro();
      } catch (e) {
        if (mounted) {
          EliteSnackbar.show(context, "STORE CONNECTION PENDING. PLEASE TRY AGAIN.", isError: true);
        }
      }
      return;
    }

    try {
      await iapProv.buySubscription(targetProduct);
    } catch (e) {
      if (mounted) {
        EliteSnackbar.show(context, "TRANSACTION CANCELLED OR FAILED", isError: true);
      }
    }
  }

  ProductDetails? _getSelectedProduct(IAPProvider iapProv) {
    switch (_selectedPlanIndex) {
      case 0:
        return iapProv.pro1y;
      case 1:
        return iapProv.pro6m ?? iapProv.pro1y;
      case 2:
        return iapProv.pro3m ?? iapProv.pro1y;
      case 3:
        return iapProv.pro1m ?? iapProv.pro1y;
      default:
        return iapProv.pro1y;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final bool isPro = authProv.isPro;

    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600 && !isLargeScreen;
            return Consumer<IAPProvider>(
              builder: (context, iapProv, _) {
                return Stack(
                  children: [
                    // Background Gradient
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0.8, -0.6),
                            radius: 1.2,
                            colors: [
                              AppColors.crimson.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    Column(
                      children: [
                        EliteSettingsAppBar(
                          title: "RUGGED ELITE",
                          isCompact: isCompact,
                          showBackButton: !widget.isEmbedded && Navigator.of(context).canPop(),
                        ),
                        Expanded(
                          child: _buildSingleColumnLayout(context, iapProv, isPro, isCompact, isLargeScreen),
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildSingleColumnLayout(
    BuildContext context, 
    IAPProvider iapProv, 
    bool isPro, 
    bool isCompact,
    bool isLargeScreen,
  ) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 24.0 : 24.w, 
              vertical: isLargeScreen ? 16.0 : 10.h,
            ),
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPro) ...[
                    _buildActiveMembershipCard(context, isLargeScreen),
                    SizedBox(height: isLargeScreen ? 24.0 : 24.h),
                    Text(
                      "EXTEND YOUR MEMBERSHIP",
                      style: AppTextStyles.h2.adaptive(context).copyWith(
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: isLargeScreen ? 4.0 : 4.h),
                    Text(
                      "Select a pass below to extend your active subscription or switch your plan at any time.",
                      style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: isLargeScreen ? 16.0 : 16.h),
                    _buildSubscriptionPlans(context, iapProv, isLargeScreen),
                    SizedBox(height: isLargeScreen ? 24.0 : 24.h),
                    _buildBenefitsList(context, isLargeScreen),
                    SizedBox(height: isLargeScreen ? 16.0 : 16.h),
                    _buildEmpathySupportCard(context, isLargeScreen),
                  ] else ...[
                    _buildHeroSection(context, isLargeScreen),
                    SizedBox(height: isLargeScreen ? 20.0 : 20.h),
                    _buildSubscriptionPlans(context, iapProv, isLargeScreen),
                    SizedBox(height: isLargeScreen ? 24.0 : 24.h),
                    _buildBenefitsList(context, isLargeScreen),
                    SizedBox(height: isLargeScreen ? 16.0 : 16.h),
                    _buildEmpathySupportCard(context, isLargeScreen),
                  ],
                  SizedBox(height: isLargeScreen ? 20.0 : 20.h),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: _buildBottomAction(context, iapProv, isPro, isLargeScreen),
        ),
      ],
    );
  }





  Widget _buildHeroSection(BuildContext context, bool isLargeScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "CHOOSE YOUR\nMEMBERSHIP",
          style: AppTextStyles.h1.adaptive(context).copyWith(
            height: 0.95,
            letterSpacing: -1,
          ),
        ),
        SizedBox(height: isLargeScreen ? 12.0 : 12.h),
        Text(
          "Unlock automated cloud backups, multi-device sync, web link sharing, and an ad-free performance experience.",
          style: AppTextStyles.bodyMedium.adaptive(context).copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatPriceWithMonthlyBreakdown(
    ProductDetails? product, 
    int months, 
    String fallbackTotal, 
    String fallbackMonthly,
  ) {
    if (product == null || product.rawPrice <= 0) {
      if (months == 1) return fallbackTotal;
      return "$fallbackTotal  ($fallbackMonthly / mo)";
    }
    if (months == 1) return product.price;

    final double monthlyRate = product.rawPrice / months;
    final String symbol = product.currencySymbol.isNotEmpty ? product.currencySymbol : "\$";
    return "${product.price}  (Effective $symbol${monthlyRate.toStringAsFixed(2)} / mo)";
  }

  Widget _buildSubscriptionPlans(BuildContext context, IAPProvider iapProv, bool isLargeScreen) {
    final p1y = _formatPriceWithMonthlyBreakdown(
      iapProv.pro1y, 
      12, 
      "\$50 / yr", 
      "\$4.17",
    );
    final p6m = _formatPriceWithMonthlyBreakdown(
      iapProv.pro6m, 
      6, 
      "\$30 / 6 mo", 
      "\$5.00",
    );
    final p3m = _formatPriceWithMonthlyBreakdown(
      iapProv.pro3m, 
      3, 
      "\$16 / 3 mo", 
      "\$5.33",
    );
    final p1m = _formatPriceWithMonthlyBreakdown(
      iapProv.pro1m, 
      1, 
      "\$6 / mo", 
      "\$6.00",
    );

    return RadioGroup<int>(
      groupValue: _selectedPlanIndex,
      onChanged: (val) {
        if (val != null) setState(() => _selectedPlanIndex = val);
      },
      child: Column(
        children: [
          _buildPlanCard(
            context,
            index: 0,
            title: "ANNUAL PASS",
            subtitle: p1y,
            badge: "BEST VALUE • SAVE 31%",
            isPopular: true,
            isLargeScreen: isLargeScreen,
          ),
          SizedBox(height: isLargeScreen ? 10.0 : 10.h),
          _buildPlanCard(
            context,
            index: 1,
            title: "6-MONTH PASS",
            subtitle: p6m,
            badge: "SAVE 17%",
            isLargeScreen: isLargeScreen,
          ),
          SizedBox(height: isLargeScreen ? 10.0 : 10.h),
          _buildPlanCard(
            context,
            index: 2,
            title: "3-MONTH PASS",
            subtitle: p3m,
            badge: "SAVE 11%",
            isLargeScreen: isLargeScreen,
          ),
          SizedBox(height: isLargeScreen ? 10.0 : 10.h),
          _buildPlanCard(
            context,
            index: 3,
            title: "MONTHLY PASS",
            subtitle: p1m,
            isLargeScreen: isLargeScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context, {
    required int index,
    required String title,
    required String subtitle,
    String? badge,
    bool isPopular = false,
    bool isLargeScreen = false,
  }) {
    final bool isSelected = _selectedPlanIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 16.0 : 16.w, 
          vertical: isLargeScreen ? 14.0 : 14.h
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.crimson.withValues(alpha: 0.15) 
              : AppColors.surface,
          borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.0),
          border: Border.all(
            color: isSelected 
                ? AppColors.crimson 
                : AppColors.white.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<int>(
              value: index,
              activeColor: AppColors.crimson,
            ),
            SizedBox(width: isLargeScreen ? 8.0 : 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                      if (badge != null) ...[
                        SizedBox(width: isLargeScreen ? 8.0 : 8.w),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isPopular ? AppColors.crimson : AppColors.crimson.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: isLargeScreen ? 2.0 : 2.h),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitsList(BuildContext context, bool isLargeScreen) {
    return Column(
      children: [
        _buildBenefitItem(
          context,
          icon: Icons.cloud_upload_rounded,
          title: "Automated Cloud Backup",
          description: "Full sync to Supabase Cloud so you never lose your history.",
          isLargeScreen: isLargeScreen,
        ),
        _buildBenefitItem(
          context,
          icon: Icons.sync_rounded,
          title: "Multi-Device Sync",
          description: "Seamless real-time synchronization across all your mobile devices.",
          isLargeScreen: isLargeScreen,
        ),
        _buildBenefitItem(
          context,
          icon: Icons.link_rounded,
          title: "Web Link Sharing",
          description: "Generate instant web sharing links for workouts, meals, and cycles.",
          isLargeScreen: isLargeScreen,
        ),
        _buildBenefitItem(
          context,
          icon: Icons.block_rounded,
          title: "Ad-Free Performance",
          description: "Zero banner or interstitial ad interruptions.",
          isLargeScreen: isLargeScreen,
        ),
        _buildBenefitItem(
          context,
          icon: Icons.auto_graph_rounded,
          title: "Advanced Analytics",
          description: "Instant access to performance trends without watching ads.",
          isLargeScreen: isLargeScreen,
        ),
      ],
    );
  }

  Widget _buildEmpathySupportCard(BuildContext context, bool isLargeScreen) {
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 16.0 : 14.r),
      decoration: BoxDecoration(
        color: AppColors.crimson.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.0),
        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.favorite_rounded, color: AppColors.crimson, size: isLargeScreen ? 20.0 : 20.sp),
          SizedBox(width: isLargeScreen ? 12.0 : 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SUPPORT INDEPENDENT DEVELOPMENT",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: isLargeScreen ? 4.0 : 4.h),
                Text(
                  "By becoming a Pro member, you directly keep our cloud servers active, fund ongoing software development, maintain database security, and support continuous feature updates for Rugged. Thank you for supporting the lab.",
                  style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    bool isLargeScreen = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLargeScreen ? 16.0 : 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isLargeScreen ? 10.0 : 10.0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 10.0),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
            ),
            child: Icon(icon, color: AppColors.crimson, size: isLargeScreen ? 20.0 : 20.0),
          ),
          SizedBox(width: isLargeScreen ? 16.0 : 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isLargeScreen ? 2.0 : 2.h),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMembershipCard(BuildContext context, bool isLargeScreen) {
    final authProv = context.watch<AuthProvider>();
    final startDateStr = DateFormat('MMM dd, yyyy').format(authProv.activeProStartDate);
    final expiryDateStr = DateFormat('MMM dd, yyyy').format(authProv.activeProExpiryDate);
    final tierName = authProv.activeProTierName.toUpperCase();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isLargeScreen ? 18.0 : 18.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isLargeScreen ? 12.0 : 16.r),
        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.crimson.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isLargeScreen ? 10.0 : 10.r),
                decoration: BoxDecoration(
                  color: AppColors.crimson.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.workspace_premium_rounded, color: AppColors.crimson, size: isLargeScreen ? 22.0 : 22.r),
              ),
              SizedBox(width: isLargeScreen ? 12.0 : 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "ACTIVE ELITE MEMBERSHIP",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.crimson,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: isLargeScreen ? 2.0 : 2.h),
                    Text(
                      tierName,
                      style: AppTextStyles.h3.adaptive(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isLargeScreen ? 10.0 : 10.w, 
                  vertical: isLargeScreen ? 5.0 : 5.h
                ),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  "ACTIVE",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 16.0 : 16.h),
          Divider(color: AppColors.white.withValues(alpha: 0.08), height: 1),
          SizedBox(height: isLargeScreen ? 16.0 : 16.h),
          Row(
            children: [
              Expanded(
                child: _buildDetailStatTile(
                  context,
                  label: "SUBSCRIBED ON",
                  value: startDateStr,
                  icon: Icons.calendar_today_rounded,
                  isLargeScreen: isLargeScreen,
                ),
              ),
              SizedBox(width: isLargeScreen ? 12.0 : 12.w),
              Expanded(
                child: _buildDetailStatTile(
                  context,
                  label: "VALID UNTIL",
                  value: expiryDateStr,
                  icon: Icons.event_available_rounded,
                  isLargeScreen: isLargeScreen,
                ),
              ),
            ],
          ),
          SizedBox(height: isLargeScreen ? 14.0 : 14.h),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 12.0 : 12.w, 
              vertical: isLargeScreen ? 8.0 : 8.h
            ),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(isLargeScreen ? 8.0 : 8.r),
              border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: isLargeScreen ? 16.0 : 16.r),
                SizedBox(width: isLargeScreen ? 8.0 : 8.w),
                Expanded(
                  child: Text(
                    "Cloud Backup • Realtime Sync • Ad-Free Active",
                    style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStatTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    bool isLargeScreen = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 10.0 : 10.r),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isLargeScreen ? 8.0 : 10.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.crimson.withValues(alpha: 0.8), size: isLargeScreen ? 16.0 : 16.r),
          SizedBox(width: isLargeScreen ? 8.0 : 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: isLargeScreen ? 2.0 : 2.h),
                Text(
                  value,
                  style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(
    BuildContext context, 
    IAPProvider iapProv, 
    bool isPro,
    bool isLargeScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 20.0 : 20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: iapProv.isLoading ? null : () => _handleUpgrade(iapProv),
            child: Container(
              width: double.infinity,
              height: isLargeScreen ? 54.0 : 52.h,
              decoration: BoxDecoration(
                color: AppColors.crimson,
                borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.0),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.crimson.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: iapProv.isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      isPro ? "EXTEND MEMBERSHIP NOW" : "GO ELITE NOW",
                      style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
          SizedBox(height: isLargeScreen ? 10.0 : 10.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 12.0 : 12.w),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                Text(
                  "One-time prepaid activation. Instant cloud provisioning. No refunds. ",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final Uri url = Uri.parse("https://affulabs.com/rugged/terms.html");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    "Terms of Service.",
                    style: AppTextStyles.bodySmall.adaptive(context).copyWith(
                      color: AppColors.crimson.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

