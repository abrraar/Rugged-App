import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_settings_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:rugged/core/widgets/elite_snackbar.dart';
import '../tracker/calorie/provider/calorie_provider.dart';

class CalorieSettingsScreen extends StatefulWidget {
  final bool isEmbedded;
  const CalorieSettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<CalorieSettingsScreen> createState() => _CalorieSettingsScreenState();
}

class _CalorieSettingsScreenState extends State<CalorieSettingsScreen> {
  late TextEditingController _goalController;
  late TextEditingController _proteinController;
  late TextEditingController _carbController;
  late TextEditingController _fatController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CalorieProvider>();
    _goalController = TextEditingController(text: provider.settings.dailyCalorieGoal.toString());
    _proteinController = TextEditingController(text: provider.settings.proteinPercent.toString());
    _carbController = TextEditingController(text: provider.settings.carbPercent.toString());
    _fatController = TextEditingController(text: provider.settings.fatPercent.toString());
  }

  @override
  void dispose() {
    _goalController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _validateAndSaveRatios(String type, String value) {
    if (value.isEmpty) return;
    
    final provider = context.read<CalorieProvider>();
    final currentSettings = provider.settings;
    int? newVal = int.tryParse(value);
    if (newVal == null) return;

    int p = type == 'p' ? newVal : currentSettings.proteinPercent;
    int c = type == 'c' ? newVal : currentSettings.carbPercent;
    int f = type == 'f' ? newVal : currentSettings.fatPercent;

    if (p + c + f > 100) {
      EliteSnackbar.show(context, "TOTAL RATIO CANNOT EXCEED 100%", isError: true);
      
      setState(() {
        if (type == 'p') _proteinController.text = currentSettings.proteinPercent.toString();
        if (type == 'c') _carbController.text = currentSettings.carbPercent.toString();
        if (type == 'f') _fatController.text = currentSettings.fatPercent.toString();
      });
      return;
    }

    provider.updateSettings(currentSettings.copyWith(
      proteinPercent: p,
      carbPercent: c,
      fatPercent: f,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600 && !isLargeScreen;

                return Column(
                  children: [
                    EliteSettingsAppBar(
                      title: "CALORIE SETTINGS", 
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
                                
                                _buildSectionHeader("NUTRITIONAL TARGETS", isLargeScreen),
                                
                                _buildSettingCard(
                                  title: "DAILY CALORIE GOAL",
                                  subtitle: "TOTAL ENERGY INTAKE TARGET",
                                  isLargeScreen: isLargeScreen,
                                  trailing: _buildSmallTextField(
                                    controller: _goalController,
                                    suffix: "KCAL",
                                    maxLength: 5,
                                    isLargeScreen: isLargeScreen,
                                    onChanged: (val) {
                                      int? goal = int.tryParse(val);
                                      if (goal != null) {
                                        provider.updateSettings(settings.copyWith(dailyCalorieGoal: goal));
                                      }
                                    },
                                  ),
                                ),

                                SizedBox(height: isLargeScreen ? 32.0 : 32.h),
                                _buildSectionHeader("MACRO RATIOS (%)", isLargeScreen),

                                _buildSettingCard(
                                  title: "PROTEIN TARGET",
                                  subtitle: "PERCENTAGE OF TOTAL CALORIES",
                                  isLargeScreen: isLargeScreen,
                                  trailing: _buildSmallTextField(
                                    controller: _proteinController,
                                    suffix: "%",
                                    maxLength: 3,
                                    isLargeScreen: isLargeScreen,
                                    onChanged: (val) => _validateAndSaveRatios('p', val),
                                  ),
                                ),

                                _buildSettingCard(
                                  title: "CARBOHYDRATE TARGET",
                                  subtitle: "PERCENTAGE OF TOTAL CALORIES",
                                  isLargeScreen: isLargeScreen,
                                  trailing: _buildSmallTextField(
                                    controller: _carbController,
                                    suffix: "%",
                                    maxLength: 3,
                                    isLargeScreen: isLargeScreen,
                                    onChanged: (val) => _validateAndSaveRatios('c', val),
                                  ),
                                ),

                                _buildSettingCard(
                                  title: "FAT TARGET",
                                  subtitle: "PERCENTAGE OF TOTAL CALORIES",
                                  isLargeScreen: isLargeScreen,
                                  trailing: _buildSmallTextField(
                                    controller: _fatController,
                                    suffix: "%",
                                    maxLength: 3,
                                    isLargeScreen: isLargeScreen,
                                    onChanged: (val) => _validateAndSaveRatios('f', val),
                                  ),
                                ),

                                SizedBox(height: isLargeScreen ? 12.0 : 12.h),
                                Center(
                                  child: Text(
                                    "TOTAL: ${settings.proteinPercent + settings.carbPercent + settings.fatPercent}% / 100%",
                                    style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                      color: (settings.proteinPercent + settings.carbPercent + settings.fatPercent) == 100 
                                          ? Colors.greenAccent 
                                          : AppColors.crimson,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                                SizedBox(height: isLargeScreen ? 32.0 : 32.h),
                                _buildSectionHeader("DISPLAY PREFERENCES", isLargeScreen),

                                _buildToggleCard(
                                  title: "TRACK MACRONUTRIENTS",
                                  subtitle: "SHOW PROTEIN, CARBS, AND FATS",
                                  value: settings.trackMacros,
                                  isLargeScreen: isLargeScreen,
                                  onChanged: (val) {
                                    provider.updateSettings(settings.copyWith(trackMacros: val));
                                  },
                                ),

                                _buildToggleCard(
                                  title: "SHOW REMAINING",
                                  subtitle: "DISPLAY CALORIES LEFT FOR THE DAY",
                                  value: settings.showRemaining,
                                  isLargeScreen: isLargeScreen,
                                  onChanged: (val) {
                                    provider.updateSettings(settings.copyWith(showRemaining: val));
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

  Widget _buildSmallTextField({
    required TextEditingController controller,
    required String suffix,
    required int maxLength,
    required ValueChanged<String> onChanged,
    required bool isLargeScreen,
  }) {
    return Container(
      width: isLargeScreen ? 100.0 : 100.w,
      padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 12.0 : 12.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(isLargeScreen ? 6.0 : 8.r),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: maxLength,
        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.white, 
          fontWeight: FontWeight.w500
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: "",
          border: InputBorder.none,
          suffixText: suffix,
          suffixStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: AppColors.textSecondary
          ),
        ),
        onChanged: onChanged,
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

  Widget _buildSettingCard({required String title, required String subtitle, required Widget trailing, required bool isLargeScreen}) {
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
          trailing,
        ],
      ),
    );
  }

  Widget _buildToggleCard({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged, required bool isLargeScreen}) {
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
          Switch(value: value, activeThumbColor: AppColors.crimson, onChanged: onChanged),
        ],
      ),
    );
  }
}
