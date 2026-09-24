import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/core/widgets/elite_confirm_dialog.dart';
import 'package:provider/provider.dart';
import 'package:rugged/features/main_wrapper.dart';
import 'package:rugged/core/utils/adaptive_utils.dart';
import 'provider/affirmation_provider.dart';
import 'model/affirmation.dart';

class AffirmationScreen extends StatefulWidget {
  const AffirmationScreen({super.key});

  @override
  State<AffirmationScreen> createState() => _AffirmationScreenState();
}

class _AffirmationScreenState extends State<AffirmationScreen> {
  final TextEditingController _addController = TextEditingController();
  final TextEditingController _speakerController = TextEditingController();

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "affirmation";
  }

  @override
  void dispose() {
    activeSettingsContext.value = "";
    _addController.dispose();
    _speakerController.dispose();
    super.dispose();
  }

  void _enterSelectionMode(String initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      _selectedIds.add(initialId);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }


  void _shareSelectedAffirmations(AffirmationProvider provider) {
    if (_selectedIds.isEmpty) return;

    final authProv = context.read<AuthProvider>();
    if (!authProv.isPro) {
      context.push(AppRoutes.proUpgrade);
      return;
    }

    final selectedList = provider.affirmations.where((a) => _selectedIds.contains(a.id)).toList();
    if (selectedList.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln("DAILY AFFIRMATIONS FROM RUGGED:\n");

    for (int i = 0; i < selectedList.length; i++) {
      final aff = selectedList[i];
      buffer.writeln('${i + 1}. "${aff.text.toUpperCase()}"');
      if (aff.speaker != null && aff.speaker!.isNotEmpty) {
        buffer.writeln('   — ${aff.speaker!.toUpperCase()}');
      }
      if (aff.sharedBy != null && aff.sharedBy!.isNotEmpty) {
        buffer.writeln('   (Shared by @${aff.sharedBy!.toUpperCase()})');
      }
      buffer.writeln();
    }

    Share.share(buffer.toString().trim(), subject: "AFFIRMATIONS SHARED VIA RUGGED");
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AffirmationProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600;
                return Column(
                  children: [
                    _buildHeader(provider, isCompact),
                    Expanded(
                      child: _buildWheelView(provider, isCompact: isCompact),
                    ),
                  ],
                );
              },
            ),
          ),
          floatingActionButton: _isSelectionMode
              ? null
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isCompact = constraints.maxWidth < 600;
                    return FloatingActionButton.extended(
                      onPressed: _showAddBottomSheet,
                      backgroundColor: AppColors.crimson,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0)),
                      icon: Icon(Icons.add_rounded, color: Colors.white, size: isCompact ? 24.r : 20.0),
                      label: Text(
                        "AFFIRMATION",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildHeader(AffirmationProvider provider, bool isCompact) {
    if (_isSelectionMode) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20.w : 24.0, 
          vertical: isCompact ? 10.h : 12.0
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: _exitSelectionMode,
            ),
            Text(
              "${_selectedIds.length} SELECTED", 
              style: AppTextStyles.h2.adaptive(context).copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.crimson,
              )
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<AuthProvider>(
                  builder: (context, authProv, _) {
                    final bool isPro = authProv.isPro;
                    return GestureDetector(
                      onTap: () => _shareSelectedAffirmations(provider),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 14.w : 14.0,
                          vertical: isCompact ? 8.h : 8.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.crimson,
                          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                        ),
                        child: Row(
                          children: [
                            Icon(isPro ? Icons.share_rounded : Icons.lock_rounded, color: Colors.white, size: isCompact ? 16.r : 16.0),
                            SizedBox(width: isCompact ? 6.w : 6.0),
                            Text(
                              isPro ? "SHARE" : "GO PRO TO SHARE",
                              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 20.w : 24.0, 
        vertical: isCompact ? 10.h : 12.0
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            "AFFIRMATIONS", 
            style: AppTextStyles.h2.adaptive(context).copyWith(
              fontWeight: FontWeight.w500,
            )
          ),
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded, 
              color: Colors.white.withValues(alpha: 0.5), 
              size: isCompact ? 22.r : 20.0
            ),
            onPressed: _showInstructions,
          ),
        ],
      ),
    );
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
            ),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 12.r : 12.0),
                  decoration: BoxDecoration(
                    color: AppColors.crimson.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "AFFIRMATION CONTROLS",
                  style: AppTextStyles.h3.adaptive(context).copyWith(
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _instructionRow(Icons.add_circle_outline_rounded, "Tap '+ AFFIRMATION' at the bottom to add your custom quotes.", isCompact),
                SizedBox(height: isCompact ? 16.h : 16.0),
                _instructionRow(Icons.touch_app_rounded, "Long press any affirmation to edit, delete, or multi-select to share.", isCompact),
                SizedBox(height: isCompact ? 16.h : 16.0),
                _instructionRow(Icons.sync_rounded, "Your affirmations are synced automatically across all your devices.", isCompact),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 12.w : 12.0, 0, isCompact ? 12.w : 12.0, isCompact ? 16.h : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                            border: Border.all(color: AppColors.crimson.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "DISMISS",
                            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
                              color: AppColors.crimson,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _instructionRow(IconData icon, String text, bool isCompact) {
    return Row(
      children: [
        Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 18.0),
        SizedBox(width: isCompact ? 12.w : 12.0),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelMedium.adaptive(context).copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWheelView(AffirmationProvider provider, {required bool isCompact}) {
    final items = provider.affirmations;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: isCompact ? 48.r : 40.0,
              color: AppColors.crimson.withValues(alpha: 0.4),
            ),
            SizedBox(height: isCompact ? 16.h : 16.0),
            Text(
              "NO AFFIRMATIONS YET",
              style: AppTextStyles.h3.adaptive(context).copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isCompact ? 8.h : 8.0),
            Text(
              "Tap '+ AFFIRMATION' below to enter your first quote",
              style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double viewportHeight = constraints.maxHeight;
        final double itemHeight = viewportHeight * 0.55; 

        return ListWheelScrollView.useDelegate(
          itemExtent: itemHeight,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 1.5,
          perspective: 0.003,
          squeeze: 1.0,
          overAndUnderCenterOpacity: 0.2,
          useMagnifier: true,
          magnification: 1.15,
          onSelectedItemChanged: (index) {
            debugPrint('Active Affirmation Index: $index');
          },
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: items.length,
            builder: (context, index) {
              final aff = items[index];
              return Center(
                child: _buildItemContent(aff, provider, isCompact),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildItemContent(Affirmation aff, AffirmationProvider provider, bool isCompact) {
    final bool isSelected = _selectedIds.contains(aff.id);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 40.w : 60.0),
      child: GestureDetector(
        onTap: _isSelectionMode ? () => _toggleSelection(aff.id) : null,
        onLongPress: () => _showAffirmationActions(context, provider, aff),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
          decoration: _isSelectionMode
              ? BoxDecoration(
                  color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
                  border: Border.all(
                    color: isSelected ? AppColors.crimson : AppColors.white.withValues(alpha: 0.1),
                    width: isSelected ? 2.0 : 1.0,
                  ),
                )
              : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_isSelectionMode)
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.4),
                    size: isCompact ? 24.r : 20.0,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                '"${aff.text.toUpperCase()}"',
                textAlign: TextAlign.center,
                style: AppTextStyles.displayMedium.adaptive(context).copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              if (aff.speaker != null && aff.speaker!.isNotEmpty) ...[
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "— ${aff.speaker!.toUpperCase()}",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
              if (aff.sharedBy != null && aff.sharedBy!.isNotEmpty) ...[
                SizedBox(height: isCompact ? 12.h : 12.0),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 12.w : 10.0,
                    vertical: isCompact ? 4.h : 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.crimson.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_pin_rounded,
                        color: AppColors.crimson,
                        size: isCompact ? 14.r : 14.0,
                      ),
                      SizedBox(width: isCompact ? 6.w : 6.0),
                      Text(
                        "SHARED BY @${aff.sharedBy!.toUpperCase()}",
                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                          color: AppColors.crimson,
                          fontSize: isCompact ? 10.sp : 10.0,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle(bool isCompact) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 16.0),
    alignment: Alignment.center,
    child: Container(
      width: isCompact ? 40.w : 40.0,
      height: isCompact ? 4.h : 4.0,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3.r),
      ),
    ),
  );

  void _showAffirmationActions(BuildContext context, AffirmationProvider provider, Affirmation aff) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 500.0);

          return Align(
            alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
            child: SizedBox(
              width: sheetWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: isSideSheet ? double.infinity : null,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: isSideSheet 
                      ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                      : BorderRadius.vertical(top: Radius.circular(isSheetCompact ? 32.r : 24.0)),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSideSheet) const SizedBox(height: 24.0),
                        if (!isSideSheet) _buildHandle(isSheetCompact),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            isSheetCompact ? 24.w : 24.0, 
                            0, 
                            isSheetCompact ? 24.w : 24.0, 
                            isSheetCompact ? 32.h : 24.0
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "MANAGE AFFIRMATION", 
                                          style: AppTextStyles.h3.adaptive(context)
                                        ),
                                        SizedBox(height: isSheetCompact ? 8.h : 6.0),
                                        Text(
                                          "Select an action for your custom quote",
                                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                      onPressed: () => Navigator.pop(sheetContext),
                                    ),
                                ],
                              ),
                              SizedBox(height: isSheetCompact ? 32.h : 24.0),
                              _buildActionTile(
                                icon: Icons.checklist_rounded,
                                title: "Select Multiple",
                                subtitle: "Select and share multiple quotes",
                                color: Colors.blueAccent,
                                isCompact: isSheetCompact,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _enterSelectionMode(aff.id);
                                },
                              ),
                              SizedBox(height: isSheetCompact ? 16.h : 12.0),
                              _buildActionTile(
                                icon: Icons.edit_outlined,
                                title: "Edit Affirmation",
                                subtitle: "Modify your quote",
                                color: AppColors.crimson,
                                isCompact: isSheetCompact,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _showEditBottomSheet(aff);
                                },
                              ),
                              SizedBox(height: isSheetCompact ? 16.h : 12.0),
                              _buildActionTile(
                                icon: Icons.delete_outline_rounded,
                                title: "Delete Affirmation",
                                subtitle: "This action cannot be undone",
                                color: AppColors.error,
                                isCompact: isSheetCompact,
                                onTap: () async {
                                  Navigator.pop(sheetContext);
                                  final confirmed = await EliteConfirmDialog.show(
                                    context,
                                    title: "DELETE AFFIRMATION",
                                    message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THIS AFFIRMATION?",
                                  );
                                  if (confirmed == true) {
                                    provider.deleteAffirmation(aff.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16.w : 16.0, 
        vertical: isCompact ? 8.h : 6.0
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0)),
      tileColor: AppColors.background.withValues(alpha: 0.5),
      leading: Container(
        padding: EdgeInsets.all(isCompact ? 8.r : 8.0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: isCompact ? 24.r : 20.0),
      ),
      title: Text(
        title,
        style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: color, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.labelSmall.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
      ),
      onTap: onTap,
    );
  }

  void _showEditBottomSheet(Affirmation aff) {
    _addController.text = aff.text;
    _speakerController.text = aff.speaker ?? "";

    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 500.0);

          return Align(
            alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
            child: SizedBox(
              width: sheetWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: isSideSheet ? double.infinity : null,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: isSideSheet 
                      ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                      : BorderRadius.vertical(top: Radius.circular(isSheetCompact ? 32.r : 24.0)),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (isSideSheet) const SizedBox(height: 24.0),
                      if (!isSideSheet) _buildHandle(isSheetCompact),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: isSheetCompact ? 24.w : 24.0, 
                            right: isSheetCompact ? 24.w : 24.0, 
                            top: isSideSheet ? 0 : 0, 
                            bottom: MediaQuery.of(context).viewInsets.bottom + (isSheetCompact ? 40.h : 32.0)
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "EDIT AFFIRMATION", 
                                    style: AppTextStyles.h3.adaptive(context)
                                  ),
                                  if (isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                      onPressed: () => Navigator.pop(sheetContext),
                                    ),
                                ],
                              ),
                              SizedBox(height: isSheetCompact ? 20.h : 16.0),
                              ListenableBuilder(
                                listenable: _addController,
                                builder: (context, _) {
                                  final text = _addController.text.trim();
                                  final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                                  return TextField(
                                    controller: _addController,
                                    minLines: 5,
                                    maxLines: 10,
                                    style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: Colors.white),
                                    inputFormatters: [
                                      TextInputFormatter.withFunction((oldValue, newValue) {
                                        final lineCount = newValue.text.split('\n').length;
                                        if (lineCount > 10) {
                                          return oldValue;
                                        }
                                        return newValue;
                                      }),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: "Enter custom quote...",
                                      hintStyle: AppTextStyles.labelMedium.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                      counterText: "$wordCount / 60 WORDS",
                                      counterStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                        color: wordCount > 60 ? AppColors.error : AppColors.textSecondary,
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0),
                                        borderSide: const BorderSide(color: AppColors.crimson),
                                      ),
                                    ),
                                  );
                                }
                              ),
                              SizedBox(height: isSheetCompact ? 16.h : 12.0),
                              TextField(
                                controller: _speakerController,
                                maxLength: 20,
                                style: TextStyle(color: Colors.white, fontSize: isSheetCompact ? 14.sp : 14.0),
                                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                                decoration: InputDecoration(
                                  hintText: "Who is the speaker?",
                                  hintStyle: AppTextStyles.labelMedium.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0),
                                    borderSide: const BorderSide(color: AppColors.crimson),
                                  ),
                                ),
                              ),
                              SizedBox(height: isSheetCompact ? 24.h : 20.0),
                              ListenableBuilder(
                                listenable: _addController,
                                builder: (context, _) {
                                  final text = _addController.text.trim();
                                  final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                                  final isValid = text.isNotEmpty && wordCount <= 60;
                                  return GestureDetector(
                                    onTap: isValid ? () {
                                      final provider = context.read<AffirmationProvider>();
                                      provider.updateAffirmation(
                                        aff.copyWith(
                                          text: text,
                                          speaker: _speakerController.text.trim().isEmpty ? null : _speakerController.text.trim(),
                                        ),
                                      );
                                      Navigator.pop(sheetContext);
                                    } : null,
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(vertical: isSheetCompact ? 14.h : 12.0),
                                      decoration: BoxDecoration(
                                        color: isValid ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "UPDATE",
                                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                          color: isValid ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.3),
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddBottomSheet() {
    _addController.clear();
    _speakerController.clear();

    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 500.0);

          return Align(
            alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
            child: SizedBox(
              width: sheetWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: isSideSheet ? double.infinity : null,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: isSideSheet 
                      ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                      : BorderRadius.vertical(top: Radius.circular(isSheetCompact ? 32.r : 24.0)),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (isSideSheet) const SizedBox(height: 24.0),
                      if (!isSideSheet) _buildHandle(isSheetCompact),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: isSheetCompact ? 24.w : 24.0, 
                            right: isSheetCompact ? 24.w : 24.0, 
                            top: isSideSheet ? 0 : 0, 
                            bottom: MediaQuery.of(context).viewInsets.bottom + (isSheetCompact ? 40.h : 32.0)
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "ADD AFFIRMATION", 
                                    style: AppTextStyles.h3.adaptive(context)
                                  ),
                                  if (isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                      onPressed: () => Navigator.pop(sheetContext),
                                    ),
                                ],
                              ),
                              SizedBox(height: isSheetCompact ? 20.h : 16.0),
                              ListenableBuilder(
                                listenable: _addController,
                                builder: (context, _) {
                                  final text = _addController.text.trim();
                                  final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                                  return TextField(
                                    controller: _addController,
                                    minLines: 5,
                                    maxLines: 10,
                                    style: AppTextStyles.labelMedium.adaptive(context).copyWith(color: Colors.white),
                                    inputFormatters: [
                                      TextInputFormatter.withFunction((oldValue, newValue) {
                                        final lineCount = newValue.text.split('\n').length;
                                        if (lineCount > 10) {
                                          return oldValue;
                                        }
                                        return newValue;
                                      }),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: "Enter quote...",
                                      hintStyle: AppTextStyles.labelMedium.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                      counterText: "$wordCount / 60 WORDS",
                                      counterStyle: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                        color: wordCount > 60 ? AppColors.error : AppColors.textSecondary,
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0),
                                        borderSide: const BorderSide(color: AppColors.crimson),
                                      ),
                                    ),
                                  );
                                }
                              ),
                              SizedBox(height: isSheetCompact ? 16.h : 12.0),
                              TextField(
                                controller: _speakerController,
                                maxLength: 20,
                                style: TextStyle(color: Colors.white, fontSize: isSheetCompact ? 14.sp : 14.0),
                                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                                decoration: InputDecoration(
                                  hintText: "Who is the speaker?",
                                  hintStyle: AppTextStyles.labelMedium.adaptive(context).copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0),
                                    borderSide: const BorderSide(color: AppColors.crimson),
                                  ),
                                ),
                              ),
                              SizedBox(height: isSheetCompact ? 24.h : 20.0),
                              ListenableBuilder(
                                listenable: _addController,
                                builder: (context, _) {
                                  final text = _addController.text.trim();
                                  final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                                  final isValid = text.isNotEmpty && wordCount <= 60;
                                  return GestureDetector(
                                    onTap: isValid ? () {
                                      final provider = context.read<AffirmationProvider>();
                                      provider.addAffirmation(
                                        text,
                                        speaker: _speakerController.text.trim().isEmpty ? null : _speakerController.text.trim(),
                                      );
                                      Navigator.pop(sheetContext);
                                    } : null,
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.symmetric(vertical: isSheetCompact ? 14.h : 12.0),
                                      decoration: BoxDecoration(
                                        color: isValid ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        "ADD",
                                        style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                          color: isValid ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.3),
                                          fontWeight: FontWeight.w500,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
