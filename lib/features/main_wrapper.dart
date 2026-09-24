import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/constants/dimensions.dart';
import 'package:rugged/features/affirmation/widgets/affirmation_settings_sheet.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'package:intl/intl.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/app_bottom_navbar.dart';
import 'package:rugged/core/ads/banner_ad_widget.dart';
import 'package:provider/provider.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';

final ValueNotifier<String> activeSettingsContext = ValueNotifier<String>("");

class MainWrapper extends StatelessWidget {
  final Widget child;
  final int currentIndex;

  const MainWrapper({
    super.key,
    required this.currentIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double width = size.width;
    final double height = size.height;
    
    // BREAKPOINTS
    final bool isCompact = width < kMobileBreakpoint; // < 600
    final bool isMedium = width >= kMobileBreakpoint && width < kTabletBreakpoint; // 600 - 900
    final bool isExpanded = width >= kTabletBreakpoint; // > 900

    // [LAYOUT_DEBUG] MainWrapper configuration
    debugPrint("[LAYOUT_DEBUG] MainWrapper -> Width: $width, Height: $height, isCompact: $isCompact, isMedium: $isMedium, isExpanded: $isExpanded");

    final String formattedDate = DateFormat('EEEE, d MMMM').format(DateTime.now()).toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false, 
        bottom: !isCompact,
        child: Row(
          children: [
            // ── NAVIGATION RAIL (MEDIUM & EXPANDED) ───────────────────────────
            if (!isCompact)
              Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.white.withValues(alpha : 0.05), width: 1)),
                ),
                child: _AdaptiveNavigationRail(
                  currentIndex: currentIndex,
                  isExpanded: width >= 1200, // Only show full text on very wide screens
                  onTap: (index) => _onNavTap(context, index),
                ),
              ),

            // ── MAIN CONTENT AREA ───────────────────────────────────────────
            Expanded(
              child: Column(
                children: [
                  _AdaptiveTopAppBar(
                    formattedDate: formattedDate,
                    title: _getTitle(currentIndex),
                    isCompact: isCompact,
                    onSettingsTap: () => _openSettings(context),
                  ),
                  Expanded(
                    child: child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // ── BOTTOM NAVIGATION (COMPACT ONLY) ─────────────────────────────
      bottomNavigationBar: Consumer<AuthProvider>(
        builder: (context, authProv, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!authProv.isPro)
                EliteBannerAd(), // Fixed Banner Ad at the bottom
              if (isCompact)
                _CompactBottomNav(
                  currentIndex: currentIndex,
                  onTap: (index) => _onNavTap(context, index),
                ),
            ],
          );
        },
      ),
    );
  }

  void _onNavTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(AppRoutes.home); break;
      case 1: context.go(AppRoutes.exercises); break;
      case 2: context.go(AppRoutes.tracker); break;
      case 3: context.go(AppRoutes.profile); break;
    }
  }

  void _openSettings(BuildContext context) {
    final String currentContext = activeSettingsContext.value;
    switch (currentContext) {
      case "hydration": context.push(AppRoutes.settingsHydration); break;
      case "body_comp": context.push(AppRoutes.settingsBodyComp); break;
      case "cycle": context.push(AppRoutes.settingsCycle); break;
      case "sleep": context.push(AppRoutes.settingsSleep); break;
      case "calorie": context.push(AppRoutes.settingsCalorie); break;
      case "supplement": context.push(AppRoutes.settingsSupplement); break;
      case "affirmation": 
        AdaptiveUtils.showAdaptiveSheet(
          context: context, 
          sheetBuilder: (sheetContext, isSideSheet) => AffirmationSettingsSheet(isSideSheet: isSideSheet),
        );
        break;
      default: context.push(AppRoutes.settings);
    }
  }

  String _getTitle(int index) {
    switch (index) {
      case 0: return 'HOME';
      case 1: return 'EXERCISES';
      case 2: return 'TRACKER';
      case 3: return 'PROFILE';
      default: return 'HOME';
    }
  }
}

class _AdaptiveTopAppBar extends StatelessWidget {
  final String formattedDate;
  final String title;
  final bool isCompact;
  final VoidCallback onSettingsTap;

  const _AdaptiveTopAppBar({
    required this.formattedDate,
    required this.title,
    required this.isCompact,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.white.withValues(alpha : 0.05), width: 1)),
      ),
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isCompact ? double.infinity : kMaxContentWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 20.w : 24.0, // Fixed padding for tablet
            vertical: 16.0,
          ).copyWith(top: MediaQuery.of(context).padding.top + 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3.0,
                        height: isCompact ? 10 : 14.0,
                        decoration: BoxDecoration(color: AppColors.crimson, borderRadius: BorderRadius.circular(4.0)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formattedDate,
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: AppTextStyles.displayMedium.adaptive(context).copyWith(
                      letterSpacing: -0.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onSettingsTap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withValues(alpha : 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
                  ),
                  child: const Icon(Icons.settings, color: AppColors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdaptiveNavigationRail extends StatelessWidget {
  final int currentIndex;
  final bool isExpanded;
  final Function(int) onTap;

  const _AdaptiveNavigationRail({
    required this.currentIndex,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isExpanded ? 200.0 : 170.0,
      color: AppColors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Image.asset(
              'lib/assets/images/rugged_app_icon.png',
              width: 40,
              height: 40,
            ),
          ),
          const SizedBox(height: 12.0),
          _buildItem(
            index: 0,
            label: 'HOME',
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_filled,
          ),
          const SizedBox(height: 8.0),
          _buildItem(
            index: 1,
            label: 'EXERCISES',
            icon: Icons.fitness_center_outlined,
            selectedIcon: Icons.fitness_center_rounded,
          ),
          const SizedBox(height: 8.0),
          _buildItem(
            index: 2,
            label: 'TRACKER',
            icon: Icons.edit_note_outlined,
            selectedIcon: Icons.edit_note_rounded,
          ),
          const SizedBox(height: 8.0),
          _buildItem(
            index: 3,
            label: 'PROFILE',
            icon: Icons.person_outline,
            selectedIcon: Icons.person_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData selectedIcon,
  }) {
    final bool isSelected = currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          onTap: () => onTap(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.crimson.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? AppColors.white
                      : AppColors.white.withValues(alpha: 0.3),
                  size: 22.0,
                ),
                const SizedBox(width: 10.0),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isSelected
                        ? AppColors.white
                        : AppColors.white.withValues(alpha: 0.3),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 11.0,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CompactBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.white.withValues(alpha : 0.05), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: AppBottomNavbar(
          currentIndex: currentIndex,
          onTap: onTap,
        ),
      ),
    );
  }
}
