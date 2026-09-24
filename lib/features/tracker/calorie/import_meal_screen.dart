import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/elite_snackbar.dart';

class ImportMealScreen extends StatefulWidget {
  final String shareId;
  final String senderName;

  const ImportMealScreen({super.key, required this.shareId, required this.senderName});

  @override
  State<ImportMealScreen> createState() => _ImportMealScreenState();
}

class _ImportMealScreenState extends State<ImportMealScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _mealData;
  bool _isExpired = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final provider = context.read<CalorieProvider>();
      final data = await provider.fetchSharedMeal(widget.shareId);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (data != null && data.containsKey('expired')) {
            _isExpired = true;
          } else if (data == null) {
            _errorMessage = "COULD NOT RETRIEVE MEAL DATA. THE LINK MIGHT BE INVALID.";
          } else {
            _mealData = data;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "AN UNEXPECTED ERROR OCCURRED WHILE FETCHING MEAL.";
        });
      }
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

    if (_isExpired || _errorMessage != null || _mealData == null) {
      return _buildErrorState();
    }

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
                              "MEAL COMPOSITION",
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: AppColors.textSecondary, 
                                letterSpacing: 2,
                              ),
                            ),
                            SizedBox(height: isCompact ? 12.h : 12.0),
                            _buildMealSummary(isCompact),
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
        "SHARED MEAL",
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
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu_rounded, color: AppColors.crimson, size: isCompact ? 40.r : 36.0),
          SizedBox(height: isCompact ? 12.h : 12.0),
          Text(
            widget.senderName.toUpperCase(),
            style: AppTextStyles.h3.adaptive(context),
          ),
          Text(
            "HAS SHARED A MEAL TEMPLATE WITH YOU",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.5), 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealSummary(bool isCompact) {
    if (_mealData == null) return const SizedBox.shrink();

    final name = (_mealData!['name'] as String?) ?? "UNNAMED MEAL";
    final foodItems = (_mealData!['foodItems'] as String?) ?? "";
    final calories = (_mealData!['calories'] as num?)?.toDouble() ?? 0.0;
    final protein = (_mealData!['protein'] as num?)?.toDouble();
    final carbs = (_mealData!['carbs'] as num?)?.toDouble();
    final fats = (_mealData!['fats'] as num?)?.toDouble();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.toUpperCase(), style: AppTextStyles.h3.adaptive(context).copyWith(
            color: Colors.white, 
          )),
          if (foodItems.isNotEmpty) ...[
            SizedBox(height: isCompact ? 8.h : 8.0),
            Text(foodItems, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: AppColors.textSecondary, 
            )),
          ],
          SizedBox(height: isCompact ? 20.h : 20.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric("CALORIES", calories.toInt().toString(), "KCAL", isCompact),
              if (protein != null) _buildMetric("PROTEIN", protein.toInt().toString(), "G", isCompact),
              if (carbs != null) _buildMetric("CARBS", carbs.toInt().toString(), "G", isCompact),
              if (fats != null) _buildMetric("FATS", fats.toInt().toString(), "G", isCompact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, String unit, bool isCompact) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.5), 
          fontWeight: FontWeight.w500,
        )),
        Text(value, style: AppTextStyles.h3.adaptive(context).copyWith(
          color: AppColors.crimson, 
        )),
        Text(unit, style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.textSecondary.withValues(alpha: 0.3), 
        )),
      ],
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
            if (_mealData == null) return;
            await context.read<CalorieProvider>().importSharedMeal(_mealData!);
            if (mounted) {
              EliteSnackbar.show(context, "MEAL SAVED TO LIBRARY");
              context.go('/tracker/calorie?tab=2'); 
            }
          },
          child: Text("SAVE TO LIBRARY", style: AppTextStyles.labelMedium.adaptive(context).copyWith(
            color: Colors.white, 
            fontWeight: FontWeight.w500,
          )),
        ),
        SizedBox(height: isCompact ? 12.h : 12.0),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
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

  Widget _buildErrorState() {
    final title = _isExpired ? "LINK EXPIRED" : "ERROR OCCURRED";
    final message = _errorMessage ?? (_isExpired 
        ? "THIS SHARED MEAL IS NO LONGER AVAILABLE. SHARE LINKS IN RUGGED ARE VALID FOR 7 DAYS ONLY."
        : "WE ENCOUNTERED A PROBLEM RETRIEVING THIS MEAL. PLEASE ENSURE YOU HAVE A STABLE INTERNET CONNECTION.");

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
                    Icon(
                      _isExpired ? Icons.timer_off_rounded : Icons.error_outline_rounded, 
                      color: AppColors.textSecondary.withValues(alpha: 0.2), 
                      size: isCompact ? 80.r : 70.0
                    ),
                    SizedBox(height: isCompact ? 24.h : 20.0),
                    Text(
                      title, 
                      style: AppTextStyles.h2.adaptive(context).copyWith(
                        letterSpacing: 4,
                      )
                    ),
                    SizedBox(height: isCompact ? 16.h : 16.0),
                    Text(
                      message,
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
