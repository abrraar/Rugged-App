// lib/features/tracker/supplement/widgets/supplement_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import '../../model/supplement.dart';

class SupplementFormSheet extends StatefulWidget {
  final Supplement? existingItem;
  final int? index;
  final Function(Supplement item, int? index) onSave;
  final bool isSideSheet;

  const SupplementFormSheet({
    super.key,
    this.existingItem,
    this.index,
    required this.onSave,
    this.isSideSheet = false,
  });

  @override
  State<SupplementFormSheet> createState() => _SupplementFormSheetState();
}

class _SupplementFormSheetState extends State<SupplementFormSheet> {
  late TextEditingController nameController;
  late TextEditingController sUnitController;
  late TextEditingController wSizeController;
  late TextEditingController wUnitController;
  late TextEditingController descController;
  late TextEditingController stockController;

  // New Controllers
  late TextEditingController expiryController;
  late TextEditingController caloriesController;
  late TextEditingController proteinController;
  late TextEditingController carbsController;
  late TextEditingController fatsController;

  bool useServingsForStock = true;
  DateTime? selectedExpiryDate;

  // Dynamic rows tracking state for broken-down sub-ingredients
  List<SupplementIngredientRow> ingredientRows = [];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.existingItem?.name ?? "",
    );
    sUnitController = TextEditingController(
      text: widget.existingItem?.servingUnit ?? "Scoop",
    );
    wSizeController = TextEditingController(
      text: widget.existingItem?.weightPerServing.toString() ?? "",
    );
    wUnitController = TextEditingController(
      text: widget.existingItem?.weightUnit ?? "g",
    );
    descController = TextEditingController(
      text: widget.existingItem?.description ?? "",
    );
    stockController = TextEditingController(
      text: widget.existingItem?.totalStock?.toString() ?? "",
    );

    // Initialize New Fields
    selectedExpiryDate = widget.existingItem?.expiryDate;
    expiryController = TextEditingController(
      text: selectedExpiryDate != null
          ? "${selectedExpiryDate!.day}/${selectedExpiryDate!.month}/${selectedExpiryDate!.year}"
          : "",
    );
    caloriesController = TextEditingController(
      text: widget.existingItem?.caloriesPerUnit?.toString() ?? "",
    );
    proteinController = TextEditingController(
      text: widget.existingItem?.proteinPerUnit?.toString() ?? "",
    );
    carbsController = TextEditingController(
      text: widget.existingItem?.carbsPerUnit?.toString() ?? "",
    );
    fatsController = TextEditingController(
      text: widget.existingItem?.fatsPerUnit?.toString() ?? "",
    );

    // Load any existing ingredients if editing an item
    if (widget.existingItem != null &&
        widget.existingItem!.ingredients.isNotEmpty) {
      for (var ing in widget.existingItem!.ingredients) {
        ingredientRows.add(
          SupplementIngredientRow(
            nameCtrl: TextEditingController(text: ing.name),
            amountCtrl: TextEditingController(text: ing.amount.toString()),
            unitCtrl: TextEditingController(text: ing.unit),
          ),
        );
      }
    } else {
      // Always start with one empty ingredient entry by default
      ingredientRows.add(
        SupplementIngredientRow(
          nameCtrl: TextEditingController(),
          amountCtrl: TextEditingController(),
          unitCtrl: TextEditingController(),
        ),
      );
    }

    nameController.addListener(_onFieldChanged);
    sUnitController.addListener(_onFieldChanged);
    wSizeController.addListener(_onFieldChanged);
    wUnitController.addListener(_onFieldChanged);

    // Add listeners to existing tracking controllers to dynamically validate changes
    for (var row in ingredientRows) {
      row.nameCtrl.addListener(_onFieldChanged);
      row.amountCtrl.addListener(_onFieldChanged);
      row.unitCtrl.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  bool _isFormValid() {
    final bool basicValid =
        nameController.text.trim().isNotEmpty &&
        sUnitController.text.trim().isNotEmpty &&
        wUnitController.text.trim().isNotEmpty &&
        wSizeController.text.trim().isNotEmpty &&
        (double.tryParse(wSizeController.text) ?? 0) > 0;

    if (!basicValid) return false;

    bool hasAtLeastOneValidIngredient = false;
    for (var row in ingredientRows) {
      final name = row.nameCtrl.text.trim();
      final amountStr = row.amountCtrl.text.trim();
      final unit = row.unitCtrl.text.trim();
      final amount = double.tryParse(amountStr) ?? 0.0;

      if (name.isNotEmpty && unit.isNotEmpty && amount > 0) {
        hasAtLeastOneValidIngredient = true;
        break;
      }
    }

    return hasAtLeastOneValidIngredient;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedExpiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.crimson,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedExpiryDate) {
      setState(() {
        selectedExpiryDate = picked;
        expiryController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    sUnitController.dispose();
    wSizeController.dispose();
    wUnitController.dispose();
    descController.dispose();
    stockController.dispose();
    expiryController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatsController.dispose();
    for (var row in ingredientRows) {
      row.nameCtrl.dispose();
      row.amountCtrl.dispose();
      row.unitCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    if (!widget.isSideSheet)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.only(
                          top: isCompact ? 16.h : 16.0, 
                          bottom: isCompact ? 16.h : 16.0
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: isCompact ? 40.w : 40.0,
                          height: isCompact ? 4.h : 4.0,
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(3.r),
                          ),
                        ),
                      ),
                    if (widget.isSideSheet) SizedBox(height: 24.0),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 24.w : 24.0, 
                          0, 
                          isCompact ? 24.w : 24.0, 
                          isCompact ? 40.h : 32.0
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(isCompact ? 10.r : 10.0),
                                          decoration: BoxDecoration(
                                            color: AppColors.crimson.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            widget.existingItem == null
                                                ? Icons.add_rounded
                                                : Icons.edit_rounded,
                                            color: AppColors.crimson,
                                            size: isCompact ? 24.r : 20.0,
                                          ),
                                        ),
                                        SizedBox(width: isCompact ? 12.w : 12.0),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.existingItem == null
                                                    ? "ADD SUPPLEMENT"
                                                    : "EDIT SUPPLEMENT",
                                                style: AppTextStyles.h3.copyWith(
                                                  fontSize: isCompact ? null : 18.0,
                                                ),
                                              ),
                                              Text(
                                                "LIBRARY CONFIGURATION",
                                                style: AppTextStyles.labelSmall.copyWith(
                                                  color: AppColors.textSecondary,
                                                  letterSpacing: 1.2,
                                                  fontSize: isCompact ? null : 10.0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 24.h : 20.0),

                              _buildFieldGroup(
                                "SUPPLEMENT NAME *",
                                nameController,
                                "e.g. Whey Protein",
                                isCompact: isCompact,
                              ),
                              SizedBox(height: isCompact ? 16.h : 12.0),

                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFieldGroup(
                                      "SERVING UNIT *",
                                      sUnitController,
                                      "Scoop",
                                      isCompact: isCompact,
                                    ),
                                  ),
                                  SizedBox(width: isCompact ? 12.w : 12.0),
                                  Expanded(
                                    child: _buildFieldGroup(
                                      "WEIGHT UNIT *",
                                      wUnitController,
                                      "g",
                                      isCompact: isCompact,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 16.h : 12.0),

                              _buildFieldGroup(
                                "WEIGHT PER SERVING *",
                                wSizeController,
                                "0.0",
                                isNumeric: true,
                                isCompact: isCompact,
                              ),
                              SizedBox(height: isCompact ? 28.h : 20.0),

                              // ─── VERTICAL INGREDIENTS BREAKDOWN COLUMN LAYOUT ───
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "INGREDIENTS BREAKDOWN * (MINIMUM 1)",
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                      fontSize: isCompact ? null : 11.0,
                                    ),
                                  ),
                                  SizedBox(height: isCompact ? 16.h : 12.0),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: ingredientRows.length,
                                    itemBuilder: (context, index) {
                                      final row = ingredientRows[index];
                                      return Padding(
                                        padding: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            vertical: isCompact ? 18.h : 16.0, 
                                            horizontal: isCompact ? 18.w : 16.0
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.background.withValues(alpha: 0.35),
                                            borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
                                            border: Border.all(
                                              color: AppColors.white.withValues(alpha: 0.06),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    "ENTRY #${index + 1}",
                                                    style: AppTextStyles.labelSmall
                                                        .copyWith(
                                                          color: AppColors.textSecondary
                                                              .withValues(alpha: 0.6),
                                                          fontWeight: FontWeight.w500,
                                                          fontSize: isCompact ? 11.sp : 10.0,
                                                          letterSpacing: 0.8,
                                                        ),
                                                  ),
                                                  if (ingredientRows.length > 1)
                                                    GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          row.nameCtrl.dispose();
                                                          row.amountCtrl.dispose();
                                                          row.unitCtrl.dispose();
                                                          ingredientRows.removeAt(
                                                            index,
                                                          );
                                                        });
                                                      },
                                                      child: Container(
                                                        padding: EdgeInsets.symmetric(
                                                          vertical: isCompact ? 6.h : 4.0, 
                                                          horizontal: isCompact ? 10.w : 8.0
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: AppColors.crimson
                                                              .withValues(alpha: 0.08),
                                                          borderRadius:
                                                              BorderRadius.circular(8.r),
                                                          border: Border.all(
                                                            color: AppColors.crimson
                                                                .withValues(alpha: 0.15),
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .delete_outline_rounded,
                                                              color: AppColors.crimson,
                                                              size: isCompact ? 14.r : 14.0,
                                                            ),
                                                            SizedBox(width: isCompact ? 4.w : 4.0),
                                                            Text(
                                                              "REMOVE",
                                                              style: AppTextStyles
                                                                  .labelSmall
                                                                  .copyWith(
                                                                    color: AppColors
                                                                        .crimson,
                                                                    fontSize: isCompact ? 10.sp : 9.0,
                                                                    fontWeight:
                                                                        FontWeight.w500,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              Padding(
                                                padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 8.0),
                                                child: Divider(
                                                  color: AppColors.white.withValues(alpha: 0.04),
                                                  thickness: 1,
                                                ),
                                              ),

                                              // Field 1: Ingredient Name
                                              Row(
                                                children: [
                                                  Expanded(
                                                    flex: 35,
                                                    child: Text(
                                                      "Ingredient Name",
                                                      style: AppTextStyles.labelSmall
                                                          .copyWith(
                                                            color: AppColors.white
                                                                .withValues(alpha: 0.7),
                                                            fontWeight: FontWeight.w500,
                                                            fontSize: isCompact ? null : 11.0,
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(width: isCompact ? 12.w : 12.0),
                                                  Expanded(
                                                    flex: 65,
                                                    child: _buildModernInput(
                                                      row.nameCtrl,
                                                      "e.g. Creatine Monohydrate",
                                                      isCompact: isCompact,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: isCompact ? 14.h : 10.0),

                                              // Field 2: Amount
                                              Row(
                                                children: [
                                                  Expanded(
                                                    flex: 35,
                                                    child: Text(
                                                      "Amount",
                                                      style: AppTextStyles.labelSmall
                                                          .copyWith(
                                                            color: AppColors.white
                                                                .withValues(alpha: 0.7),
                                                            fontWeight: FontWeight.w500,
                                                            fontSize: isCompact ? null : 11.0,
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(width: isCompact ? 12.w : 12.0),
                                                  Expanded(
                                                    flex: 65,
                                                    child: _buildModernInput(
                                                      row.amountCtrl,
                                                      "e.g. 5000",
                                                      isNumeric: true,
                                                      isCompact: isCompact,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: isCompact ? 14.h : 10.0),

                                              // Field 3: Unit
                                              Row(
                                                children: [
                                                  Expanded(
                                                    flex: 35,
                                                    child: Text(
                                                      "Unit (e.g. mg)",
                                                      style: AppTextStyles.labelSmall
                                                          .copyWith(
                                                            color: AppColors.white
                                                                .withValues(alpha: 0.7),
                                                            fontWeight: FontWeight.w500,
                                                            fontSize: isCompact ? null : 11.0,
                                                          ),
                                                    ),
                                                  ),
                                                  SizedBox(width: isCompact ? 12.w : 12.0),
                                                  Expanded(
                                                    flex: 65,
                                                    child: _buildModernInput(
                                                      row.unitCtrl,
                                                      "e.g. mg or g",
                                                      isCompact: isCompact,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        final newRow = SupplementIngredientRow(
                                          nameCtrl: TextEditingController(),
                                          amountCtrl: TextEditingController(),
                                          unitCtrl: TextEditingController(),
                                        );
                                        newRow.nameCtrl.addListener(_onFieldChanged);
                                        newRow.amountCtrl.addListener(_onFieldChanged);
                                        newRow.unitCtrl.addListener(_onFieldChanged);
                                        ingredientRows.add(newRow);
                                      });
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      height: isCompact ? 54.h : 48.0,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.crimson.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
                                        border: Border.all(
                                          color: AppColors.crimson.withValues(alpha: 0.3),
                                          width: 1.5,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline_rounded,
                                            color: AppColors.crimson,
                                            size: isCompact ? 18.r : 18.0,
                                          ),
                                          SizedBox(width: isCompact ? 8.w : 8.0),
                                          Text(
                                            "ADD NEXT INGREDIENT",
                                            style: AppTextStyles.labelSmall.copyWith(
                                              color: AppColors.crimson,
                                              fontSize: isCompact ? 13.sp : 12.0,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 24.h : 20.0),

                              // EXPIRY & CALORIES
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "EXPIRY DATE",
                                          style: AppTextStyles.labelSmall.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: isCompact ? null : 11.0,
                                          ),
                                        ),
                                        SizedBox(height: isCompact ? 8.h : 8.0),
                                        GestureDetector(
                                          onTap: () => _selectDate(context),
                                          child: AbsorbPointer(
                                            child: _buildModernInput(
                                              expiryController,
                                              "DD/MM/YYYY",
                                              isCompact: isCompact,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: isCompact ? 12.w : 12.0),
                                  Expanded(
                                    child: _buildFieldGroup(
                                      "CALORIES PER ${wUnitController.text.isEmpty ? 'UNIT' : wUnitController.text.toUpperCase()}",
                                      caloriesController,
                                      "0.0",
                                      isNumeric: true,
                                      isCompact: isCompact,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 16.h : 12.0),

                              // MACROS PER UNIT
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFieldGroup(
                                      "PRO (g)",
                                      proteinController,
                                      "0.0",
                                      isNumeric: true,
                                      isCompact: isCompact,
                                    ),
                                  ),
                                  SizedBox(width: isCompact ? 8.w : 8.0),
                                  Expanded(
                                    child: _buildFieldGroup(
                                      "CHO (g)",
                                      carbsController,
                                      "0.0",
                                      isNumeric: true,
                                      isCompact: isCompact,
                                    ),
                                  ),
                                  SizedBox(width: isCompact ? 8.w : 8.0),
                                  Expanded(
                                    child: _buildFieldGroup(
                                      "FAT (g)",
                                      fatsController,
                                      "0.0",
                                      isNumeric: true,
                                      isCompact: isCompact,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isCompact ? 24.h : 20.0),

                              if (widget.existingItem == null) ...[
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: isCompact ? 24.h : 20.0),
                                  child: Divider(
                                    color: AppColors.white.withValues(alpha: 0.08),
                                    thickness: 1,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "TOTAL STOCK (OPTIONAL)",
                                          style: AppTextStyles.labelSmall.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: isCompact ? null : 11.0,
                                          ),
                                        ),
                                        _buildSegmentedSelector(
                                          [
                                            sUnitController.text.isEmpty
                                                ? "Serv"
                                                : sUnitController.text,
                                            wUnitController.text.isEmpty
                                                ? "Unit"
                                                : wUnitController.text,
                                          ],
                                          useServingsForStock ? 0 : 1,
                                          (i) => setState(
                                            () => useServingsForStock = i == 0,
                                          ),
                                          isCompact: isCompact,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isCompact ? 12.h : 8.0),
                                    _buildModernInput(
                                      stockController,
                                      "Enter total amount",
                                      isNumeric: true,
                                      isCompact: isCompact,
                                    ),
                                  ],
                                ),
                              ],

                              SizedBox(height: isCompact ? 16.h : 12.0),

                              _buildFieldGroup(
                                "DESCRIPTION (OPTIONAL)",
                                descController,
                                "Notes about this supplement",
                                maxLines: 4,
                                isCompact: isCompact,
                              ),

                              SizedBox(height: isCompact ? 32.h : 24.0),

                              _buildActionButton(
                                widget.existingItem == null
                                    ? "ADD TO LIBRARY"
                                    : "SAVE CHANGES",
                                _isFormValid()
                                    ? AppColors.crimson
                                    : AppColors.surfaceLight,
                                _isFormValid()
                                    ? () {
                                        double weight =
                                            double.tryParse(wSizeController.text) ??
                                            1.0;

                                        double? finalStock;
                                        double? finalRemaining;

                                        if (widget.existingItem == null) {
                                          double? stockRaw = double.tryParse(
                                            stockController.text,
                                          );
                                          finalStock = stockRaw != null
                                              ? (useServingsForStock
                                                    ? stockRaw * weight
                                                    : stockRaw)
                                              : null;
                                          finalRemaining = finalStock;
                                        } else {
                                          finalStock = widget.existingItem!.totalStock;
                                          finalRemaining =
                                              widget.existingItem!.remainingStock;
                                        }

                                        List<SupplementIngredient> compiledIngredients =
                                            [];
                                        for (var row in ingredientRows) {
                                          final name = row.nameCtrl.text.trim();
                                          final amountStr = row.amountCtrl.text.trim();
                                          final unit = row.unitCtrl.text.trim();
                                          final amount =
                                              double.tryParse(amountStr) ?? 0.0;

                                          if (name.isNotEmpty &&
                                              unit.isNotEmpty &&
                                              amount > 0) {
                                            compiledIngredients.add(
                                              SupplementIngredient(
                                                name: name,
                                                amount: amount,
                                                unit: unit,
                                              ),
                                            );
                                          }
                                        }

                                        final newItem = Supplement(
                                          id:
                                              widget.existingItem?.id ??
                                              DateTime.now().toString(),
                                          name: nameController.text.trim(),
                                          servingUnit: sUnitController.text.trim(),
                                          weightPerServing: weight,
                                          weightUnit: wUnitController.text.trim(),
                                          description: descController.text.trim(),
                                          totalStock: finalStock,
                                          remainingStock: finalRemaining,
                                          expiryDate: selectedExpiryDate,
                                          caloriesPerUnit: double.tryParse(
                                            caloriesController.text,
                                          ),
                                          proteinPerUnit: double.tryParse(
                                            proteinController.text,
                                          ),
                                          carbsPerUnit: double.tryParse(
                                            carbsController.text,
                                          ),
                                          fatsPerUnit: double.tryParse(
                                            fatsController.text,
                                          ),
                                          isActive:
                                              widget.existingItem?.isActive ?? true,
                                          isPinnedToHome:
                                              widget.existingItem?.isPinnedToHome ??
                                              false,
                                          pinnedIntakeAmount:
                                              widget.existingItem?.pinnedIntakeAmount ??
                                              0,
                                          pinnedRestockAmount:
                                              widget
                                                  .existingItem
                                                  ?.pinnedRestockAmount ??
                                              0,
                                          pinnedUseServingsIntake:
                                              widget
                                                  .existingItem
                                                  ?.pinnedUseServingsIntake ??
                                              true,
                                          pinnedUseServingsRestock:
                                              widget
                                                  .existingItem
                                                  ?.pinnedUseServingsRestock ??
                                              true,
                                          notificationsEnabled:
                                              widget
                                                  .existingItem
                                                  ?.notificationsEnabled ??
                                              false,
                                          reminders:
                                              widget.existingItem?.reminders ?? [],
                                          ingredients: compiledIngredients,
                                        );

                                        widget.onSave(newItem, widget.index);
                                        Navigator.pop(context);
                                      }
                                    : null,
                                isCompact: isCompact,
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildFieldGroup(
    String label,
    TextEditingController controller,
    String hint, {
    bool isNumeric = false,
    int maxLines = 1,
    required bool isCompact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: isCompact ? null : 11.0,
          ),
        ),
        SizedBox(height: isCompact ? 8.h : 6.0),
        _buildModernInput(
          controller,
          hint,
          isNumeric: isNumeric,
          maxLines: maxLines,
          isCompact: isCompact,
        ),
      ],
    );
  }

  Widget _buildModernInput(
    TextEditingController controller,
    String hint, {
    bool isNumeric = false,
    int maxLines = 1,
    required bool isCompact,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: maxLines > 1 ? (isCompact ? 120.h : 100.0) : (isCompact ? 54.h : 44.0)),
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0),
      alignment: maxLines > 1 ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: isNumeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))]
            : [],
        style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 15.sp : 14.0),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withValues(alpha: 0.25),
            fontSize: isCompact ? 15.sp : 14.0,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 12.0),
        ),
      ),
    );
  }

  Widget _buildSegmentedSelector(
    List<String> labels,
    int activeIndex,
    Function(int) onTap,
    {required bool isCompact}
  ) {
    return Container(
      height: isCompact ? 38.h : 34.0,
      padding: EdgeInsets.all(isCompact ? 4.r : 3.0),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (index) {
          final bool isActive = activeIndex == index;
          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 12.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? AppColors.crimson : Colors.transparent,
                borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
              ),
              child: Text(
                labels[index].toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: isCompact ? 10.sp : 9.0,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    VoidCallback? onPressed,
    {required bool isCompact}
  ) {
    bool isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isCompact ? 60.h : 52.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.buttonPrimary.copyWith(
            color: isEnabled
                ? Colors.white
                : AppColors.textSecondary.withValues(alpha: 0.4),
            fontSize: isCompact ? 16.sp : 14.0,
          ),
        ),
      ),
    );
  }
}

// ─── LOCAL STATE ROW MODEL OBJECT ───
class SupplementIngredientRow {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController unitCtrl;

  SupplementIngredientRow({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.unitCtrl,
  });
}
