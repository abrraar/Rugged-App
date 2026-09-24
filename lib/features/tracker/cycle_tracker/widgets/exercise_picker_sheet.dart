import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/exercise/model/exercise_template.dart';
import 'package:rugged/features/exercise/provider/exercise_provider.dart';
import 'package:provider/provider.dart';

class ExercisePickerSheet extends StatefulWidget {
  final Function(String) onSelected;
  final bool isSideSheet;

  const ExercisePickerSheet({super.key, required this.onSelected, this.isSideSheet = false});

  @override
  State<ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<ExercisePickerSheet> with SingleTickerProviderStateMixin {
  String _searchQuery = "";
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600 && !widget.isSideSheet;
        final double sheetWidth = widget.isSideSheet ? constraints.maxWidth : (isCompact ? constraints.maxWidth : 600.0);

        return Center(
          child: SizedBox(
            width: sheetWidth,
            child: Container(
              height: widget.isSideSheet ? double.infinity : MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: widget.isSideSheet 
                  ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                  : BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
              ),
              child: Column(
                children: [
                  if (widget.isSideSheet) SizedBox(height: 24.0),
                  if (!widget.isSideSheet) _buildHandle(isCompact),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 24.0),
                    child: Row(
                      mainAxisAlignment: widget.isSideSheet ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                      children: [
                        Text(
                          "PICK EXERCISE", 
                          style: AppTextStyles.h3.adaptive(context)
                        ),
                        if (widget.isSideSheet)
                          IconButton(
                            icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 24.r : 24.0, 
                      isCompact ? 16.r : 16.0, 
                      isCompact ? 24.r : 24.0, 
                      isCompact ? 12.r : 12.0
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: AppTextStyles.inputText.adaptive(context).copyWith(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "SEARCH...",
                        hintStyle: AppTextStyles.inputHint.adaptive(context),
                        prefixIcon: const Icon(Icons.search, color: AppColors.crimson),
                        filled: true,
                        fillColor: AppColors.background.withValues(alpha : 0.5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                      ),
                    ),
                  ),

                  // TABS
                  Container(
                    width: double.infinity,
                    height: isCompact ? 48.h : 44.0,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha : 0.1),
                      border: Border(bottom: BorderSide(color: AppColors.white.withValues(alpha : 0.05))),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.crimson, width: 3)),
                      ),
                      labelColor: AppColors.white,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(fontWeight: FontWeight.w500, letterSpacing: 1.2),
                      tabs: const [
                        Tab(text: 'DEFAULT EXERCISES'),
                        Tab(text: 'MY EXERCISES'),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Consumer<ExerciseProvider>(
                      builder: (context, provider, _) {
                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildExerciseList(provider.defaultTemplates, isCompact),
                            _buildExerciseList(provider.customTemplates, isCompact),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExerciseList(List<ExerciseTemplate> templates, bool isCompact) {
    final filtered = templates
        .where((t) => t.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          "NO EXERCISES FOUND",
          style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 24.0, vertical: isCompact ? 12.h : 12.0),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final t = filtered[index];
        return ListTile(
          onTap: () {
            widget.onSelected(t.name);
            Navigator.pop(context);
          },
          contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 8.h : 6.0),
          title: Text(t.name.toUpperCase(), style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: Colors.white)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.targetMuscles?.toUpperCase() ?? "GENERAL", style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary)),
              SizedBox(height: isCompact ? 4.h : 4.0),
              Container(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.w : 8.0, vertical: isCompact ? 2.h : 2.0),
                decoration: BoxDecoration(
                  color: t.type == ExerciseType.compound ? AppColors.crimson.withValues(alpha : 0.2) : AppColors.white.withValues(alpha : 0.05),
                  borderRadius: BorderRadius.circular(isCompact ? 4.r : 4.0),
                ),
                child: Text(
                  t.type.name.toUpperCase(),
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: t.type == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          trailing: Icon(Icons.add_circle_outline, color: AppColors.crimson, size: isCompact ? 20.r : 20.0),
        );
      },
    );
  }

  Widget _buildHandle(bool isCompact) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 16.0),
        width: isCompact ? 40.w : 40.0,
        height: isCompact ? 4.h : 4.0,
        decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha : 0.2), borderRadius: BorderRadius.circular(2.r)),
      ),
    );
  }
}
