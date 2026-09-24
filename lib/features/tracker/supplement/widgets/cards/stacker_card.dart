// lib/features/tracker/supplement/widgets/stacker_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:rugged/core/navigation/app_routes.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/supplement/model/supplement.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_stack.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:rugged/features/tracker/supplement/widgets/sheets/stack_form_sheet.dart';
import 'package:rugged/features/tracker/supplement/widgets/sheets/stack_notification_sheet.dart';
import 'package:rugged/core/utils/adaptive_utils.dart'; // Import the new sheet
import 'package:rugged/core/widgets/elite_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import 'package:rugged/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/widgets/elite_confirm_dialog.dart';

class StackerCard extends StatefulWidget {
  final SupplementStack stack;
  final bool isCompact;

  const StackerCard({
    super.key, 
    required this.stack,
    this.isCompact = true,
  });

  @override
  State<StackerCard> createState() => _StackerCardState();
}

class _StackerCardState extends State<StackerCard> {
  bool _isManagementExpanded = false;
  final Map<String, bool> _isRecordMode = {};
  final Map<String, bool> _useServings = {};
  final Map<String, TextEditingController> _controllers = {};

  // State for the log date and time
  DateTime _selectedDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncStateFromStack();
  }

  @override
  void didUpdateWidget(covariant StackerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the stack items have changed, we need to ensure we have controllers for them
    if (oldWidget.stack.items.length != widget.stack.items.length ||
        !oldWidget.stack.items.every((item) => widget.stack.items.any((newItem) => newItem.id == item.id))) {
      _syncStateFromStack();
    }
  }

  void _syncStateFromStack() {
    for (var item in widget.stack.items) {
      // Use existing state if we already have it (to prevent resetting user input on rebuild)
      if (!_controllers.containsKey(item.id)) {
        _isRecordMode[item.id] = widget.stack.pinnedRecordModes[item.id] ?? true;
        _useServings[item.id] = widget.stack.pinnedUseServings[item.id] ?? true;
        double initialAmount = widget.stack.pinnedAmounts[item.id] ?? 1.0;
        _controllers[item.id] =
            TextEditingController(text: initialAmount.toString());
        _controllers[item.id]!.addListener(() => setState(() {}));
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allValuesValid {
    for (var controller in _controllers.values) {
      final val = double.tryParse(controller.text) ?? 0;
      if (val <= 0) return false;
    }
    return true;
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      useRootNavigator: true,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppColors.crimson,
                onPrimary: Colors.white,
                surface: AppColors.surface,
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          ),
        ),
      ),
    );

    if (pickedDate != null) {
      if (!mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        useRootNavigator: true,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        builder: (context, child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: child!,
          ),
        ),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplementProvider>();

    final List<Map<String, dynamic>> itemsWithStatus = widget.stack.items.map((
      item,
    ) {
      final libraryItem = provider.library.firstWhere(
        (libItem) => libItem.id == item.id,
        orElse: () => item.copyWith(isActive: false),
      );
      // Ensure we check both the library existence AND the isActive flag
      final bool effectivelyActive = libraryItem.isActive;
      return {'item': libraryItem, 'isActive': effectivelyActive};
    }).toList();

    final int activeCount = itemsWithStatus.where((e) => e['isActive'] == true).length;
    final bool hasInvalidItems = itemsWithStatus.any((e) => e['isActive'] == false);
    
    // Check for stock issues on current settings
    bool hasStockIssue = false;
    for (var data in itemsWithStatus) {
      if (data['isActive'] == false) continue;
      final Supplement item = data['item'];
      if (_isRecordMode[item.id] == true) {
        final double amount = double.tryParse(_controllers[item.id]?.text ?? "0") ?? 0.0;
        final bool servings = _useServings[item.id] ?? true;
        double needed = servings ? (amount * item.weightPerServing) : amount;
        if ((item.remainingStock ?? 0) < (needed - 0.0001)) {
          hasStockIssue = true;
          break;
        }
      }
    }
    
    // A stack is disabled if any item is missing/inactive OR if it has fewer than 2 valid items
    // OR if there is a stock issue for an intake item
    final bool isStackDisabled = hasInvalidItems || activeCount < 2 || hasStockIssue;

    final bool isCompact = widget.isCompact;

    return Opacity(
      opacity: isStackDisabled ? 0.6 : 1.0,
      child: Container(
        margin: EdgeInsets.only(bottom: isCompact ? 16.h : 12.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
          border: Border.all(
            color: isStackDisabled
                ? AppColors.crimson.withValues(alpha: 0.3)
                : AppColors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(provider, isStackDisabled, isCompact),
            if (_isManagementExpanded) _buildManagementDrawer(context, isCompact),
            if (isStackDisabled)
              _buildLockedCompositionView(itemsWithStatus, activeCount, isCompact)
            else
              _buildActiveFunctionalView(itemsWithStatus, isCompact),
            if (!isStackDisabled) SizedBox(height: isCompact ? 16.h : 12.0),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(SupplementProvider provider, bool isDeactivated, bool isCompact) {
    final bool isPinnedToHome = widget.stack.isPinnedToHome;
    final bool valid = _allValuesValid;

    return Padding(
      padding: EdgeInsets.fromLTRB(isCompact ? 24.w : 20.0, isCompact ? 24.h : 20.0, isCompact ? 16.w : 14.0, isCompact ? 12.h : 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.stack.name.toUpperCase(),
                  style: AppTextStyles.h3.adaptive(context).copyWith(
                    color: isDeactivated
                        ? AppColors.textSecondary
                        : AppColors.white,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.stack.sharedBy != null) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(isCompact ? 6.r : 4.0),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_rounded, color: Colors.blueAccent, size: isCompact ? 10.r : 10.0),
                        SizedBox(width: 4.w),
                        Text(
                          "SHARED BY ${widget.stack.sharedBy!.toUpperCase()}",
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),

          if (!isDeactivated) ...[
            _buildQuickActionButton(
              icon: isPinnedToHome ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              isActive: isPinnedToHome,
              opacity: valid ? 1.0 : 0.3,
              isCompact: isCompact,
              onTap: valid
                  ? () {
                      if (isPinnedToHome) {
                        bool matches = true;
                        for (var item in widget.stack.items) {
                          if ((_isRecordMode[item.id] ?? true) != (widget.stack.pinnedRecordModes[item.id] ?? true) ||
                              (_useServings[item.id] ?? true) != (widget.stack.pinnedUseServings[item.id] ?? true) ||
                              (double.tryParse(_controllers[item.id]?.text ?? "0") ?? 0.0) != (widget.stack.pinnedAmounts[item.id] ?? 0.0)) {
                            matches = false;
                            break;
                          }
                        }

                        if (matches) {
                          _showUnpinConfirmation(provider);
                        } else {
                          _showUpdatePinConfirmation(provider);
                        }
                      } else {
                        _showPinConfirmation(provider);
                      }
                    }
                  : () {},
            ),
            SizedBox(width: 8.w),
            _buildQuickActionButton(
              icon: widget.stack.notificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              isActive: widget.stack.notificationsEnabled,
              opacity: valid ? 1.0 : 0.3,
              isCompact: isCompact,
              onTap: valid
                  ? () => _openNotificationSheet(context)
                  : () {},
            ),
            SizedBox(width: 8.w),
            Consumer<AuthProvider>(
              builder: (context, authProv, _) {
                final bool isPro = authProv.isPro;
                return _buildQuickActionButton(
                  icon: isPro ? Icons.ios_share_rounded : Icons.lock_rounded,
                  isActive: false,
                  isCompact: isCompact,
                  onTap: () async {
                    if (!isPro) {
                      context.push(AppRoutes.proUpgrade);
                      return;
                    }
                    final userName = authProv.displayName;
                    final link = await provider.generateStackShareLink(widget.stack, userName);
                    
                    if (link != null) {
                      await Share.share(
                        "CHECK OUT THIS SUPPLEMENT STACK SHARED BY $userName IN RUGGED:\n\n$link",
                        subject: "SUPPLEMENT STACK SHARED BY $userName",
                      );
                    }
                  },
                );
              },
            ),
            SizedBox(width: 8.w),
          ],

          _buildQuickActionButton(
            icon: _isManagementExpanded
                ? Icons.close_rounded
                : Icons.more_vert_rounded,
            isActive: _isManagementExpanded,
            isCompact: isCompact,
            onTap: () =>
                setState(() => _isManagementExpanded = !_isManagementExpanded),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required bool isCompact,
    double opacity = 1.0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: EdgeInsets.all(isCompact ? 8.r : 6.0),
          decoration: BoxDecoration(
            color: isActive ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(isCompact ? 10.r : 8.0),
            border: Border.all(
              color: isActive ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Icon(
            icon,
            color: isActive ? AppColors.crimson : AppColors.textSecondary,
            size: isCompact ? 18.r : 16.0,
          ),
        ),
      ),
    );
  }

  /*
  Widget _headerIcon(...) { ... }
  */

  Widget _buildLockedCompositionView(
    List<Map<String, dynamic>> itemsWithStatus,
    int activeCount,
    bool isCompact,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isCompact ? 16.w : 14.0, isCompact ? 8.h : 6.0, isCompact ? 16.w : 14.0, isCompact ? 20.h : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "STACK COMPONENTS",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                activeCount < 2 ? "INVALID STACK" : "REACTIVATION REQUIRED",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.crimson,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 12.h : 10.0),
          ...itemsWithStatus.map((data) {
            final Supplement item = data['item'];
            final bool isActive = data['isActive'];
            return Container(
              margin: EdgeInsets.only(bottom: isCompact ? 6.h : 4.0),
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 12.w : 10.0, vertical: isCompact ? 10.h : 8.0),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: Border.all(
                  color: isActive
                      ? Colors.transparent
                      : AppColors.crimson.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: isActive ? Colors.white24 : AppColors.crimson,
                    size: isCompact ? 14.r : 14.0,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      item.name.toUpperCase(),
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: isActive
                            ? AppColors.white.withValues(alpha: 0.6)
                            : AppColors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!isActive)
                    Text(
                      item.name == "Deleted Item" ? "DELETED" : "INACTIVE",
                      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                        color: AppColors.crimson,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            );
          }),
          if (activeCount < 2)
            Padding(
              padding: EdgeInsets.only(top: isCompact ? 12.h : 10.0),
              child: Text(
                "A stack must have at least 2 active supplements. Please modify this stack to continue.",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveFunctionalView(List<Map<String, dynamic>> itemsWithStatus, bool isCompact) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 14.0),
          itemCount: itemsWithStatus.length,
          itemBuilder: (context, index) =>
              _buildSupplementRow(itemsWithStatus[index]['item'], isCompact),
        ),
        _buildDateTimeSelector(isCompact),
        SizedBox(height: isCompact ? 8.h : 6.0),
        _buildExecuteButton(isCompact),
      ],
    );
  }

  Widget _buildDateTimeSelector(bool isCompact) {
    String formatted =
        "${_selectedDateTime.day}/${_selectedDateTime.month} @ ${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}";
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 14.0),
      child: GestureDetector(
        onTap: _pickDateTime,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 10.0, horizontal: isCompact ? 16.w : 14.0),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: AppColors.crimson,
                size: isCompact ? 16.r : 14.0,
              ),
              SizedBox(width: 12.w),
              Text(
                "LOG DATE & TIME",
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                formatted,
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.edit_calendar_rounded,
                color: AppColors.white.withValues(alpha: 0.2),
                size: isCompact ? 14.r : 12.0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementDrawer(BuildContext context, bool isCompact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isCompact ? 16.w : 14.0, isCompact ? 8.h : 6.0, isCompact ? 16.w : 14.0, isCompact ? 12.h : 10.0),
      child: Row(
        children: [
          Expanded(
            child: _drawerBtn(
              context,
              Icons.edit_document,
              "MODIFY",
              AppColors.textSecondary,
              () => _openEdit(context),
              isCompact,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _drawerBtn(
              context,
              Icons.delete_sweep_rounded,
              "DELETE",
              AppColors.crimson,
              () => _confirmDelete(context),
              isCompact,
            ),
          ),
        ],
      ),
    );
  }

  void _showUnpinConfirmation(SupplementProvider provider) async {
    final confirm = await EliteConfirmDialog.show(
      context,
      title: "REMOVE FROM HOME",
      message: "Are you sure you want to remove '${widget.stack.name.toUpperCase()}' from your home screen shortcuts?",
      confirmText: "REMOVE",
      icon: Icons.push_pin_rounded,
    );

    if (confirm == true) {
      provider.toggleStackHomePin(
        stackId: widget.stack.id,
        recordModes: {},
        useServings: {},
        amounts: {},
      );
    }
  }

  void _showUpdatePinConfirmation(SupplementProvider provider) {
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
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.update_rounded,
                    color: Colors.orange,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "UPDATE PRESET",
                  style: AppTextStyles.h3.adaptive(context).copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Your current configuration differs from the pinned home screen shortcut. Would you like to update the preset or remove it?",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 12.w : 12.0, 0, isCompact ? 12.w : 12.0, isCompact ? 8.h : 8.0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        provider.toggleStackHomePin(
                          stackId: widget.stack.id,
                          recordModes: Map.from(_isRecordMode),
                          useServings: Map.from(_useServings),
                          amounts: _controllers.map(
                            (id, c) => MapEntry(id, double.tryParse(c.text) ?? 0.0),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      child: Container(
                        height: isCompact ? 48.h : 44.0,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.crimson,
                          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "UPDATE PRESET",
                          style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 8.h : 8.0),
                    Row(
                      children: [
                        Expanded(
                          child: _dialogBtn(
                            context,
                            "CANCEL",
                            Colors.transparent,
                            AppColors.textSecondary,
                            () => Navigator.pop(context),
                            isCompact: isCompact,
                          ),
                        ),
                        SizedBox(width: isCompact ? 8.w : 6.0),
                        Expanded(
                          child: _dialogBtn(
                            context,
                            "REMOVE PIN",
                            Colors.transparent,
                            AppColors.crimson,
                            () {
                              provider.toggleStackHomePin(
                                stackId: widget.stack.id,
                                recordModes: {},
                                useServings: {},
                                amounts: {},
                              );
                              Navigator.pop(context);
                            },
                            isCompact: isCompact,
                          ),
                        ),
                      ],
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

  void _showPinConfirmation(SupplementProvider provider) {
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
                    Icons.push_pin_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "PIN TO HOME",
                  style: AppTextStyles.h3.adaptive(context).copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Confirming current configuration as a home screen preset.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.stack.items.map((item) {
                      final isRecord = _isRecordMode[item.id] ?? true;
                      final servings = _useServings[item.id] ?? true;
                      final amount = _controllers[item.id]?.text ?? "0";
                      final unit = servings ? item.servingUnit : item.weightUnit;
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: isCompact ? 6.h : 6.0),
                        child: Row(
                          children: [
                            Icon(
                              isRecord
                                  ? Icons.remove_circle_outline
                                  : Icons.add_circle_outline,
                              size: isCompact ? 14.r : 14.0,
                              color: isRecord ? AppColors.crimson : Colors.green,
                            ),
                            SizedBox(width: isCompact ? 12.w : 12.0),
                            Expanded(
                              child: Text(
                                "${isRecord ? 'RECORD' : 'RESTOCK'} $amount $unit OF ${item.name}"
                                    .toUpperCase(),
                                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 12.w : 12.0, 0, isCompact ? 12.w : 12.0, isCompact ? 16.h : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _dialogBtn(
                        context,
                        "CANCEL",
                        Colors.transparent,
                        AppColors.textSecondary,
                        () => Navigator.pop(context),
                        isCompact: isCompact,
                      ),
                    ),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Expanded(
                      child: _dialogBtn(
                        context,
                        "CONFIRM",
                        AppColors.crimson,
                        Colors.white,
                        () {
                          provider.toggleStackHomePin(
                            stackId: widget.stack.id,
                            recordModes: Map.from(_isRecordMode),
                            useServings: Map.from(_useServings),
                            amounts: _controllers.map(
                              (id, c) =>
                                  MapEntry(id, double.tryParse(c.text) ?? 0.0),
                            ),
                          );
                          Navigator.pop(context);
                        },
                        isCompact: isCompact,
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

  // UPDATED: Standardized to match identical styling scheme of Pin Confirmation Dialog
  void _showExecuteConfirmation() {
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
                    Icons.checklist_rtl_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "CONFIRM EXECUTION",
                  style: AppTextStyles.h3.adaptive(context).copyWith(
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Record all items in '${widget.stack.name.toUpperCase()}' for the selected date/time?",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 12.w : 12.0, 0, isCompact ? 12.w : 12.0, isCompact ? 16.h : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _dialogBtn(
                        context,
                        "CANCEL",
                        Colors.transparent,
                        AppColors.textSecondary,
                        () => Navigator.pop(context),
                        isCompact: isCompact,
                      ),
                    ),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Expanded(
                      child: _dialogBtn(
                        context,
                        "EXECUTE",
                        AppColors.crimson,
                        Colors.white,
                        () {
                          final provider = context.read<SupplementProvider>();
                          if (provider.isStackProcessing) return;

                          provider.executeStackLog(
                            stack: widget.stack,
                            recordModes: _isRecordMode,
                            useServings: _useServings,
                            amounts: _controllers.map(
                              (id, c) =>
                                  MapEntry(id, double.tryParse(c.text) ?? 0.0),
                            ),
                            selectedDateTime: _selectedDateTime,
                          );

                          Navigator.pop(context);
                          EliteSnackbar.show(
                            context,
                            "STACK LOGGED: ${widget.stack.name.toUpperCase()}",
                            onUndo: () => provider.deleteLastEntry(),
                          );
                        },
                        isCompact: isCompact,
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

  Widget _buildSupplementRow(Supplement item, bool isCompact) {
    bool isRecord = _isRecordMode[item.id] ?? true;
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 8.h : 6.0),
      padding: EdgeInsets.all(isCompact ? 12.r : 10.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name.toUpperCase(),
                  style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _unitToggle(item, isCompact),
            ],
          ),
          SizedBox(height: isCompact ? 12.h : 10.0),
          Row(
            children: [
              _modeToggleChip(
                "RECORD",
                isRecord,
                () => setState(() => _isRecordMode[item.id] = true),
                isCompact,
              ),
              SizedBox(width: 8.w),
              _modeToggleChip(
                "RESTOCK",
                !isRecord,
                () => setState(() => _isRecordMode[item.id] = false),
                isCompact,
              ),
              const Spacer(),
              _valueInput(item.id, isCompact),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecuteButton(bool isCompact) {
    final valid = _allValuesValid;
    final bool hasZeroValue = _controllers.values.any((c) {
      final val = double.tryParse(c.text) ?? 0;
      return val <= 0;
    });

    // Check for stock issue again for the button label
    bool hasStockIssue = false;
    for (var controllerEntry in _controllers.entries) {
      final String id = controllerEntry.key;
      if (_isRecordMode[id] == true) {
        final double amount = double.tryParse(controllerEntry.value.text) ?? 0;
        final provider = context.read<SupplementProvider>();
        final item = provider.library.firstWhereOrNull((s) => s.id == id);
        if (item != null) {
          final bool servings = _useServings[id] ?? true;
          double needed = servings ? (amount * item.weightPerServing) : amount;
          if ((item.remainingStock ?? 0) < (needed - 0.0001)) {
            hasStockIssue = true;
            break;
          }
        }
      }
    }

    final bool canExecute = valid && !hasZeroValue && !hasStockIssue;
    String label = "EXECUTE STACK";
    if (!valid || hasZeroValue) {
      label = "DATA REQUIRED";
    } else if (hasStockIssue) {
      label = "INSUFFICIENT STOCK";
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 14.0),
      child: GestureDetector(
        onTap: canExecute ? _showExecuteConfirmation : null,
        child: Container(
          height: isCompact ? 52.h : 44.0,
          width: double.infinity,
          decoration: BoxDecoration(
            color: canExecute
                ? AppColors.crimson
                : AppColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(isCompact ? 14.r : 12.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.buttonPrimary.adaptive(context).copyWith(
              color: canExecute ? Colors.white : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _unitToggle(Supplement item, bool isCompact) {
    bool servings = _useServings[item.id] ?? true;
    return Container(
      height: isCompact ? 30.h : 26.0,
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _unitBtn(
            item.servingUnit,
            servings,
            () => setState(() => _useServings[item.id] = true),
            isCompact,
          ),
          _unitBtn(
            item.weightUnit,
            !servings,
            () => setState(() => _useServings[item.id] = false),
            isCompact,
          ),
        ],
      ),
    );
  }

  Widget _unitBtn(String label, bool active, VoidCallback onTap, bool isCompact) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 10.w : 8.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.crimson : Colors.transparent,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );

  Widget _modeToggleChip(String label, bool isActive, VoidCallback onTap, bool isCompact) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 12.w : 10.0, vertical: isCompact ? 6.h : 4.0),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.crimson.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isActive
                  ? AppColors.crimson
                  : AppColors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: isActive ? AppColors.crimson : AppColors.textSecondary,
            ),
          ),
        ),
      );

  Widget _valueInput(String id, bool isCompact) => Container(
    width: isCompact ? 65.w : 60.0,
    height: isCompact ? 34.h : 30.0,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0),
      border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
    ),
    child: TextField(
      controller: _controllers[id],
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTextStyles.labelSmall.adaptive(context).copyWith(
        fontWeight: FontWeight.w500,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.only(top: 8),
      ),
    ),
  );

  Widget _drawerBtn(BuildContext context, IconData i, String l, Color c, VoidCallback o, bool isCompact) =>
      GestureDetector(
        onTap: o,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 8.0),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: c.withValues(alpha: 0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, color: c, size: isCompact ? 16.r : 14.0),
              SizedBox(width: 8.w),
              Text(
                l,
                style: AppTextStyles.labelSmall.adaptive(context).copyWith(
                  color: c,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );

  void _openNotificationSheet(BuildContext context) => AdaptiveUtils.showAdaptiveSheet(
    context: context,
    sheetBuilder: (sheetContext, isSideSheet) => StackNotificationSheet(
      isSideSheet: isSideSheet,
      stack: widget.stack,
      initialReminders: widget.stack.reminders,
      initialEnabled: widget.stack.notificationsEnabled,
    ),
  );

  void _openEdit(BuildContext context) => AdaptiveUtils.showAdaptiveSheet(
    context: context,
    sheetBuilder: (sheetContext, isSideSheet) => StackFormSheet(
      isSideSheet: isSideSheet,
      existingStack: widget.stack
    ),
  );

  // UPDATED: Standardized to match identical styling scheme of Pin Confirmation Dialog
  void _confirmDelete(BuildContext context) async {
    final confirm = await EliteConfirmDialog.show(
      context,
      title: "DELETE STACK",
      message: "Are you sure you want to delete the stack '${widget.stack.name.toUpperCase()}'?",
    );

    if (confirm == true) {
      if (!context.mounted) return;
      final calorieProvider = context.read<CalorieProvider>();
      context.read<SupplementProvider>().deleteStack(
        widget.stack.id,
        onDeleted: (id, cals, pro, cho, fat) {
          calorieProvider.removeStackFromAllMeals(id, cals, pro, cho, fat);
        }
      );
    }
  }

  Widget _dialogBtn(BuildContext context, String label, Color bg, Color text, VoidCallback onTap, {required bool isCompact}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: bg == Colors.transparent
                  ? AppColors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.adaptive(context).copyWith(
              color: text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
}
