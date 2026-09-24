import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';

class SupplementSettingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const SupplementSettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SupplementSettingsScreen> createState() => _SupplementSettingsScreenState();
}

class _SupplementSettingsScreenState extends State<SupplementSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return Consumer<SupplementProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        
        final pinnedSupps = provider.library
            .where((s) => s.isActive && s.isPinnedToHome)
            .toList();
        final pinnedStacks = provider.supplementStacks
            .where((s) => s.isPinnedToHome)
            .toList();

        pinnedSupps.sort((a, b) {
          final idxA = settings.pinnedOrder.indexOf(a.id);
          final idxB = settings.pinnedOrder.indexOf(b.id);
          if (idxA == -1 && idxB == -1) return 0;
          if (idxA == -1) return 1;
          if (idxB == -1) return -1;
          return idxA.compareTo(idxB);
        });

        pinnedStacks.sort((a, b) {
          final idxA = settings.pinnedOrder.indexOf(a.id);
          final idxB = settings.pinnedOrder.indexOf(b.id);
          if (idxA == -1 && idxB == -1) return 0;
          if (idxA == -1) return 1;
          if (idxB == -1) return -1;
          return idxA.compareTo(idxB);
        });

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600 && !isLargeScreen;

                return Column(
                  children: [
                    EliteSettingsAppBar(
                      title: "SUPPLEMENT SETTINGS", 
                      isCompact: isCompact,
                      showBackButton: !widget.isEmbedded,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 24.0 : 24.w
                        ),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                SizedBox(height: isLargeScreen ? 16.0 : 16.h),
                                _buildSectionHeader("GLOBAL PREFERENCES", isLargeScreen),
                                _buildToggleCard(
                                  title: "SHOW EXPIRED ITEMS",
                                  subtitle: "DISPLAY SUPPLEMENTS PAST EXPIRY DATE",
                                  value: settings.showExpired,
                                  isLargeScreen: isLargeScreen,
                                  onChanged: (val) {
                                    provider.updateSettings(settings.copyWith(showExpired: val));
                                  },
                                ),
                                _buildToggleCard(
                                  title: "HIDE EMPTY STOCK",
                                  subtitle: "REMOVE ITEMS WITH 0 REMAINING FROM LOGS",
                                  value: settings.hideEmptyStock,
                                  isLargeScreen: isLargeScreen,
                                  onChanged: (val) {
                                    provider.updateSettings(settings.copyWith(hideEmptyStock: val));
                                  },
                                ),
                                
                                SizedBox(height: isLargeScreen ? 32.0 : 32.h),
                                _buildSectionHeader("PINNED SUPPLEMENTS", isLargeScreen),
                                Text(
                                  "REORDER INDIVIDUAL SUPPLEMENT SHORTCUTS",
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                    color: AppColors.textSecondary, 
                                  ),
                                ),
                                SizedBox(height: isLargeScreen ? 16.0 : 16.h),
                                if (pinnedSupps.isEmpty)
                                  _buildEmptyPlaceholder("NO SUPPLEMENTS PINNED", isLargeScreen)
                                else
                                  ReorderableListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: pinnedSupps.length,
                                    proxyDecorator: (child, index, animation) => Material(
                                      type: MaterialType.transparency,
                                      child: child,
                                    ),
                                    onReorder: (oldIdx, newIdx) {
                                      if (newIdx > oldIdx) newIdx--;
                                      final item = pinnedSupps.removeAt(oldIdx);
                                      pinnedSupps.insert(newIdx, item);
                                      
                                      final List<String> newOrder = [
                                        ...pinnedSupps.map((e) => e.id),
                                        ...pinnedStacks.map((e) => e.id),
                                      ];
                                      provider.updatePinnedOrder(newOrder);
                                    },
                                    itemBuilder: (context, index) {
                                      final item = pinnedSupps[index];
                                      return _buildPinnedItemCard(
                                        key: ValueKey(item.id),
                                        name: item.name,
                                        isStack: false,
                                        isLargeScreen: isLargeScreen,
                                      );
                                    },
                                  ),

                                SizedBox(height: isLargeScreen ? 32.0 : 32.h),
                                _buildSectionHeader("PINNED STACKS", isLargeScreen),
                                Text(
                                  "REORDER SUPPLEMENT STACK SHORTCUTS",
                                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                    color: AppColors.textSecondary, 
                                  ),
                                ),
                                SizedBox(height: isLargeScreen ? 16.0 : 16.h),
                                if (pinnedStacks.isEmpty)
                                  _buildEmptyPlaceholder("NO STACKS PINNED", isLargeScreen)
                                else
                                  ReorderableListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: pinnedStacks.length,
                                    proxyDecorator: (child, index, animation) => Material(
                                      type: MaterialType.transparency,
                                      child: child,
                                    ),
                                    onReorder: (oldIdx, newIdx) {
                                      if (newIdx > oldIdx) newIdx--;
                                      final item = pinnedStacks.removeAt(oldIdx);
                                      pinnedStacks.insert(newIdx, item);
                                      
                                      final List<String> newOrder = [
                                        ...pinnedSupps.map((e) => e.id),
                                        ...pinnedStacks.map((e) => e.id),
                                      ];
                                      provider.updatePinnedOrder(newOrder);
                                    },
                                    itemBuilder: (context, index) {
                                      final item = pinnedStacks[index];
                                      return _buildPinnedItemCard(
                                        key: ValueKey(item.id),
                                        name: item.name,
                                        isStack: true,
                                        isLargeScreen: isLargeScreen,
                                      );
                                    },
                                  ),
                                
                                SizedBox(height: isLargeScreen ? 40.0 : 40.h),
                              ],
                            ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPlaceholder(String message, bool isLargeScreen) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 40.0 : 40.h),
        child: Text(
          message,
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isLargeScreen) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLargeScreen ? 12.0 : 12.h, 
        left: isLargeScreen ? 4.0 : 4.w
      ),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.crimson,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required String subtitle,
    required bool value,
    required bool isLargeScreen,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLargeScreen ? 12.0 : 12.h),
      padding: EdgeInsets.all(isLargeScreen ? 16.0 : 16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.white, 
                  fontWeight: FontWeight.w500,
                )),
                Text(subtitle, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary, 
                  letterSpacing: 0
                )),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppColors.crimson,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedItemCard({
    required Key key,
    required String name,
    required bool isStack,
    required bool isLargeScreen,
  }) {
    return Container(
      key: key,
      margin: EdgeInsets.only(bottom: isLargeScreen ? 8.0 : 8.h),
      padding: EdgeInsets.all(isLargeScreen ? 12.0 : 12.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(
            isStack ? Icons.layers_rounded : Icons.medication_rounded,
            color: isStack ? Colors.blueAccent : AppColors.crimson,
            size: isLargeScreen ? 20.0 : 20.r,
          ),
          SizedBox(width: isLargeScreen ? 16.0 : 16.w),
          Expanded(
            child: Text(
              name.toUpperCase(),
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: Colors.white, 
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(
            Icons.drag_handle_rounded, 
            color: AppColors.textSecondary.withValues(alpha: 0.3), 
            size: isLargeScreen ? 20.0 : 20.r
          ),
        ],
      ),
    );
  }
}
