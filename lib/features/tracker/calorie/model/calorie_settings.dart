import 'dart:convert';
import 'package:flutter/foundation.dart';

class CalorieSettings {
  final int dailyCalorieGoal;
  final int proteinPercent;
  final int carbPercent;
  final int fatPercent;
  final bool trackMacros;
  final bool showRemaining;
  final Set<String> visibleMetrics;
  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  CalorieSettings({
    this.dailyCalorieGoal = 2500,
    this.proteinPercent = 25,
    this.carbPercent = 60,
    this.fatPercent = 15,
    this.trackMacros = true,
    this.showRemaining = true,
    this.visibleMetrics = const {"calories", "protein", "carbs", "fats"},
    this.isSynced = 1,
    this.updatedAt,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'user_id': userId,
      'daily_calorie_goal': dailyCalorieGoal,
      'protein_percent': proteinPercent,
      'carb_percent': carbPercent,
      'fat_percent': fatPercent,
      'track_macros': trackMacros,
      'show_remaining': showRemaining,
      'visible_metrics_json': jsonEncode(visibleMetrics.toList()),
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory CalorieSettings.fromMap(Map<String, dynamic> map) {
    bool parseBool(dynamic val) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      return true; // Default
    }

    final rawMetrics = map['visible_metrics_json'];
    Set<String> metrics = {"calories", "protein", "carbs", "fats"};
    if (rawMetrics != null) {
      try {
        if (rawMetrics is String) {
          final List<dynamic> decoded = jsonDecode(rawMetrics);
          metrics = Set<String>.from(decoded);
        } else if (rawMetrics is List) {
          metrics = Set<String>.from(rawMetrics);
        }
      } catch (e) {
        debugPrint("Error decoding calorie visible metrics: $e");
      }
    }

    return CalorieSettings(
      dailyCalorieGoal: (map['daily_calorie_goal'] as num?)?.toInt() ?? 2500,
      proteinPercent: (map['protein_percent'] as num?)?.toInt() ?? 25,
      carbPercent: (map['carb_percent'] as num?)?.toInt() ?? 60,
      fatPercent: (map['fat_percent'] as num?)?.toInt() ?? 15,
      trackMacros: parseBool(map['track_macros']),
      showRemaining: parseBool(map['show_remaining']),
      visibleMetrics: metrics,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      userId: map['user_id'] as String?,
    );
  }

  CalorieSettings copyWith({
    int? dailyCalorieGoal,
    int? proteinPercent,
    int? carbPercent,
    int? fatPercent,
    bool? trackMacros,
    bool? showRemaining,
    Set<String>? visibleMetrics,
    int? isSynced,
    DateTime? updatedAt,
    String? userId,
  }) {
    return CalorieSettings(
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      proteinPercent: proteinPercent ?? this.proteinPercent,
      carbPercent: carbPercent ?? this.carbPercent,
      fatPercent: fatPercent ?? this.fatPercent,
      trackMacros: trackMacros ?? this.trackMacros,
      showRemaining: showRemaining ?? this.showRemaining,
      visibleMetrics: visibleMetrics ?? this.visibleMetrics,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}
