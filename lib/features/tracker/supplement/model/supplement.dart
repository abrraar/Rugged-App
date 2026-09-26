// lib/features/tracker/supplement/model/supplement.dart

import 'dart:convert';
import 'package:flutter/material.dart';

enum ReminderType { intake, lowStock }

enum ReminderMode { schedule, interval }

enum IntervalUnit { minute, hour, day }

class SupplementReminder {
  final List<int> days;
  final List<TimeOfDay> times;
  final double value;
  final ReminderType type;
  final String? supplementId;
  final List<String>? supplementIds;

  final ReminderMode reminderMode;
  final int? intervalValue;
  final IntervalUnit? intervalUnit;

  // NEW: Support for stack-specific values per supplement in a reminder
  final Map<String, double>? stackItemValues;

  SupplementReminder({
    required this.days,
    required this.times,
    required this.value,
    required this.type,
    this.supplementId,
    this.supplementIds,
    this.reminderMode = ReminderMode.schedule,
    this.intervalValue,
    this.intervalUnit,
    this.stackItemValues,
  });

  SupplementReminder copyWith({
    List<int>? days,
    List<TimeOfDay>? times,
    double? value,
    ReminderType? type,
    String? supplementId,
    List<String>? supplementIds,
    ReminderMode? reminderMode,
    int? intervalValue,
    IntervalUnit? intervalUnit,
    Map<String, double>? stackItemValues,
  }) {
    return SupplementReminder(
      days: days ?? this.days,
      times: times ?? this.times,
      value: value ?? this.value,
      type: type ?? this.type,
      supplementId: supplementId ?? this.supplementId,
      supplementIds: supplementIds ?? this.supplementIds,
      reminderMode: reminderMode ?? this.reminderMode,
      intervalValue: intervalValue ?? this.intervalValue,
      intervalUnit: intervalUnit ?? this.intervalUnit,
      stackItemValues: stackItemValues ?? this.stackItemValues,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'days': days,
      'times': times.map((t) => '${t.hour}:${t.minute}').toList(),
      'value': value,
      'type': type.name,
      'supplementId': supplementId,
      'supplementIds': supplementIds,
      'reminderMode': reminderMode.name,
      'intervalValue': intervalValue,
      'intervalUnit': intervalUnit?.name,
      'stackItemValues': stackItemValues?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    };
  }

  factory SupplementReminder.fromMap(Map<String, dynamic> map) {
    return SupplementReminder(
      days: List<int>.from(map['days'] ?? []),
      times: (map['times'] as List? ?? []).map((t) {
        final parts = (t as String).split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }).toList(),
      value: (map['value'] as num? ?? 1.0).toDouble(),
      type: ReminderType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => ReminderType.intake,
      ),
      supplementId: map['supplementId'],
      supplementIds: map['supplementIds'] != null
          ? List<String>.from(map['supplementIds'])
          : null,
      reminderMode: ReminderMode.values.firstWhere(
        (e) => e.name == map['reminderMode'],
        orElse: () => ReminderMode.schedule,
      ),
      intervalValue: map['intervalValue'],
      intervalUnit: map['intervalUnit'] != null
          ? IntervalUnit.values.firstWhere(
              (e) => e.name == map['intervalUnit'],
              orElse: () => IntervalUnit.minute,
            )
          : null,
      stackItemValues: map['stackItemValues'] != null
          ? (map['stackItemValues'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, double.parse(value.toString())),
            )
          : null,
    );
  }
}

// ─── NEW: INGREDIENT STRUCTURAL DATA TYPE ───
class SupplementIngredient {
  final String name; // e.g., "Vitamin D", "Vitamin C", "Zinc"
  final double amount; // e.g., 4000, 2500, 50
  final String unit; // e.g., "IU", "mg"

  SupplementIngredient({
    required this.name,
    required this.amount,
    required this.unit,
  });

  SupplementIngredient copyWith({String? name, double? amount, String? unit}) {
    return SupplementIngredient(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'amount': amount, 'unit': unit};
  }

  factory SupplementIngredient.fromMap(Map<String, dynamic> map) {
    return SupplementIngredient(
      name: map['name'] as String? ?? '',
      amount: (map['amount'] as num? ?? 0.0).toDouble(),
      unit: map['unit'] as String? ?? '',
    );
  }
}

class Supplement {
  final String id;
  final String name;
  final String servingUnit;
  final double weightPerServing;
  final String weightUnit;
  final String description;
  final double? totalStock;
  final double? remainingStock;
  final bool isActive;
  final bool notificationsEnabled;
  final List<SupplementReminder> reminders;

  // NEW LIST FIELD TRAPPING MULTIPLE COMPONENT INGREDIENTS
  final List<SupplementIngredient> ingredients;

  // EXTRA CONFIG FIELDS
  final DateTime? expiryDate;
  final double? caloriesPerUnit;
  final double? proteinPerUnit;
  final double? carbsPerUnit;
  final double? fatsPerUnit;

  // NEW: Shared by badge
  final String? sharedBy;
  final String? userId;
  final int isSynced;
  final DateTime? updatedAt;

  // --- SHORTCUT SETTINGS ---
  final bool isPinnedToHome;
  final double pinnedIntakeAmount;
  final bool pinnedUseServingsIntake;
  final double pinnedRestockAmount;
  final bool pinnedUseServingsRestock;

  Supplement({
    required this.id,
    required this.name,
    required this.servingUnit,
    required this.weightPerServing,
    required this.weightUnit,
    this.description = "",
    this.totalStock,
    this.remainingStock,
    this.isActive = true,
    this.notificationsEnabled = false,
    this.reminders = const [],
    this.ingredients = const [], // Default to an empty array
    this.expiryDate,
    this.caloriesPerUnit,
    this.proteinPerUnit,
    this.carbsPerUnit,
    this.fatsPerUnit,
    this.sharedBy,
    this.userId,
    this.isSynced = 0,
    this.updatedAt,
    this.isPinnedToHome = false,
    this.pinnedIntakeAmount = 1.0,
    this.pinnedUseServingsIntake = true,
    this.pinnedRestockAmount = 0.0,
    this.pinnedUseServingsRestock = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'serving_unit': servingUnit,
      'weight_per_serving': weightPerServing,
      'weight_unit': weightUnit,
      'description': description,
      'total_stock': totalStock,
      'remaining_stock': remainingStock,
      'is_active': isActive ? 1 : 0,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'expiry_date': expiryDate?.toIso8601String(),
      'calories_per_unit': caloriesPerUnit,
      'protein_per_unit': proteinPerUnit,
      'carbs_per_unit': carbsPerUnit,
      'fats_per_unit': fatsPerUnit,
      'shared_by': sharedBy,
      'is_pinned_to_home': isPinnedToHome ? 1 : 0,
      'pinned_intake_amount': pinnedIntakeAmount,
      'pinned_use_servings_intake': pinnedUseServingsIntake ? 1 : 0,
      'pinned_restock_amount': pinnedRestockAmount,
      'pinned_use_servings_restock': pinnedUseServingsRestock ? 1 : 0,
      'reminders_json': jsonEncode(reminders.map((r) => r.toMap()).toList()),
      'ingredients_json': jsonEncode(
        ingredients.map((i) => i.toMap()).toList(),
      ),
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory Supplement.fromMap(Map<String, dynamic> map) {
    final List<dynamic> decodedReminders = map['reminders_json'] != null
        ? jsonDecode(map['reminders_json'] as String)
        : [];

    // NEW: Decode internal text back into structural entities safely
    final List<dynamic> decodedIngredients = map['ingredients_json'] != null
        ? jsonDecode(map['ingredients_json'] as String)
        : [];

    return Supplement(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      name: map['name'] as String,
      servingUnit: map['serving_unit'] as String? ?? '',
      weightPerServing: (map['weight_per_serving'] as num? ?? 0.0).toDouble(),
      weightUnit: map['weight_unit'] as String? ?? '',
      description: map['description'] as String? ?? '',
      totalStock: (map['total_stock'] as num?)?.toDouble(),
      remainingStock: (map['remaining_stock'] as num?)?.toDouble(),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      notificationsEnabled: (map['notifications_enabled'] as int? ?? 0) == 1,
      expiryDate: map['expiry_date'] != null
          ? DateTime.parse(map['expiry_date'] as String)
          : null,
      caloriesPerUnit: (map['calories_per_unit'] as num?)?.toDouble(),
      proteinPerUnit: (map['protein_per_unit'] as num?)?.toDouble(),
      carbsPerUnit: (map['carbs_per_unit'] as num?)?.toDouble(),
      fatsPerUnit: (map['fats_per_unit'] as num?)?.toDouble(),
      sharedBy: map['shared_by'] as String?,
      isPinnedToHome: (map['is_pinned_to_home'] as int? ?? 0) == 1,
      pinnedIntakeAmount: (map['pinned_intake_amount'] as num? ?? 1.0)
          .toDouble(),
      pinnedUseServingsIntake:
          (map['pinned_use_servings_intake'] as int? ?? 1) == 1,
      pinnedRestockAmount: (map['pinned_restock_amount'] as num? ?? 0.0)
          .toDouble(),
      pinnedUseServingsRestock:
          (map['pinned_use_servings_restock'] as int? ?? 1) == 1,
      reminders: decodedReminders
          .map((r) => SupplementReminder.fromMap(r as Map<String, dynamic>))
          .toList(),
      ingredients: decodedIngredients
          .map((i) => SupplementIngredient.fromMap(i as Map<String, dynamic>))
          .toList(),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Supplement copyWith({
    String? id,
    String? name,
    String? servingUnit,
    double? weightPerServing,
    String? weightUnit,
    String? description,
    double? Function()? totalStock,
    double? Function()? remainingStock,
    bool? isActive,
    bool? notificationsEnabled,
    List<SupplementReminder>? reminders,
    List<SupplementIngredient>? ingredients,
    DateTime? Function()? expiryDate,
    double? Function()? caloriesPerUnit,
    double? Function()? proteinPerUnit,
    double? Function()? carbsPerUnit,
    double? Function()? fatsPerUnit,
    String? sharedBy,
    String? userId,
    int? isSynced,
    DateTime? updatedAt,
    bool? isPinnedToHome,
    double? pinnedIntakeAmount,
    bool? pinnedUseServingsIntake,
    double? pinnedRestockAmount,
    bool? pinnedUseServingsRestock,
  }) {
    return Supplement(
      id: id ?? this.id,
      name: name ?? this.name,
      servingUnit: servingUnit ?? this.servingUnit,
      weightPerServing: weightPerServing ?? this.weightPerServing,
      weightUnit: weightUnit ?? this.weightUnit,
      description: description ?? this.description,
      totalStock: totalStock != null ? totalStock() : this.totalStock,
      remainingStock: remainingStock != null ? remainingStock() : this.remainingStock,
      isActive: isActive ?? this.isActive,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminders: reminders ?? this.reminders,
      ingredients: ingredients ?? this.ingredients,
      expiryDate: expiryDate != null ? expiryDate() : this.expiryDate,
      caloriesPerUnit: caloriesPerUnit != null ? caloriesPerUnit() : this.caloriesPerUnit,
      proteinPerUnit: proteinPerUnit != null ? proteinPerUnit() : this.proteinPerUnit,
      carbsPerUnit: carbsPerUnit != null ? carbsPerUnit() : this.carbsPerUnit,
      fatsPerUnit: fatsPerUnit != null ? fatsPerUnit() : this.fatsPerUnit,
      sharedBy: sharedBy ?? this.sharedBy,
      userId: userId ?? this.userId,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      isPinnedToHome: isPinnedToHome ?? this.isPinnedToHome,
      pinnedIntakeAmount: pinnedIntakeAmount ?? this.pinnedIntakeAmount,
      pinnedUseServingsIntake:
          pinnedUseServingsIntake ?? this.pinnedUseServingsIntake,
      pinnedRestockAmount: pinnedRestockAmount ?? this.pinnedRestockAmount,
      pinnedUseServingsRestock:
          pinnedUseServingsRestock ?? this.pinnedUseServingsRestock,
    );
  }

}
