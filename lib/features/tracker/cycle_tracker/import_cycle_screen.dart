import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/elite_snackbar.dart';

class ImportCycleScreen extends StatefulWidget {
  final String shareId;
  final String senderName;

  const ImportCycleScreen({super.key, required this.shareId, required this.senderName});

  @override
  State<ImportCycleScreen> createState() => _ImportCycleScreenState();
}

class _ImportCycleScreenState extends State<ImportCycleScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _cycleData;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final provider = context.read<CycleProvider>();
    final data = await provider.fetchSharedCycle(widget.shareId);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null && data.containsKey('expired')) {
          _isExpired = true;
        } else {
          _cycleData = data;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
      );
    }

    if (_isExpired || _cycleData == null) {
      return _buildExpiredState();
    }

    final List workouts = _cycleData!['workouts'] as List;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.8),
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isCompact ? double.infinity : 480, 
                maxHeight: isCompact ? double.infinity : 680,
              ),
              child: Container(
                margin: EdgeInsets.all(isCompact ? 16.r : 24.0),
                padding: EdgeInsets.all(isCompact ? 20.r : 24.0),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(isCompact),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildWebToAppBanner(context, isCompact),
                            _buildSenderInfo(isCompact),
                            SizedBox(height: isCompact ? 24.h : 20.0),
                            Text(
                              "WORKOUT ARCHITECTURE",
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.textSecondary, 
                                letterSpacing: 2,
                              ),
                            ),
                            SizedBox(height: isCompact ? 12.h : 12.0),
                            ...workouts.asMap().entries.map((entry) => _buildWorkoutSummary(entry.key, entry.value, isCompact)),
                            SizedBox(height: isCompact ? 28.h : 24.0),
                            _buildActions(isCompact),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 24.h : 24.0, 
        horizontal: isCompact ? 24.w : 24.0
      ),
      child: Text(
        "SHARED CYCLE",
        textAlign: TextAlign.center,
        style: AppTextStyles.h2.adaptive(context).copyWith(
          color: AppColors.white, 
          fontWeight: FontWeight.w500, 
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildSenderInfo(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.white.withValues(alpha : 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.person_pin_rounded, color: AppColors.crimson, size: isCompact ? 40.r : 36.0),
          SizedBox(height: isCompact ? 12.h : 12.0),
          Text(
            widget.senderName.toUpperCase(),
            style: AppTextStyles.h3.adaptive(context),
          ),
          Text(
            "HAS SHARED A TRAINING ARCHITECTURE WITH YOU",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary.withValues(alpha : 0.5), 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummary(int index, dynamic workout, bool isCompact) {
    final List exercises = workout['exercises'] as List;
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 16.h : 16.0),
      padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "SESSION ${index + 1}: ${workout['name']}",
            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
              color: AppColors.white, 
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isCompact ? 8.h : 8.0),
          ...exercises.map((ex) => Padding(
            padding: EdgeInsets.only(
              left: isCompact ? 12.w : 12.0, 
              top: isCompact ? 4.h : 4.0
            ),
            child: Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.crimson, size: isCompact ? 12.r : 12.0),
                SizedBox(width: isCompact ? 8.w : 8.0),
                Text(
                  ex['name'].toString().toUpperCase(),
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary, 
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildActions(bool isCompact) {
    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.crimson,
            minimumSize: Size(double.infinity, isCompact ? 56.h : 50.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0)),
          ),
          onPressed: () async {
            await context.read<CycleProvider>().importSharedCycle(_cycleData!);
            if (mounted) {
              EliteSnackbar.show(context, "TEMPLATE SAVED TO LIBRARY");
              // Navigate to the Library tab in the Cycle Tracking screen within the Shell
              context.go('${AppRoutes.cycleTracking}?tab=2');
            }
          },
          child: Text("SAVE AS TEMPLATE", style: AppTextStyles.labelMedium.adaptive(context).copyWith(
            color: Colors.white, 
            fontWeight: FontWeight.w500,
          )),
        ),
        SizedBox(height: isCompact ? 12.h : 12.0),
        TextButton(
          onPressed: () => context.go('${AppRoutes.cycleTracking}?tab=2'),
          child: Text("CANCEL", style: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary,
          )),
        ),
      ],
    );
  }

  Widget _buildWebToAppBanner(BuildContext context, bool isCompact) {
    if (!kIsWeb) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isCompact ? 20.h : 20.0),
      padding: EdgeInsets.all(isCompact ? 14.r : 12.0),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_android_rounded, color: Colors.blueAccent, size: 20),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "HAVE THE RUGGED APP?",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.h),
                Text(
                  "Open this shared item directly in your native app.",
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () async {
              final currentUri = GoRouterState.of(context).uri;
              final customUri = Uri.parse('affulabs://rugged${currentUri.path}?${currentUri.query}');
              if (await canLaunchUrl(customUri)) {
                await launchUrl(customUri);
              }
            },
            child: Text("OPEN APP", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return Center(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 40.r : 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isCompact ? double.infinity : 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_off_rounded, color: AppColors.textSecondary.withValues(alpha : 0.2), size: isCompact ? 80.r : 70.0),
                    SizedBox(height: isCompact ? 24.h : 24.0),
                    Text(
                      "LINK EXPIRED",
                      style: AppTextStyles.h2.adaptive(context).copyWith(
                        letterSpacing: 4,
                      ),
                    ),
                    SizedBox(height: isCompact ? 16.h : 16.0),
                    Text(
                      "THIS SHARED ARCHITECTURE IS NO LONGER AVAILABLE. SHARE LINKS IN RUGGED ARE VALID FOR 7 DAYS ONLY.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.textSecondary, 
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: isCompact ? 40.h : 40.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface, 
                        minimumSize: Size(isCompact ? 200.w : 180.0, isCompact ? 50.h : 46.0)
                      ),
                      onPressed: () => context.go(AppRoutes.home),
                      child: Text("RETURN TO HOME", style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: Colors.white,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

}
