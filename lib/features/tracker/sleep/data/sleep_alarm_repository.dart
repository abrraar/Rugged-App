// lib/features/tracker/sleep/data/sleep_alarm_repository.dart

import 'package:sqflite/sqflite.dart';
import '../../../../../core/database/database_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';

class SleepAlarmSettings {
  final bool bedtimeEnabled;
  final int bedtimeHour;
  final int bedtimeMinute;
  final String? bedtimeAudioPath;
  final bool wakeUpEnabled;
  final int wakeUpHour;
  final int wakeUpMinute;
  final String? wakeUpAudioPath;
  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  SleepAlarmSettings({
    this.bedtimeEnabled = false,
    this.bedtimeHour = 22,
    this.bedtimeMinute = 30,
    this.bedtimeAudioPath,
    this.wakeUpEnabled = false,
    this.wakeUpHour = 6,
    this.wakeUpMinute = 45,
    this.wakeUpAudioPath,
    this.isSynced = 1,
    this.updatedAt,
    this.userId,
  });

  Map<String, dynamic> toMap({bool forCloud = false}) {
    return {
      'user_id': userId,
      'bedtime_enabled': forCloud ? bedtimeEnabled : (bedtimeEnabled ? 1 : 0),
      'bedtime_hour': bedtimeHour,
      'bedtime_minute': bedtimeMinute,
      'bedtime_audio_path': bedtimeAudioPath,
      'wake_up_enabled': forCloud ? wakeUpEnabled : (wakeUpEnabled ? 1 : 0),
      'wake_up_hour': wakeUpHour,
      'wake_up_minute': wakeUpMinute,
      'wake_up_audio_path': wakeUpAudioPath,
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory SleepAlarmSettings.fromMap(Map<String, dynamic> map) {
    // Helper to handle both boolean (Cloud) and integer (Local) types
    bool parseBool(dynamic val) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      return false;
    }

    return SleepAlarmSettings(
      bedtimeEnabled: parseBool(map['bedtime_enabled']),
      bedtimeHour: map['bedtime_hour'] as int? ?? 22,
      bedtimeMinute: map['bedtime_minute'] as int? ?? 30,
      bedtimeAudioPath: map['bedtime_audio_path'] as String?,
      wakeUpEnabled: parseBool(map['wake_up_enabled']),
      wakeUpHour: map['wake_up_hour'] as int? ?? 6,
      wakeUpMinute: map['wake_up_minute'] as int? ?? 45,
      wakeUpAudioPath: map['wake_up_audio_path'] as String?,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      userId: map['user_id'] as String?,
    );
  }

  SleepAlarmSettings copyWith({
    bool? bedtimeEnabled,
    int? bedtimeHour,
    int? bedtimeMinute,
    String? bedtimeAudioPath,
    bool? wakeUpEnabled,
    int? wakeUpHour,
    int? wakeUpMinute,
    String? wakeUpAudioPath,
    int? isSynced,
    DateTime? updatedAt,
    String? userId,
  }) {
    return SleepAlarmSettings(
      bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
      bedtimeHour: bedtimeHour ?? this.bedtimeHour,
      bedtimeMinute: bedtimeMinute ?? this.bedtimeMinute,
      bedtimeAudioPath: bedtimeAudioPath ?? this.bedtimeAudioPath,
      wakeUpEnabled: wakeUpEnabled ?? this.wakeUpEnabled,
      wakeUpHour: wakeUpHour ?? this.wakeUpHour,
      wakeUpMinute: wakeUpMinute ?? this.wakeUpMinute,
      wakeUpAudioPath: wakeUpAudioPath ?? this.wakeUpAudioPath,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}


class SleepAlarmRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  SupabaseClient get _supabase => Supabase.instance.client;
  bool get _isPro => AuthProvider().isPro;

  SleepAlarmRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  Future<SleepAlarmSettings> getSettings() async {
    // 1. Try Local First
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('sleep_alarm_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
    SleepAlarmSettings settings;
    
    if (maps.isNotEmpty) {
      debugPrint("SleepAlarmRepository: Found local settings");
      settings = SleepAlarmSettings.fromMap(maps.first);
    } else {
      debugPrint("SleepAlarmRepository: No local settings, using defaults");
      settings = SleepAlarmSettings(userId: userId);
    }

    if (!_isPro) return settings;

    // 2. Try Cloud and sync if newer/different
    try {
      debugPrint("SleepAlarmRepository: Fetching from cloud for user $userId...");
      final cloudResponse = await _supabase
          .from('sleep_alarm_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (cloudResponse != null) {
        debugPrint("SleepAlarmRepository: Found cloud settings: $cloudResponse");
        final cloudSettings = SleepAlarmSettings.fromMap(cloudResponse);
        
        // If local was empty (fresh install), or if cloud is different, sync locally
        if (maps.isEmpty) {
          debugPrint("SleepAlarmRepository: Fresh install detected, restoring from cloud...");
          await saveSettings(cloudSettings, syncToCloud: false);
          return cloudSettings;
        }
      } else {
        debugPrint("SleepAlarmRepository: No cloud settings found for this user.");
      }
    } catch (e) {
      debugPrint("SleepAlarmRepository: Cloud fetch error: $e");
    }

    return settings;
  }

  Future<void> saveSettings(SleepAlarmSettings settings, {bool syncToCloud = true, bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final List<Map<String, dynamic>> maps = await db.query('sleep_alarm_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
      if (maps.isNotEmpty) {
        final localIsSynced = (maps.first['is_synced'] as num?)?.toInt() ?? 1;
        final localUpdatedAt = maps.first['updated_at'] != null 
            ? DateTime.tryParse(maps.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (settings.updatedAt != null && localUpdatedAt != null && settings.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }
    
    // Local Save: Always use id = 1 for the singleton settings row
    final localData = settings.toMap(forCloud: false);
    localData['id'] = 1;
    
    await db.insert(
      'sleep_alarm_settings',
      localData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (syncToCloud && _isPro) {
      try {
        final cloudData = settings.toMap(forCloud: true);
        cloudData['user_id'] = userId;
        cloudData.remove('is_synced');
        cloudData.remove('updated_at');
        
        debugPrint("SleepAlarmRepository: Upserting to cloud: $cloudData");
        
        // Cloud Upsert: Use user_id as the unique constraint
        await _supabase.from('sleep_alarm_settings').upsert(cloudData, onConflict: 'user_id');
        debugPrint("SleepAlarmRepository: Cloud save successful.");

        // Mark local as synced
        await db.update('sleep_alarm_settings', {'is_synced': 1}, where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
      } catch (e) {
        debugPrint("SleepAlarmRepository: Cloud save error: $e");
        rethrow;
      }
    }
  }

  Future<SleepAlarmSettings?> getUnsyncedSettings() async {
    if (!_isPro) return null;
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('sleep_alarm_settings', where: 'is_synced = 0 AND id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) return SleepAlarmSettings.fromMap(maps.first);
    return null;
  }
}
