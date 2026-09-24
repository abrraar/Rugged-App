import 'dart:convert';
import 'package:flutter/foundation.dart';

enum WeightUnit { lbs, kgs }

class CycleSettings {
  final WeightUnit weightUnit;
  final Set<String> visibleMetrics;
  final bool workoutRemindersEnabled;
  final int workoutReminderInterval;
  final bool smartAutoDateEnabled;
  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  CycleSettings({
    this.weightUnit = WeightUnit.lbs,
    this.visibleMetrics = const {"strength", "volume"},
    this.workoutRemindersEnabled = false,
    this.workoutReminderInterval = 2,
    this.smartAutoDateEnabled = true,
    this.isSynced = 1,
    this.updatedAt,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'user_id': userId,
      'weight_unit': weightUnit.name,
      'visible_metrics_json': jsonEncode(visibleMetrics.toList()),
      'workout_reminders_enabled': workoutRemindersEnabled ? 1 : 0,
      'workout_reminder_interval': workoutReminderInterval,
      'smart_auto_date_enabled': smartAutoDateEnabled ? 1 : 0,
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory CycleSettings.fromMap(Map<String, dynamic> map) {
    final rawMetrics = map['visible_metrics_json'];
    Set<String> metrics = {"strength", "volume"};

    if (rawMetrics != null) {
      try {
        if (rawMetrics is String) {
          final List<dynamic> decoded = jsonDecode(rawMetrics);
          metrics = Set<String>.from(decoded);
        } else if (rawMetrics is List) {
          metrics = Set<String>.from(rawMetrics);
        }
      } catch (e) {
        debugPrint("Error decoding visible metrics: $e");
      }
    }

    final rawSmartAutoDate = map['smart_auto_date_enabled'];
    final bool smartAutoDate = rawSmartAutoDate == null ? true : (rawSmartAutoDate == 1 || rawSmartAutoDate == true);

    return CycleSettings(
      weightUnit: WeightUnit.values.firstWhere(
        (e) => e.name == map['weight_unit'],
        orElse: () => WeightUnit.lbs,
      ),
      visibleMetrics: metrics,
      workoutRemindersEnabled: map['workout_reminders_enabled'] == 1,
      workoutReminderInterval: map['workout_reminder_interval'] ?? 2,
      smartAutoDateEnabled: smartAutoDate,
      isSynced: map['is_synced'] ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      userId: map['user_id'] as String?,
    );
  }

  CycleSettings copyWith({
    WeightUnit? weightUnit,
    Set<String>? visibleMetrics,
    bool? workoutRemindersEnabled,
    int? workoutReminderInterval,
    bool? smartAutoDateEnabled,
    int? isSynced,
    DateTime? updatedAt,
    String? userId,
  }) {
    return CycleSettings(
      weightUnit: weightUnit ?? this.weightUnit,
      visibleMetrics: visibleMetrics ?? this.visibleMetrics,
      workoutRemindersEnabled: workoutRemindersEnabled ?? this.workoutRemindersEnabled,
      workoutReminderInterval: workoutReminderInterval ?? this.workoutReminderInterval,
      smartAutoDateEnabled: smartAutoDateEnabled ?? this.smartAutoDateEnabled,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}


