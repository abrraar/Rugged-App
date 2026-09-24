// lib/core/widgets/sync_status_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/providers/sync_provider.dart';
import 'package:provider/provider.dart';

class SyncStatusOverlay extends StatelessWidget {
  const SyncStatusOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProv, child) {
        final bool isVisible = syncProv.state != SyncUIState.idle;
        
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          bottom: isVisible ? 110.h : -120.h,
          left: 0,
          right: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400), // Standard snackbar width
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildContent(syncProv),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(SyncProvider syncProv) {
    switch (syncProv.state) {
      case SyncUIState.online:
        return _StatusCard(
          key: const ValueKey('online'),
          icon: Icons.wifi_rounded,
          iconColor: Colors.greenAccent,
          message: "INTERNET CONNECTION RESTORED",
          subMessage: "WELCOME BACK, PROTOCOL ACTIVE",
        );
      case SyncUIState.syncing:
        return _StatusCard(
          key: const ValueKey('syncing'),
          icon: Icons.sync_rounded,
          iconColor: AppColors.crimson,
          message: "SYNCHRONIZING OFFLINE DATA...",
          trailing: "${syncProv.completedItems}/${syncProv.totalItems}",
          showLoading: true,
        );
      case SyncUIState.completed:
        return _StatusCard(
          key: const ValueKey('completed'),
          icon: Icons.check_circle_rounded,
          iconColor: Colors.greenAccent,
          message: "SYNCHRONIZATION COMPLETE",
          subMessage: "ALL CLOUD RECORDS VERIFIED",
          isSuccess: true,
        );
      case SyncUIState.idle:
      return const SizedBox.shrink();
    }
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final String? subMessage;
  final String? trailing;
  final bool showLoading;
  final bool isSuccess;

  const _StatusCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.message,
    this.subMessage,
    this.trailing,
    this.showLoading = false,
    this.isSuccess = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSuccess ? Colors.greenAccent.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildLeadingIcon(),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (subMessage != null || showLoading)
                    Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (subMessage != null)
                            Text(
                              subMessage!,
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          if (showLoading) ...[
                            SizedBox(height: 8.h),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2.r),
                              child: LinearProgressIndicator(
                                value: (trailing != null && trailing!.contains('/'))
                                  ? (() {
                                      try {
                                        final parts = trailing!.split('/');
                                        final current = int.parse(parts[0]);
                                        final total = int.parse(parts[1]);
                                        return total > 0 ? current / total : 0.0;
                                      } catch (_) { return 0.0; }
                                    })()
                                  : null,
                                backgroundColor: AppColors.white.withValues(alpha: 0.05),
                                valueColor: AlwaysStoppedAnimation<Color>(iconColor.withValues(alpha: 0.5)),
                                minHeight: 2.h,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              SizedBox(width: 12.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  trailing!,
                  style: AppTextStyles.h3.adaptive(context).copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    if (showLoading) {
      return SizedBox(
        width: 24.r,
        height: 24.r,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(iconColor),
        ),
      );
    }
    
    return Icon(icon, color: iconColor, size: 24.r);
  }
}
