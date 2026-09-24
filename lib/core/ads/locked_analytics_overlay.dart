import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/providers/ad_unlock_provider.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/core/ads/ad_service.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';

class LockedAnalyticsOverlay extends StatefulWidget {
  final Widget child;
  final String unlockKey;
  final double? height;
  final bool isCompact;

  const LockedAnalyticsOverlay({
    super.key,
    required this.child,
    required this.unlockKey,
    this.height,
    this.isCompact = false,
  });

  @override
  State<LockedAnalyticsOverlay> createState() => _LockedAnalyticsOverlayState();
}

class _LockedAnalyticsOverlayState extends State<LockedAnalyticsOverlay> {
  bool _isAdLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-load rewarded ad
    AdService().loadRewardedAd();
  }

  void _handleWatchAd(BuildContext context) async {
    setState(() => _isAdLoading = true);

    AdService().showRewardedAd(
      onRewardEarned: () async {
        if (!mounted) return;
        setState(() => _isAdLoading = false);
        final unlockProv = context.read<AdUnlockProvider>();
        await unlockProv.unlockFor6Hours(widget.unlockKey);
        if (!context.mounted) return;
        EliteSnackbar.show(context, "ANALYTICS UNLOCKED FOR 6 HOURS!");
      },
      onAdFailed: () {
        if (!mounted) return;
        setState(() => _isAdLoading = false);
        EliteSnackbar.show(context, "FAILED TO LOAD AD. PLEASE TRY AGAIN.", isError: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTabletOrFoldable = MediaQuery.of(context).size.width >= 600;

    return Consumer2<AdUnlockProvider, AuthProvider>(
      builder: (context, unlockProv, authProv, _) {
        final bool isUnlocked = unlockProv.isUnlocked(widget.unlockKey) || authProv.isPro;

        if (isUnlocked) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              if (!authProv.isPro) // Only show the badge for Ad-Watch users
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: AppColors.crimson.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: AppColors.crimson.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_open_rounded, color: AppColors.crimson, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          "6H UNLOCKED (${unlockProv.remainingTimeText(widget.unlockKey)})",
                          style: TextStyle(
                            color: AppColors.crimson,
                            fontSize: isTabletOrFoldable ? 11.0 : 10.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }

        Widget backgroundContent;
        if (widget.height != null) {
          final double minCardHeight = isTabletOrFoldable ? 260.0 : 230.0;
          final double effectiveHeight = widget.height! < minCardHeight ? minCardHeight : widget.height!;
          backgroundContent = SizedBox(
            height: effectiveHeight,
            width: double.infinity,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Opacity(
                  opacity: 0.15,
                  child: IgnorePointer(child: widget.child),
                ),
              ),
            ),
          );
        } else {
          backgroundContent = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Opacity(
              opacity: 0.15,
              child: IgnorePointer(child: widget.child),
            ),
          );
        }

        return Container(
          height: widget.height,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              backgroundContent,

              // Lock Card Overlay (FittedBox prevents ANY overflow across all screen types)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: AppColors.crimson.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(
                          Icons.auto_graph_rounded,
                          color: AppColors.crimson,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "UNLOCK PERFORMANCE TRENDS",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTabletOrFoldable ? 16.0 : 14.0,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          "Watch a short video ad to unlock interactive charts for 6 hours. Watching ads directly helps us keep servers active and software development free for everyone.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: isTabletOrFoldable ? 13.0 : 12.0,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.crimson,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: _isAdLoading ? null : () => _handleWatchAd(context),
                            icon: _isAdLoading 
                                ? const SizedBox(
                                    width: 14, 
                                    height: 14, 
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                  )
                                : const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 16),
                            label: Text(
                              _isAdLoading ? "LOADING..." : "WATCH AD (6H)",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isTabletOrFoldable ? 12.0 : 11.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.crimson,
                              side: const BorderSide(color: AppColors.crimson),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => context.push(AppRoutes.proUpgrade),
                            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                            label: Text(
                              "GO ELITE",
                              style: TextStyle(
                                fontSize: isTabletOrFoldable ? 12.0 : 11.0,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
