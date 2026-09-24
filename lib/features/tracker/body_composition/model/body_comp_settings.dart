import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/cycle_settings.dart';

enum HeightUnit { cm, ftIn }

class BodyCompReminder {
  final List<int> days;
  final List<TimeOfDay> times;

  BodyCompReminder({
    required this.days,
    required this.times,
  });

  Map<String, dynamic> toMap() {
    return {
      'days': days,
      'times': times.map((t) => '${t.hour}:${t.minute}').toList(),
    };
  }

  factory BodyCompReminder.fromMap(Map<String, dynamic> map) {
    return BodyCompReminder(
      days: List<int>.from(map['days'] ?? []),
      times: (map['times'] as List? ?? []).map((t) {
        final parts = (t as String).split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }).toList(),
    );
  }

  BodyCompReminder copyWith({
    List<int>? days,
    List<TimeOfDay>? times,
  }) {
    return BodyCompReminder(
      days: days ?? this.days,
      times: times ?? this.times,
    );
  }
}

class BodyCompSettings {
  final WeightUnit weightUnit;
  final HeightUnit heightUnit;
  
  final bool weightRemindersEnabled;
  final List<BodyCompReminder> weightReminders;
  
  final bool fatRemindersEnabled;
  final List<BodyCompReminder> fatReminders;
  
  final bool muscleRemindersEnabled;
  final List<BodyCompReminder> muscleReminders;

  final Set<String> visibleMetrics;

  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  BodyCompSettings({
    this.weightUnit = WeightUnit.kgs,
    this.heightUnit = HeightUnit.cm,
    this.weightRemindersEnabled = false,
    this.weightReminders = const [],
    this.fatRemindersEnabled = false,
    this.fatReminders = const [],
    this.muscleRemindersEnabled = false,
    this.muscleReminders = const [],
    this.visibleMetrics = const {"weight", "fat", "muscle"},
    this.isSynced = 1,
    this.updatedAt,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'user_id': userId,
      'weight_unit': weightUnit.name,
      'height_unit': heightUnit.name,
      'weight_reminders_enabled': weightRemindersEnabled ? 1 : 0,
      'weight_reminders_json': jsonEncode(weightReminders.map((r) => r.toMap()).toList()),
      'fat_reminders_enabled': fatRemindersEnabled ? 1 : 0,
      'fat_reminders_json': jsonEncode(fatReminders.map((r) => r.toMap()).toList()),
      'muscle_reminders_enabled': muscleRemindersEnabled ? 1 : 0,
      'muscle_reminders_json': jsonEncode(muscleReminders.map((r) => r.toMap()).toList()),
      'visible_metrics_json': jsonEncode(visibleMetrics.toList()),
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory BodyCompSettings.fromMap(Map<String, dynamic> map) {
    List<BodyCompReminder> parseReminders(String? json) {
      if (json == null || json.isEmpty) return [];
      try {
        final List<dynamic> decoded = jsonDecode(json);
        return decoded.map((r) => BodyCompReminder.fromMap(r as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint("Error parsing reminders: $e");
        return [];
      }
    }

    final rawMetrics = map['visible_metrics_json'];
    Set<String> metrics = {"weight", "fat", "muscle"};
    if (rawMetrics != null) {
      try {
        if (rawMetrics is String) {
          final List<dynamic> decoded = jsonDecode(rawMetrics);
          metrics = Set<String>.from(decoded);
        } else if (rawMetrics is List) {
          metrics = Set<String>.from(rawMetrics);
        }
      } catch (e) {
        debugPrint("Error decoding body comp visible metrics: $e");
      }
    }

    return BodyCompSettings(
      weightUnit: WeightUnit.values.firstWhere(
        (e) => e.name == map['weight_unit'],
        orElse: () => WeightUnit.kgs,
      ),
      heightUnit: HeightUnit.values.firstWhere(
        (e) => e.name == map['height_unit'],
        orElse: () => HeightUnit.cm,
      ),
      weightRemindersEnabled: map['weight_reminders_enabled'] == 1,
      weightReminders: parseReminders(map['weight_reminders_json']),
      fatRemindersEnabled: map['fat_reminders_enabled'] == 1,
      fatReminders: parseReminders(map['fat_reminders_json']),
      muscleRemindersEnabled: map['muscle_reminders_enabled'] == 1,
      muscleReminders: parseReminders(map['muscle_reminders_json']),
      visibleMetrics: metrics,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      userId: map['user_id'] as String?,
    );
  }

  BodyCompSettings copyWith({
    WeightUnit? weightUnit,
    HeightUnit? heightUnit,
    bool? weightRemindersEnabled,
    List<BodyCompReminder>? weightReminders,
    bool? fatRemindersEnabled,
    List<BodyCompReminder>? fatReminders,
    bool? muscleRemindersEnabled,
    List<BodyCompReminder>? muscleReminders,
    Set<String>? visibleMetrics,
    int? isSynced,
    DateTime? updatedAt,
    String? userId,
  }) {
    return BodyCompSettings(
      weightUnit: weightUnit ?? this.weightUnit,
      heightUnit: heightUnit ?? this.heightUnit,
      weightRemindersEnabled: weightRemindersEnabled ?? this.weightRemindersEnabled,
      weightReminders: weightReminders ?? this.weightReminders,
      fatRemindersEnabled: fatRemindersEnabled ?? this.fatRemindersEnabled,
      fatReminders: fatReminders ?? this.fatReminders,
      muscleRemindersEnabled: muscleRemindersEnabled ?? this.muscleRemindersEnabled,
      muscleReminders: muscleReminders ?? this.muscleReminders,
      visibleMetrics: visibleMetrics ?? this.visibleMetrics,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}
