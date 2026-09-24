import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/core/theme/app_text_styles.dart';
import 'package:rugged/features/tracker/calorie/model/saved_meal.dart';
import 'package:rugged/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../model/calorie_log.dart';
import 'package:rugged/features/tracker/supplement/model/supplement.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_stack.dart';

class AddMealSheet extends StatefulWidget {
  final SavedMeal? existingMeal;
  final List<SavedMeal> savedMeals;
  final Function(CalorieLog, bool, double servings, bool multiplySupps) onSave;
  final bool isLibraryOnly;
  final bool isSideSheet;

  const AddMealSheet({
    super.key,
    this.existingMeal,
    required this.onSave,
    required this.savedMeals,
    this.isLibraryOnly = false,
    this.isSideSheet = false,
  });

  @override
  State<AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends State<AddMealSheet> {
  final _mealNameController = TextEditingController();
  final _foodItemsController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatsController = TextEditingController();
  final _multiplierController = TextEditingController();

  double _multiplier = 1.0;
  bool _multiplySupps = true;

  final Map<String, double> _supplementAmounts = {};
  final Map<String, Map<String, double>> _stackItemAmounts = {};
  final Map<String, bool> _useServingsForSupps = {};

  @override
  void initState() {
    super.initState();
    if (widget.existingMeal != null) {
      final meal = widget.existingMeal!;
      final supplementProvider = context.read<SupplementProvider>();

      _mealNameController.text = meal.name;
      _multiplier = meal.servings;
      _multiplySupps = meal.multiplySupps;
      
      _multiplierController.text = (_multiplier % 1 == 0 ? _multiplier.toInt() : _multiplier.toStringAsFixed(2)).toString();
      
      if (meal.addedSupplementsJson != null) {
        try {
          final decoded = jsonDecode(meal.addedSupplementsJson!);
          if (decoded is List) {
            for (var item in decoded) {
              if (item is Map) {
                final String? id = item['id']?.toString();
                if (id == null) continue;
                final double totalAmount = (item['amount'] as num?)?.toDouble() ?? 0.0;
                _supplementAmounts[id] = _multiplySupps 
                    ? totalAmount / (meal.servings > 0 ? meal.servings : 1.0)
                    : totalAmount;
                _useServingsForSupps[id] = true;
              }
            }
          }
        } catch (e) {
          debugPrint("AddMealSheet Init Supp Error: $e");
        }
      }

      if (meal.addedStacksJson != null) {
        try {
          final decoded = jsonDecode(meal.addedStacksJson!);
          if (decoded is List) {
            for (var item in decoded) {
              if (item is Map) {
                final String? stackId = item['id']?.toString();
                if (stackId == null) continue;
                final rawAmounts = item['itemAmounts'];
                if (rawAmounts is Map) {
                  _stackItemAmounts[stackId] = rawAmounts.map((k, v) {
                    final double totalVal = (v as num?)?.toDouble() ?? 0.0;
                    final String suppId = k.toString();
                    _useServingsForSupps[suppId] = true;
                    return MapEntry(suppId, _multiplySupps 
                        ? totalVal / (meal.servings > 0 ? meal.servings : 1.0)
                        : totalVal);
                  });
                }
              }
            }
          }
        } catch (e) {
          debugPrint("AddMealSheet Init Stack Error: $e");
        }
      }

      double suppCals = 0;
      double suppPro = 0, suppCarbs = 0, suppFats = 0;
      List<String> suppNames = [];

      _supplementAmounts.forEach((id, amount) {
        try {
          final s = supplementProvider.library.firstWhere((s) => s.id == id);
          suppCals += (s.caloriesPerUnit ?? 0) * amount;
          suppPro += (s.proteinPerUnit ?? 0) * amount;
          suppCarbs += (s.carbsPerUnit ?? 0) * amount;
          suppFats += (s.fatsPerUnit ?? 0) * amount;
          suppNames.add(s.name.toUpperCase());
        } catch (_) {}
      });

      _stackItemAmounts.forEach((stackId, itemValues) {
        try {
          final stack = supplementProvider.supplementStacks.firstWhere((s) => s.id == stackId);
          itemValues.forEach((suppId, amount) {
            final s = stack.items.firstWhere((item) => item.id == suppId);
            suppCals += (s.caloriesPerUnit ?? 0) * amount;
            suppPro += (s.proteinPerUnit ?? 0) * amount;
            suppCarbs += (s.carbsPerUnit ?? 0) * amount;
            suppFats += (s.fatsPerUnit ?? 0) * amount;
          });
          suppNames.add(stack.name.toUpperCase());
        } catch (_) {}
      });

      double baseTotalCals = meal.calories / (meal.servings > 0 ? meal.servings : 1.0);
      double? baseTotalPro = meal.protein != null ? meal.protein! / (meal.servings > 0 ? meal.servings : 1.0) : null;
      double? baseTotalCarbs = meal.carbs != null ? meal.carbs! / (meal.servings > 0 ? meal.servings : 1.0) : null;
      double? baseTotalFats = meal.fats != null ? meal.fats! / (meal.servings > 0 ? meal.servings : 1.0) : null;

      final double baseCals = (baseTotalCals - suppCals).clamp(0.0, 9999.999);
      _caloriesController.text = baseCals % 1 == 0 ? baseCals.toInt().toString() : baseCals.toStringAsFixed(3);
      
      final pVal = baseTotalPro != null ? (baseTotalPro - suppPro).clamp(0.0, 1000.0) : null;
      final cVal = baseTotalCarbs != null ? (baseTotalCarbs - suppCarbs).clamp(0.0, 1000.0) : null;
      final fVal = baseTotalFats != null ? (baseTotalFats - suppFats).clamp(0.0, 1000.0) : null;

      _proteinController.text = pVal != null ? (pVal % 1 == 0 ? pVal.toInt().toString() : pVal.toStringAsFixed(1)) : "";
      _carbsController.text = cVal != null ? (cVal % 1 == 0 ? cVal.toInt().toString() : cVal.toStringAsFixed(1)) : "";
      _fatsController.text = fVal != null ? (fVal % 1 == 0 ? fVal.toInt().toString() : fVal.toStringAsFixed(1)) : "";

      String cleanedItems = meal.foodItems;
      for (var name in suppNames) {
        cleanedItems = cleanedItems.replaceAll(RegExp(',?\\s*$name', caseSensitive: false), '');
        cleanedItems = cleanedItems.replaceAll(RegExp('$name\\s*,?', caseSensitive: false), '');
      }
      _foodItemsController.text = cleanedItems.trim();
    } else {
      _multiplierController.text = "1.0";
    }

    _mealNameController.addListener(_updateState);
    _caloriesController.addListener(_updateState);
    _proteinController.addListener(_updateState);
    _carbsController.addListener(_updateState);
    _fatsController.addListener(_updateState);
  }

  void _updateState() => setState(() {});

  @override
  void dispose() {
    _mealNameController.dispose();
    _foodItemsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _multiplierController.dispose();
    super.dispose();
  }

  double get _calculatedCalories {
    final p = double.tryParse(_proteinController.text) ?? 0.0;
    final c = double.tryParse(_carbsController.text) ?? 0.0;
    final f = double.tryParse(_fatsController.text) ?? 0.0;
    return (p * 4) + (c * 4) + (f * 9);
  }

  bool get _isMacroValid {
    final totalText = _caloriesController.text.trim();
    if (totalText.isEmpty) return true;
    final total = double.tryParse(totalText) ?? 0.0;
    if (total == 0) return true;
    return _calculatedCalories <= total;
  }

  bool get _canSubmit {
    return _mealNameController.text.trim().isNotEmpty &&
           _caloriesController.text.trim().isNotEmpty &&
           double.tryParse(_caloriesController.text.trim()) != null &&
           _isMacroValid &&
           _multiplier > 0;
  }

  String _getButtonLabel(String baseLabel) {
    if (_mealNameController.text.trim().isEmpty) return "ENTER MEAL NAME";
    final calText = _caloriesController.text.trim();
    if (calText.isEmpty) return "ENTER CALORIES";
    if (double.tryParse(calText) == null) return "INVALID CALORIES";
    if (!_isMacroValid) return "MACROS EXCEED CALORIES";
    if (_multiplier <= 0) return "SERVING MUST BE > 0";
    return baseLabel;
  }

  void _toggleSupplement(Supplement supp) {
    setState(() {
      if (_supplementAmounts.containsKey(supp.id)) {
        _supplementAmounts.remove(supp.id);
        _useServingsForSupps.remove(supp.id);
      } else {
        _supplementAmounts[supp.id] = 1.0;
        _useServingsForSupps[supp.id] = true;
      }
    });
  }

  void _toggleStack(SupplementStack stack) {
    setState(() {
      if (_stackItemAmounts.containsKey(stack.id)) {
        _stackItemAmounts.remove(stack.id);
      } else {
        final Map<String, double> values = {};
        for (var item in stack.items) {
          values[item.id] = stack.pinnedAmounts[item.id] ?? 1.0;
          _useServingsForSupps[item.id] = true;
        }
        _stackItemAmounts[stack.id] = values;
      }
    });
  }

  Future<void> _handleSave(bool saveToLibrary) async {
    if (!_canSubmit) return;
    
    try {
      final supplementProvider = context.read<SupplementProvider>();
      
      double totalCals = (double.parse(_caloriesController.text.trim()) * _multiplier);
      
      final double? basePro = double.tryParse(_proteinController.text);
      final double? baseCarbs = double.tryParse(_carbsController.text);
      final double? baseFats = double.tryParse(_fatsController.text);

      double? totalPro = basePro != null ? basePro * _multiplier : null;
      double? totalCarbs = baseCarbs != null ? baseCarbs * _multiplier : null;
      double? totalFats = baseFats != null ? baseFats * _multiplier : null;
      
      String mealName = _mealNameController.text.trim();
      String finalFoodItems = _foodItemsController.text.trim();

      final List<Map<String, dynamic>> suppsPayload = [];
      final List<Map<String, dynamic>> stacksPayload = [];
      final mealId = widget.existingMeal?.id ?? const Uuid().v4();

      for (var entry in _supplementAmounts.entries) {
        final id = entry.key;
        final amount = _multiplySupps ? (entry.value * _multiplier) : entry.value; 
        try {
          final supp = supplementProvider.library.firstWhere((s) => s.id == id);
          totalCals += ((supp.caloriesPerUnit ?? 0.0) * amount);
          
          if (supp.proteinPerUnit != null) totalPro = (totalPro ?? 0.0) + (supp.proteinPerUnit! * amount);
          if (supp.carbsPerUnit != null) totalCarbs = (totalCarbs ?? 0.0) + (supp.carbsPerUnit! * amount);
          if (supp.fatsPerUnit != null) totalFats = (totalFats ?? 0.0) + (supp.fatsPerUnit! * amount);
          
          suppsPayload.add({'id': id, 'amount': amount});

          if (!widget.isLibraryOnly) {
            await supplementProvider.recordEntry(
              supplement: supp,
              isIntake: true,
              isRestock: false,
              weightAdjustment: -(amount * supp.weightPerServing),
              historyDetails: "MEAL LOG: ${mealName.toUpperCase()} | SUPPLEMENT | $amount ${supp.servingUnit.toUpperCase()}",
              timestamp: DateTime.now(),
              sourceId: mealId,
            );
          }
        } catch (_) {}
      }

      for (var entry in _stackItemAmounts.entries) {
        final stackId = entry.key;
        final itemValues = entry.value;
        try {
          final stack = supplementProvider.supplementStacks.firstWhere((s) => s.id == stackId);
          final Map<String, double> finalItemAmounts = itemValues.map((k, v) => MapEntry(k, _multiplySupps ? (v * _multiplier) : v));
          stacksPayload.add({'id': stackId, 'itemAmounts': finalItemAmounts});
          
          for (var itemEntry in itemValues.entries) {
            final suppId = itemEntry.key;
            final amount = _multiplySupps ? (itemEntry.value * _multiplier) : itemEntry.value;
            final item = supplementProvider.library.firstWhere((s) => s.id == suppId);
            
            totalCals += ((item.caloriesPerUnit ?? 0.0) * amount);
            
            if (item.proteinPerUnit != null) totalPro = (totalPro ?? 0.0) + (item.proteinPerUnit! * amount);
            if (item.carbsPerUnit != null) totalCarbs = (totalCarbs ?? 0.0) + (item.carbsPerUnit! * amount);
            if (item.fatsPerUnit != null) totalFats = (totalFats ?? 0.0) + (item.fatsPerUnit! * amount);

            if (!widget.isLibraryOnly) {
              await supplementProvider.recordEntry(
                supplement: item,
                isIntake: true,
                isRestock: false,
                weightAdjustment: -(amount * item.weightPerServing),
                historyDetails: "MEAL LOG: ${mealName.toUpperCase()} | STACK: ${stack.name.toUpperCase()} | $amount ${item.servingUnit.toUpperCase()}",
                timestamp: DateTime.now(),
                sourceId: mealId,
              );
            }
          }
        } catch (_) {}
      }
      
      final log = CalorieLog(
        id: mealId, 
        mealName: mealName,
        foodItems: finalFoodItems,
        calories: totalCals,
        protein: totalPro,
        carbs: totalCarbs,
        fats: totalFats,
        addedSupplementsJson: suppsPayload.isNotEmpty ? jsonEncode(suppsPayload) : null,
        addedStacksJson: stacksPayload.isNotEmpty ? jsonEncode(stacksPayload) : null,
        servings: _multiplier,
      );
      
      widget.onSave(log, saveToLibrary, _multiplier, _multiplySupps);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("AddMealSheet GLOBAL SAVE ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplementProvider = context.watch<SupplementProvider>();
    final allSupplements = supplementProvider.library;
    final supplementStacks = supplementProvider.supplementStacks;

    final List<Supplement> visibleSupps = allSupplements.where((s) {
      return s.isActive || _supplementAmounts.containsKey(s.id);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600 && !widget.isSideSheet;
        final double sheetWidth = widget.isSideSheet ? constraints.maxWidth : (isCompact ? constraints.maxWidth : 600.0);

        return Align(
          alignment: widget.isSideSheet ? Alignment.center : Alignment.bottomCenter,
          child: SizedBox(
            width: sheetWidth,
            child: Container(
              height: widget.isSideSheet ? double.infinity : null,
              padding: EdgeInsets.fromLTRB(
                isCompact ? 24.w : 24.0, 
                widget.isSideSheet ? 0 : (isCompact ? 20.h : 16.0), 
                isCompact ? 24.w : 24.0, 
                MediaQuery.of(context).viewInsets.bottom + (isCompact ? 40.h : 32.0)
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
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.existingMeal != null ? "EDIT MEAL ENTRY" : "ADD MEAL ENTRY", 
                                style: AppTextStyles.h3.copyWith(fontSize: isCompact ? null : 18.0)
                              ),
                              if (widget.isSideSheet)
                                IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                  onPressed: () => Navigator.pop(context),
                                ),
                            ],
                          ),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildSectionHeader("MEAL NAME", isCompact),
                          SizedBox(height: isCompact ? 8.h : 6.0),
                          _buildTextFieldWithoutLabel(_mealNameController, hint: "e.g. Breakfast", isCompact: isCompact),
                          SizedBox(height: isCompact ? 16.h : 12.0),
                          _buildMultiplierSection(isCompact),
                          SizedBox(height: isCompact ? 16.h : 12.0),
                          _buildSectionHeader("FOOD ITEMS", isCompact),
                          SizedBox(height: isCompact ? 8.h : 6.0),
                          _buildTextFieldWithoutLabel(_foodItemsController, hint: "e.g. Oats, Whey, Berries", isCompact: isCompact),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          
                          if (visibleSupps.isNotEmpty || supplementStacks.isNotEmpty) ...[
                            _buildSectionHeader("QUICK ADD SUPPLEMENTS", isCompact),
                            SizedBox(height: isCompact ? 12.h : 10.0),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: [
                                  ...supplementStacks.map((stack) => _buildQuickAddChip(
                                    label: stack.name,
                                    isSelected: _stackItemAmounts.containsKey(stack.id),
                                    onTap: () => _toggleStack(stack),
                                    isStack: true,
                                    isCompact: isCompact,
                                  )),
                                  ...visibleSupps.map((supp) => _buildQuickAddChip(
                                    label: supp.name,
                                    isSelected: _supplementAmounts.containsKey(supp.id),
                                    onTap: () => _toggleSupplement(supp),
                                    isCompact: isCompact,
                                  )),
                                ],
                              ),
                            ),
                            if (_supplementAmounts.isNotEmpty || _stackItemAmounts.isNotEmpty) ...[
                              SizedBox(height: isCompact ? 16.h : 12.0),
                              _buildIngredientConfigSection(allSupplements, supplementStacks, isCompact),
                            ],
                            SizedBox(height: isCompact ? 24.h : 20.0),
                          ] else ...[
                            _buildSectionHeader("QUICK ADD SUPPLEMENTS", isCompact),
                            SizedBox(height: isCompact ? 12.h : 10.0),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                                border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                              ),
                              child: Text(
                                "NO ACTIVE SUPPLEMENTS OR STACKS AVAILABLE.\nPLEASE CREATE OR ACTIVATE THEM IN THE LIBRARY.",
                                textAlign: TextAlign.center,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                                  fontSize: isCompact ? 10.sp : 10.0,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 24.h : 20.0),
                          ],

                          _buildSectionHeader("CALORIES", isCompact),
                          SizedBox(height: isCompact ? 8.h : 6.0),
                          _buildTextFieldWithoutLabel(
                            _caloriesController, 
                            isNumber: true, 
                            suffix: "kcal",
                            isCompact: isCompact,
                            inputFormatters: [
                              TextInputFormatter.withFunction((oldValue, newValue) {
                                final text = newValue.text;
                                if (text.isEmpty) return newValue;
                                if (double.tryParse(text) == null && text != '.') return oldValue;
                                if (RegExp(r'^\d{0,4}(\.\d{0,3})?$').hasMatch(text)) {
                                  return newValue;
                                }
                                return oldValue;
                              }),
                            ],
                          ),
                          SizedBox(height: isCompact ? 24.h : 20.0),
                          _buildSectionHeader("MACROS (OPTIONAL)", isCompact),
                          SizedBox(height: isCompact ? 16.h : 12.0),
                          Row(
                            children: [
                              Expanded(child: _buildMacroInputBlock("PROTEIN", "4 kcal/g", _proteinController, isCompact)),
                              SizedBox(width: isCompact ? 12.w : 12.0),
                              Expanded(child: _buildMacroInputBlock("CARBS", "4 kcal/g", _carbsController, isCompact)),
                              SizedBox(width: isCompact ? 12.w : 12.0),
                              Expanded(child: _buildMacroInputBlock("FATS", "9 kcal/g", _fatsController, isCompact)),
                            ],
                          ),
                          if (!_isMacroValid) ...[
                            SizedBox(height: isCompact ? 16.h : 12.0),
                            _buildMacroError(isCompact),
                          ],
                          SizedBox(height: isCompact ? 32.h : 24.0),
                          _buildActionButtons(isCompact),
                        ],
                      ),
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

  Widget _buildMacroInputBlock(String label, String energy, TextEditingController controller, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: isCompact ? 9.sp : 9.0)),
            Text(energy, style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: isCompact ? 9.sp : 9.0, fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: isCompact ? 8.h : 6.0),
        _buildMacroField(controller, isCompact),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isCompact) {
    return Row(
      children: [
        Container(
          width: 2.5,
          height: 12.0,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(2.0),
          ),
        ),
        const SizedBox(width: 6.0),
        Text(
          title,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: isCompact ? 10.sp : 10.0,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAddChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isCompact,
    bool isStack = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(right: isCompact ? 8.w : 8.0),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16.w : 14.0, 
          vertical: isCompact ? 8.h : 6.0
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.crimson.withValues(alpha: 0.2) 
              : AppColors.surfaceLight.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
          border: Border.all(
            color: isSelected 
                ? AppColors.crimson 
                : AppColors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isStack ? Icons.layers_rounded : Icons.medication_rounded,
              size: isCompact ? 14.r : 14.0,
              color: isSelected ? AppColors.crimson : AppColors.textSecondary,
            ),
            SizedBox(width: isCompact ? 6.w : 6.0),
            Text(
              label.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: isCompact ? 10.sp : 10.0,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextFieldWithoutLabel(TextEditingController controller, {bool isNumber = false, String? suffix, String? hint, List<TextInputFormatter>? inputFormatters, required bool isCompact}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      inputFormatters: inputFormatters,
      style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: isCompact ? 14.sp : 14.0),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.3), fontSize: isCompact ? null : 14.0),
        suffixText: suffix,
        suffixStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: isCompact ? null : 14.0),
        filled: true,
        fillColor: AppColors.background.withValues(alpha: 0.5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), borderSide: BorderSide.none),
        contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0, vertical: isCompact ? 14.h : 12.0),
      ),
    );
  }

  Widget _buildMacroField(TextEditingController controller, bool isCompact) {
    return Container(
      height: isCompact ? 60.h : 52.0,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 14.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTextStyles.h2.copyWith(
                color: Colors.white, 
                fontSize: isCompact ? 20.sp : 18.0,
                fontWeight: FontWeight.w500,
              ),
              inputFormatters: [
                TextInputFormatter.withFunction((oldValue, newValue) {
                  final text = newValue.text;
                  if (text.isEmpty) return newValue;
                  if (double.tryParse(text) == null && text != '.') return oldValue;
                  if (RegExp(r'^\d{0,3}(\.\d{0,2})?$').hasMatch(text)) {
                    return newValue;
                  }
                  return oldValue;
                }),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: "",
              ),
            ),
          ),
          Text(
            "g",
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.crimson, 
              fontSize: isCompact ? 14.sp : 14.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiplierSection(bool isCompact) {
    final supplementProvider = context.watch<SupplementProvider>();
    final bool hasActiveSupps = supplementProvider.library.any((s) => s.isActive);
    final bool hasStacks = supplementProvider.supplementStacks.isNotEmpty;
    final bool canMultiply = hasActiveSupps || hasStacks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("SERVING", isCompact),
        SizedBox(height: isCompact ? 12.h : 10.0),
        Container(
          height: isCompact ? 60.h : 54.0,
          padding: EdgeInsets.symmetric(horizontal: isCompact ? 6.w : 4.0),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              _multiplierStepBtn(Icons.remove, () {
                if (_multiplier > 0.5) {
                  final double newVal = _multiplier - 0.5;
                  setState(() {
                    _multiplier = newVal;
                    _multiplierController.text = (newVal % 1 == 0 ? newVal.toInt() : newVal.toStringAsFixed(2)).toString();
                  });
                }
              }, isCompact),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      IntrinsicWidth(
                        child: TextField(
                          controller: _multiplierController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h2.copyWith(
                            color: Colors.white, 
                            fontSize: isCompact ? 22.sp : 20.0,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          inputFormatters: [
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              final text = newValue.text;
                              if (text.isEmpty) return newValue;
                              if (double.tryParse(text) == null && text != '.') return oldValue;
                              if (RegExp(r'^\d{0,3}(\.\d{0,2})?$').hasMatch(text)) {
                                return newValue;
                              }
                              return oldValue;
                            }),
                          ],
                          onChanged: (val) {
                            final double? parsed = double.tryParse(val);
                            if (parsed != null && parsed > 0) {
                              _multiplier = parsed;
                            } else {
                              _multiplier = 0.0;
                            }
                            setState(() {}); 
                          },
                        ),
                      ),
                      Text(
                        "X",
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.crimson, 
                          fontSize: isCompact ? 18.sp : 16.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _multiplierStepBtn(Icons.add, () {
                if (_multiplier < 999) {
                  final double newVal = _multiplier + 0.5;
                  setState(() {
                    _multiplier = newVal;
                    _multiplierController.text = (newVal % 1 == 0 ? newVal.toInt() : newVal.toStringAsFixed(2)).toString();
                  });
                }
              }, isCompact),
            ],
          ),
        ),
        
        SizedBox(height: isCompact ? 16.h : 12.0),
        Opacity(
          opacity: canMultiply ? 1.0 : 0.3,
          child: IgnorePointer(
            ignoring: !canMultiply,
            child: GestureDetector(
              onTap: () => setState(() => _multiplySupps = !_multiplySupps),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: isCompact ? 4.h : 4.0),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isCompact ? 20.r : 20.0,
                      height: isCompact ? 20.r : 20.0,
                      decoration: BoxDecoration(
                        color: (canMultiply && _multiplySupps) ? AppColors.crimson : Colors.transparent,
                        border: Border.all(
                          color: (canMultiply && _multiplySupps) ? AppColors.crimson : AppColors.white.withValues(alpha: 0.2), 
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(isCompact ? 6.r : 6.0),
                      ),
                      child: (canMultiply && _multiplySupps) ? Icon(Icons.check, color: Colors.white, size: isCompact ? 14.r : 14.0) : null,
                    ),
                    SizedBox(width: isCompact ? 12.w : 12.0),
                    Expanded(
                      child: Text(
                        canMultiply 
                            ? "MULTIPLY SUPPLEMENT DOSAGE WITH SERVINGS"
                            : "MULTIPLY SUPPLEMENT DOSAGE (DISABLED - NO ACTIVE SUPPS)",
                        style: AppTextStyles.labelSmall.copyWith(
                          color: (canMultiply && _multiplySupps) ? Colors.white : AppColors.textSecondary,
                          fontSize: isCompact ? 9.sp : 9.0,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _multiplierStepBtn(IconData icon, VoidCallback onTap, bool isCompact) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: isCompact ? 48.r : 44.0,
        height: isCompact ? 48.r : 44.0,
        margin: EdgeInsets.symmetric(vertical: isCompact ? 6.h : 4.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 20.0),
      ),
    );
  }

  Widget _buildHandle(bool isCompact) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(bottom: isCompact ? 20.h : 16.0),
        width: isCompact ? 40.w : 40.0,
        height: isCompact ? 4.h : 4.0,
        decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2.r)),
      ),
    );
  }

  Widget _buildIngredientConfigSection(List<Supplement> allSupps, List<SupplementStack> stacks, bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: isCompact ? 14.r : 14.0, color: AppColors.crimson),
              SizedBox(width: isCompact ? 10.w : 10.0),
              Text(
                "DOSAGE CONFIGURATION",
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: isCompact ? 10.sp : 10.0,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 16.h : 12.0),
          
          ..._supplementAmounts.entries.map((entry) {
            final supp = allSupps.cast<Supplement?>().firstWhere((s) => s?.id == entry.key, orElse: () => null);
            if (supp == null) return const SizedBox.shrink();
            
            return _buildAmountRow(
              id: supp.id,
              label: supp.name,
              value: entry.value,
              servingUnit: supp.servingUnit,
              weightUnit: supp.weightUnit,
              weightPerServing: supp.weightPerServing,
              initialUseServing: _useServingsForSupps[supp.id] ?? true,
              isCompact: isCompact,
              onChanged: (newVal, useServing) {
                setState(() {
                  _supplementAmounts[entry.key] = newVal;
                  _useServingsForSupps[supp.id] = useServing;
                });
              },
            );
          }),

          ..._stackItemAmounts.entries.map((entry) {
            final stack = stacks.cast<SupplementStack?>().firstWhere((s) => s?.id == entry.key, orElse: () => null);
            if (stack == null) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_supplementAmounts.isNotEmpty || _stackItemAmounts.keys.first != entry.key) 
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: isCompact ? 8.h : 6.0),
                    child: Divider(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                Row(
                  children: [
                    Icon(Icons.layers_rounded, size: isCompact ? 14.r : 14.0, color: AppColors.crimson),
                    SizedBox(width: isCompact ? 10.w : 10.0),
                    Text(
                      stack.name.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white, 
                        fontWeight: FontWeight.w500,
                        fontSize: isCompact ? 11.sp : 11.0,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isCompact ? 12.h : 10.0),
                ...entry.value.entries.map((itemEntry) {
                  final item = stack.items.cast<Supplement?>().firstWhere((i) => i?.id == itemEntry.key, orElse: () => null);
                  if (item == null) return const SizedBox.shrink();

                  return Padding(
                    padding: EdgeInsets.only(left: isCompact ? 12.w : 12.0),
                    child: _buildAmountRow(
                      id: item.id,
                      label: item.name,
                      value: itemEntry.value,
                      servingUnit: item.servingUnit,
                      weightUnit: item.weightUnit,
                      weightPerServing: item.weightPerServing,
                      initialUseServing: _useServingsForSupps[item.id] ?? true,
                      isNested: true,
                      isCompact: isCompact,
                      onChanged: (newVal, useServing) {
                        setState(() {
                          _stackItemAmounts[entry.key]![itemEntry.key] = newVal;
                          _useServingsForSupps[item.id] = useServing;
                        });
                      },
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAmountRow({
    required String id,
    required String label,
    required double value,
    required String servingUnit,
    required String weightUnit,
    required double weightPerServing,
    required Function(double, bool) onChanged,
    required bool isCompact,
    bool initialUseServing = true,
    bool isNested = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isNested ? AppColors.textSecondary : Colors.white.withValues(alpha: 0.9), 
              fontSize: isCompact ? 11.sp : 11.0,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isCompact ? 10.h : 8.0),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: isCompact ? 48.h : 44.0,
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.w : 8.0),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      _miniStepBtn(Icons.remove, () {
                        final step = initialUseServing ? 0.5 : 1.0;
                        onChanged((value - step).clamp(0, 999.0), initialUseServing);
                      }, isCompact),
                      Expanded(
                        child: TextField(
                          controller: TextEditingController(
                            text: value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1)
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h3.copyWith(fontSize: isCompact ? 16.sp : 14.0, color: Colors.white),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          inputFormatters: [
                            TextInputFormatter.withFunction((oldValue, newValue) {
                              final text = newValue.text;
                              if (text.isEmpty) return newValue;
                              if (double.tryParse(text) == null && text != '.') return oldValue;
                              if (RegExp(r'^\d{0,3}(\.\d{0,2})?$').hasMatch(text)) {
                                return newValue;
                              }
                              return oldValue;
                            }),
                          ],
                          onSubmitted: (val) {
                            final d = double.tryParse(val);
                            if (d != null) onChanged(d, initialUseServing);
                          },
                        ),
                      ),
                      _miniStepBtn(Icons.add, () {
                        final step = initialUseServing ? 0.5 : 1.0;
                        onChanged((value + step).clamp(0, 999.0), initialUseServing);
                      }, isCompact),
                    ],
                  ),
                ),
              ),
              SizedBox(width: isCompact ? 12.w : 12.0),
              _buildUnitToggle(
                leftLabel: servingUnit,
                rightLabel: weightUnit,
                isLeftSelected: initialUseServing,
                isCompact: isCompact,
                onToggle: () {
                  double newValue;
                  if (initialUseServing) {
                    newValue = value * weightPerServing;
                  } else {
                    newValue = weightPerServing > 0 ? value / weightPerServing : value;
                  }
                  onChanged(newValue, !initialUseServing);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitToggle({
    required String leftLabel,
    required String rightLabel,
    required bool isLeftSelected,
    required VoidCallback onToggle,
    required bool isCompact,
  }) {
    return Container(
      height: isCompact ? 48.h : 44.0,
      padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption(leftLabel, isLeftSelected, onToggle, isCompact),
          _buildToggleOption(rightLabel, !isLeftSelected, onToggle, isCompact),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String text, bool isSelected, VoidCallback onTap, bool isCompact) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 12.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson : Colors.transparent,
          borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
        ),
        child: Text(
          text.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: isCompact ? 9.sp : 9.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _miniStepBtn(IconData icon, VoidCallback onTap, bool isCompact) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(isCompact ? 8.r : 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0),
        ),
        child: Icon(icon, color: AppColors.crimson, size: isCompact ? 18.r : 18.0),
      ),
    );
  }

  Widget _buildMacroError(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12.r : 12.0),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), border: Border.all(color: AppColors.error.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.error, size: isCompact ? 18.r : 18.0),
          SizedBox(width: isCompact ? 10.w : 10.0),
          Expanded(
            child: Text(
              "Macros (${_calculatedCalories.toInt()} kcal) exceed total calories",
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.error, fontSize: isCompact ? 10.sp : 10.0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isCompact) {
    final enabled = _canSubmit;
    final String label = _getButtonLabel(""); 

    if (widget.isLibraryOnly) {
      return _buildButton(
        label: enabled ? "SAVE MEAL" : label,
        enabled: enabled,
        isCompact: isCompact,
        onTap: () => _handleSave(true),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: enabled ? () => _handleSave(false) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: isCompact ? 50.h : 44.0,
            width: double.infinity,
            decoration: BoxDecoration(
              color: enabled 
                  ? AppColors.crimson.withValues(alpha: 0.1) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
              border: Border.all(
                color: enabled 
                    ? AppColors.crimson.withValues(alpha: 0.5) 
                    : AppColors.white.withValues(alpha: 0.05),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              enabled ? "LOG MEAL" : label,
              style: AppTextStyles.buttonPrimary.copyWith(
                color: enabled ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.3),
                fontSize: isCompact ? 12.sp : 12.0,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        SizedBox(height: isCompact ? 12.h : 10.0),
        _buildButton(
          label: enabled ? "LOG AND SAVE MEAL" : label,
          enabled: enabled,
          isCompact: isCompact,
          onTap: () => _handleSave(true),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isCompact ? (enabled ? 54.h : 50.h) : 48.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: enabled ? AppColors.crimson : AppColors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          boxShadow: enabled ? [
            BoxShadow(
              color: AppColors.crimson.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.buttonPrimary.copyWith(
            color: enabled ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.3),
            fontSize: isCompact ? 12.sp : 12.0,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
