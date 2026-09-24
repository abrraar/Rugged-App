// lib/features/tracker/supplement/widgets/sheets/stack_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/supplement/model/supplement.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_stack.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class StackFormSheet extends StatefulWidget {
  final SupplementStack? existingStack;
  final bool isSideSheet;

  const StackFormSheet({super.key, this.existingStack, this.isSideSheet = false});

  @override
  State<StackFormSheet> createState() => _StackFormSheetState();
}

class _StackFormSheetState extends State<StackFormSheet> {
  final TextEditingController _stackNameController = TextEditingController();
  final Set<String> _selectedIds = {};

  // Maps to hold the specific settings for each supplement in the stack
  final Map<String, bool> _recordActive = {};
  final Map<String, bool> _recordUseServings = {};
  final Map<String, bool> _restockUseServings = {};
  final Map<String, double> _recordValues = {};

  @override
  void initState() {
    super.initState();
    if (widget.existingStack != null) {
      final stack = widget.existingStack!;
      _stackNameController.text = stack.name;

      for (var item in stack.items) {
        _selectedIds.add(item.id);

        // Initialize explicit settings mapping properties from existing stack if available
        _recordActive[item.id] = stack.pinnedRecordModes[item.id] ?? true;
        _recordUseServings[item.id] = stack.pinnedUseServings[item.id] ?? true;
        _restockUseServings[item.id] = true;
        _recordValues[item.id] = stack.pinnedAmounts[item.id] ?? 1.0;
      }
    }
  }

  @override
  void dispose() {
    _stackNameController.dispose();
    super.dispose();
  }

  bool get _hasValidName => _stackNameController.text.trim().isNotEmpty;
  bool get _hasValidItemCount => _selectedIds.length >= 2;

  /// Compares current form input states with baseline model fields to find mutations
  bool _hasUnsavedModifications() {
    if (widget.existingStack == null) return false;
    final stack = widget.existingStack!;

    // Check if title has changed
    if (_stackNameController.text.trim() != stack.name) {
      return true;
    }

    // Check if selection mapping composition counts or IDs changed
    final currentStackIds = stack.items.map((i) => i.id).toSet();
    if (currentStackIds.length != _selectedIds.length ||
        !currentStackIds.containsAll(_selectedIds)) {
      return true;
    }

    return false;
  }

  String _getButtonText(bool stackAlreadyExists) {
    if (stackAlreadyExists) {
      return "STACK CONFIGURATION EXISTS";
    }
    if (!_hasValidItemCount) {
      return "SELECT 2+ SUPPLEMENTS";
    }
    if (!_hasValidName) {
      return "ENTER STACK NAME";
    }
    if (widget.existingStack != null) {
      return _hasUnsavedModifications()
          ? "MODIFY STACK"
          : "DISMISS / NO CHANGES";
    }
    return "INITIALIZE STACK";
  }

  void _handleSave(List<Supplement> combinedPool) {
    // Validation check
    if (widget.existingStack != null && !_hasUnsavedModifications()) {
      Navigator.pop(context);
      return;
    }

    final provider = context.read<SupplementProvider>();

    // Dynamic configuration safety check to catch duplicate states on tap
    bool stackAlreadyExists = false;
    for (var stack in provider.supplementStacks) {
      if (widget.existingStack != null &&
          stack.id == widget.existingStack!.id) {
        continue;
      }
      final stackItemIds = stack.items.map((i) => i.id).toSet();
      if (stackItemIds.length == _selectedIds.length &&
          stackItemIds.containsAll(_selectedIds)) {
        stackAlreadyExists = true;
        break;
      }
    }

    if (!_hasValidName || !_hasValidItemCount || stackAlreadyExists) return;

    // Extract selected items
    final selectedSupplements = combinedPool
        .where((item) => _selectedIds.contains(item.id))
        .toList();

    // Sanitize values to ensure no 0 amounts are saved
    final Map<String, double> sanitizedAmounts = {};
    for (var id in _selectedIds) {
      double val = _recordValues[id] ?? 1.0;
      sanitizedAmounts[id] = val <= 0 ? 1.0 : val;
    }

    // Create the stack with the settings captured in your local state maps
    final stack = SupplementStack(
      id: widget.existingStack?.id ?? const Uuid().v4(),
      name: _stackNameController.text.trim(),
      items: selectedSupplements,
      isPinned: widget.existingStack?.isPinned ?? false,
      isPinnedToHome: widget.existingStack?.isPinnedToHome ?? false,
      notificationsEnabled: widget.existingStack?.notificationsEnabled ?? false,
      pinnedRecordModes: _recordActive,
      pinnedUseServings: _recordUseServings,
      pinnedAmounts: sanitizedAmounts,
    );

    // Send to Provider (calls Repository -> SQLite/Cloud via addOrUpdateStack)
    provider.addOrUpdateStack(stack);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplementProvider>();

    // Create a tracking set of item IDs that are confirmed active in the library
    final Set<String> activeLibraryIds = provider.activeSupplements
        .map((e) => e.id)
        .toSet();

    // Map to pool the final combined elements uniquely
    final Map<String, Supplement> poolMap = {};

    // 1. Layer active items from provider reference list
    for (var item in provider.activeSupplements) {
      poolMap[item.id] = item;
    }

    // 2. Layer stack items: safely preserve items that exist inside the stack
    if (widget.existingStack != null) {
      for (var item in widget.existingStack!.items) {
        poolMap.putIfAbsent(item.id, () => item);
      }
    }

    final unifiedPool = poolMap.values.toList();

    // Verification check tracking if a duplicate layout array composition already exists
    bool stackAlreadyExists = false;
    for (var stack in provider.supplementStacks) {
      if (widget.existingStack != null &&
          stack.id == widget.existingStack!.id) {
        continue;
      }
      final stackItemIds = stack.items.map((i) => i.id).toSet();
      if (stackItemIds.length == _selectedIds.length &&
          stackItemIds.containsAll(_selectedIds)) {
        stackAlreadyExists = true;
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600 && !widget.isSideSheet;
        final double sheetWidth = widget.isSideSheet ? constraints.maxWidth : (isCompact ? constraints.maxWidth : 600.0);

        return Align(
          alignment: widget.isSideSheet ? Alignment.center : Alignment.bottomCenter,
          child: SizedBox(
            width: sheetWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                height: widget.isSideSheet ? double.infinity : null,
                constraints: widget.isSideSheet ? null : BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: widget.isSideSheet 
                    ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                    : BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
                  border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  mainAxisSize: widget.isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    if (widget.isSideSheet) SizedBox(height: 24.0),
                    if (!widget.isSideSheet) _buildHandle(isCompact),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 24.w : 24.0, 
                        0, 
                        isCompact ? 24.w : 24.0, 
                        isCompact ? 8.h : 8.0
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isCompact ? 10.r : 10.0),
                                    decoration: BoxDecoration(
                                      color: AppColors.crimson.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.layers_rounded,
                                      color: AppColors.crimson,
                                      size: isCompact ? 24.r : 24.0,
                                    ),
                                  ),
                                  SizedBox(width: isCompact ? 12.w : 12.0),
                                  Text(
                                    widget.existingStack == null
                                        ? "NEW STACK"
                                        : "EDIT STACK",
                                    style: AppTextStyles.h3.copyWith(
                                      fontSize: isCompact ? null : 18.0,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.isSideSheet)
                                IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                  onPressed: () => Navigator.pop(context),
                                ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildTextField("STACK NAME", _stackNameController, isCompact),
                          SizedBox(height: isCompact ? 20.h : 16.0),
                          Text(
                            "SELECT SUPPLEMENTS",
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: isCompact ? 10.sp : 10.0,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: isCompact ? 12.h : 10.0),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 24.0),
                        itemCount: unifiedPool.length,
                        itemBuilder: (context, index) {
                          final item = unifiedPool[index];
                          final isSelected = _selectedIds.contains(item.id);

                          final bool isDeactivated =
                              !item.isActive || !activeLibraryIds.contains(item.id);

                          return _buildSelectionTile(item, isSelected, isDeactivated, isCompact);
                        },
                      ),
                    ),
                    _buildSaveButton(unifiedPool, stackAlreadyExists, isCompact),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionTile(
    Supplement item,
    bool isSelected,
    bool isDeactivated,
    bool isCompact,
  ) {
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedIds.remove(item.id);
        } else {
          _selectedIds.add(item.id);
          _recordActive[item.id] = true;
          _recordUseServings[item.id] = true;
          _restockUseServings[item.id] = true;
          _recordValues[item.id] = 1.0;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
        padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
        decoration: BoxDecoration(
          color: isDeactivated
              ? AppColors.crimson.withValues(alpha: 0.04)
              : AppColors.background.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
          border: Border.all(
            color: isSelected
                ? AppColors.crimson.withValues(alpha: 0.5)
                : (isDeactivated
                      ? AppColors.crimson.withValues(alpha: 0.2)
                      : AppColors.white.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? AppColors.crimson
                  : (isDeactivated
                        ? AppColors.crimson.withValues(alpha: 0.4)
                        : AppColors.textSecondary),
              size: isCompact ? 24.r : 24.0,
            ),
            SizedBox(width: isCompact ? 12.w : 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDeactivated
                        ? "[DEACTIVATED] ${item.name.toUpperCase()}"
                        : item.name.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: isCompact ? 13.sp : 12.0,
                      decoration: isDeactivated && !isSelected
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: isSelected
                          ? Colors.white
                          : (isDeactivated
                                ? AppColors.crimson.withValues(alpha: 0.7)
                                : AppColors.textSecondary),
                    ),
                  ),
                  if (isDeactivated) ...[
                    SizedBox(height: isCompact ? 4.h : 4.0),
                    Text(
                      "CURRENTLY DEACTIVATED IN LIBRARY",
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: isCompact ? 9.sp : 9.0,
                        color: AppColors.crimson,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(
    List<Supplement> combinedPool,
    bool stackAlreadyExists,
    bool isCompact,
  ) {
    final bool staticEdit =
        widget.existingStack != null && !_hasUnsavedModifications();
    final bool validAction =
        (_hasValidName && _hasValidItemCount && !stackAlreadyExists) ||
        staticEdit;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompact ? 24.w : 24.0, 
        isCompact ? 12.h : 12.0, 
        isCompact ? 24.w : 24.0, 
        isCompact ? 32.h : 24.0
      ),
      child: GestureDetector(
        onTap: validAction ? () => _handleSave(combinedPool) : null,
        child: Container(
          height: isCompact ? 60.h : 52.0,
          width: double.infinity,
          decoration: BoxDecoration(
            color: validAction
                ? AppColors.crimson
                : AppColors.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
            boxShadow: validAction
                ? [
                    BoxShadow(
                      color: AppColors.crimson.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            _getButtonText(stackAlreadyExists),
            style: AppTextStyles.buttonPrimary.copyWith(
              color: validAction ? Colors.white : Colors.white24,
              fontSize: isCompact ? 16.sp : 14.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool isCompact) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16.w : 16.0, 
        vertical: isCompact ? 4.h : 4.0
      ),
      child: TextField(
        controller: controller,
        cursorColor: AppColors.crimson,
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.none,
        style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 15.sp : 14.0),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: isCompact ? 12.sp : 12.0,
          ),
          floatingLabelStyle: AppTextStyles.labelSmall.copyWith(
            color: AppColors.crimson,
            fontSize: isCompact ? 12.sp : 12.0,
          ),
          border: InputBorder.none,
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
}
