import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../provider/affirmation_provider.dart';
import '../model/affirmation_settings.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';

class AffirmationSettingsSheet extends StatefulWidget {
  final bool isSideSheet;
  const AffirmationSettingsSheet({super.key, this.isSideSheet = false});

  @override
  State<AffirmationSettingsSheet> createState() => _AffirmationSettingsSheetState();

  static void show(BuildContext context) {
    // This static method will be replaced by AdaptiveUtils call in the screen
  }
}

class _AffirmationSettingsSheetState extends State<AffirmationSettingsSheet> {
  final List<String> _units = ['MINUTES', 'HOURS', 'DAYS'];
  late FixedExtentScrollController _valueController;
  late FixedExtentScrollController _unitController;
  
  int _selectedValue = 1;
  int _selectedUnitIdx = 0;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AffirmationProvider>().settings;
    _parseMinutes(settings.rotationMinutes);
    _valueController = FixedExtentScrollController(initialItem: _selectedValue - 1);
    _unitController = FixedExtentScrollController(initialItem: _selectedUnitIdx);
    
    _valueController.addListener(() => setState(() {}));
    _unitController.addListener(() => setState(() {}));
  }

  void _parseMinutes(int totalMins) {
    if (totalMins >= 1440 && totalMins % 1440 == 0) {
      _selectedValue = totalMins ~/ 1440;
      _selectedUnitIdx = 2; // DAYS
    } else if (totalMins >= 60 && totalMins % 60 == 0) {
      _selectedValue = totalMins ~/ 60;
      _selectedUnitIdx = 1; // HOURS
    } else {
      _selectedValue = totalMins;
      _selectedUnitIdx = 0; // MINUTES
    }
  }

  void _updateSettings() {
    int multiplier = 1;
    if (_selectedUnitIdx == 1) multiplier = 60;
    if (_selectedUnitIdx == 2) multiplier = 1440;
    
    final totalMins = _selectedValue * multiplier;
    context.read<AffirmationProvider>().updateSettings(
      context.read<AffirmationProvider>().settings.copyWith(rotationMinutes: totalMins)
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600 && !widget.isSideSheet;
        final double sheetWidth = widget.isSideSheet ? constraints.maxWidth : (isCompact ? constraints.maxWidth : 500.0);

        return Align(
          alignment: widget.isSideSheet ? Alignment.center : Alignment.bottomCenter,
          child: SizedBox(
            width: sheetWidth,
            child: Consumer<AffirmationProvider>(
              builder: (context, provider, _) {
                final settings = provider.settings;

                return Container(
                  height: widget.isSideSheet ? double.infinity : null,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: widget.isSideSheet 
                      ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                      : BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    isCompact ? 24.w : 24.0, 
                    widget.isSideSheet ? 0 : (isCompact ? 20.h : 16.0), 
                    isCompact ? 24.w : 24.0, 
                    MediaQuery.of(context).viewInsets.bottom + (isCompact ? 40.h : 32.0)
                  ),
                  child: Column(
                    mainAxisSize: widget.isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isSideSheet) SizedBox(height: 24.0),
                      if (!widget.isSideSheet)
                        Center(
                          child: Container(
                            width: isCompact ? 40.w : 40.0,
                            height: isCompact ? 4.h : 4.0,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          ),
                        ),
                      if (!widget.isSideSheet) SizedBox(height: isCompact ? 24.h : 20.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "ROTATION SETTINGS", 
                            style: AppTextStyles.h3.adaptive(context)
                          ),
                          if (widget.isSideSheet)
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                        ],
                      ),
                      SizedBox(height: isCompact ? 32.h : 24.0),

                      _buildSectionLabel("ROTATION FREQUENCY", isCompact),
                      Container(
                        height: isCompact ? 150.h : 120.0,
                        decoration: BoxDecoration(
                          color: AppColors.background.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
                          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: _valueController,
                                itemExtent: isCompact ? 40.h : 36.0,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  _selectedValue = index + 1;
                                  _updateSettings();
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: 60,
                                  builder: (context, index) {
                                    double opacity = 0.2;
                                    if (_valueController.hasClients) {
                                      final double itemExtent = isCompact ? 40.h : 36.0;
                                      final double currentPage = _valueController.offset / itemExtent;
                                      final double diff = (currentPage - index).abs();
                                      opacity = (1.0 - (diff * 0.7)).clamp(0.2, 1.0);
                                    } else if (index == _selectedValue - 1) {
                                      opacity = 1.0;
                                    }
                                    return Center(
                                      child: Opacity(
                                        opacity: opacity,
                                        child: Text(
                                          "${index + 1}",
                                          style: AppTextStyles.h3.adaptive(context).copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListWheelScrollView.useDelegate(
                                controller: _unitController,
                                itemExtent: isCompact ? 40.h : 36.0,
                                physics: const FixedExtentScrollPhysics(),
                                onSelectedItemChanged: (index) {
                                  _selectedUnitIdx = index;
                                  _updateSettings();
                                },
                                childDelegate: ListWheelChildBuilderDelegate(
                                  childCount: _units.length,
                                  builder: (context, index) {
                                    double opacity = 0.2;
                                    if (_unitController.hasClients) {
                                      final double itemExtent = isCompact ? 40.h : 36.0;
                                      final double currentPage = _unitController.offset / itemExtent;
                                      final double diff = (currentPage - index).abs();
                                      opacity = (1.0 - (diff * 0.7)).clamp(0.2, 1.0);
                                    } else if (index == _selectedUnitIdx) {
                                      opacity = 1.0;
                                    }
                                    return Center(
                                      child: Opacity(
                                        opacity: opacity,
                                        child: Text(
                                          _units[index],
                                          style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                                            color: AppColors.crimson,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isCompact ? 32.h : 24.0),

                      _buildSectionLabel("ROTATION MODE", isCompact),
                      Wrap(
                        spacing: isCompact ? 8.w : 8.0,
                        runSpacing: isCompact ? 8.h : 8.0,
                        children: [
                          _buildModeChip("random", "RANDOM", settings, provider, isCompact: isCompact),
                          _buildModeChip("continuous", "CONTINUOUS", settings, provider, isCompact: isCompact),
                        ],
                      ),
                      SizedBox(height: isCompact ? 32.h : 24.0),

                      _buildSectionLabel("ORDER BY", isCompact),
                      Opacity(
                        opacity: settings.rotationMode == 'random' ? 0.3 : 1.0,
                        child: IgnorePointer(
                          ignoring: settings.rotationMode == 'random',
                          child: Row(
                            children: [
                              _buildOrderChip("asc", "ASCENDING", settings, provider, isCompact: isCompact),
                              SizedBox(width: isCompact ? 12.w : 12.0),
                              _buildOrderChip("desc", "DESCENDING", settings, provider, isCompact: isCompact),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 40.h : 32.0),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.crimson,
                            padding: EdgeInsets.symmetric(vertical: isCompact ? 18.h : 14.0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0)),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "SAVE & CLOSE",
                            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeChip(String mode, String label, AffirmationSettings settings, AffirmationProvider provider, {bool isEnabled = true, required bool isCompact}) {
    final isSelected = settings.rotationMode == mode;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.3,
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) provider.updateSettings(settings.copyWith(rotationMode: mode));
          },
          selectedColor: AppColors.crimson,
          backgroundColor: AppColors.surfaceLight.withValues(alpha: 0.1),
          labelStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderChip(String direction, String label, AffirmationSettings settings, AffirmationProvider provider, {required bool isCompact}) {
    final isSelected = settings.orderDirection == direction;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.updateSettings(settings.copyWith(orderDirection: direction)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
            border: Border.all(
              color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: isSelected ? AppColors.crimson : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
