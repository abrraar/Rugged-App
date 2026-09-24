import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/services/connectivity_service.dart';
import 'package:rugged/core/services/notification_service.dart';
import 'package:rugged/features/tracker/cycle_tracker/model/cycle_settings.dart'; // For WeightUnit
import '../model/body_comp_log.dart';
import '../model/body_comp_settings.dart';
import '../data/body_comp_local_repository.dart';
import '../data/body_comp_cloud_repository.dart';

import 'package:rugged/core/providers/sync_provider.dart';

class BodyCompProvider with ChangeNotifier {
  BodyCompLocalRepository? _localRepo;
  BodyCompCloudRepository _cloudRepo = BodyCompCloudRepository();
  NotificationService _notificationService = NotificationService();
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  void setRepositories({BodyCompLocalRepository? local, BodyCompCloudRepository? cloud, NotificationService? notifications}) {
    if (local != null) _localRepo = local;
    if (cloud != null) _cloudRepo = cloud;
    if (notifications != null) _notificationService = notifications;
  }

  List<BodyCompLog> _logs = [];
  BodyCompSettings _settings = BodyCompSettings();
  bool _isLoading = false;

  static const double kgToLbsMultiplier = 2.205;

  List<BodyCompLog> get logs => _logs;
  BodyCompSettings get settings => _settings;
  Set<String> get visibleMetrics => _settings.visibleMetrics;
  bool get isLoading => _isLoading;

  Future<void> setVisibleMetrics(Set<String> metrics) async {
    await updateSettings(_settings.copyWith(visibleMetrics: metrics));
  }

  void initializeForUser(String userId) {
    _localRepo = BodyCompLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscriptions(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    debugPrint("BodyCompProvider: Reconnected. Triggering sync...");
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscriptions(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:body_comp_sync:$userId');

    final tables = ['body_comp_weight_logs', 'body_comp_fats_logs', 'body_comp_muscle_logs'];

    for (var table in tables) {
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) async {
          debugPrint("Realtime $table Update: ${payload.eventType}");
          
          final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
          if (recordUserId != userId) return;

          final type = _getTypeFromTable(table);

          if (payload.newRecord.isNotEmpty) {
            final log = BodyCompLog.fromMap(payload.newRecord, type);
            
            final localLogs = await _localRepo!.getAllLogs();
            final localIdx = localLogs.indexWhere((l) => l.id == log.id);

            if (localIdx == -1 || localLogs[localIdx].isSynced == 1) {
              await _localRepo!.insertLog(log);
              
              final index = _logs.indexWhere((l) => l.id == log.id);
              if (index != -1) {
                _logs[index] = log;
              } else {
                _logs.add(log);
                _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              }
              notifyListeners();
            }
          } else if (payload.eventType == PostgresChangeEvent.delete) {
            final String? id = payload.oldRecord['id'];
            if (id != null) {
              await _localRepo!.deleteLog(id, type);
              _logs.removeWhere((l) => l.id == id);
              notifyListeners();
            }
          }
        },
      );
    }

    _realtimeChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("BodyCompProvider: Realtime Subscribed/Reconnected. Syncing...");
        await _syncLocalToCloud();
        await _loadData(silent: true);
      }
    });
  }

  BodyMetricType _getTypeFromTable(String table) {
    if (table == 'body_comp_weight_logs') return BodyMetricType.weight;
    if (table == 'body_comp_fats_logs') return BodyMetricType.fat;
    return BodyMetricType.muscle;
  }

  String _getTableFromType(BodyMetricType type) {
    if (type == BodyMetricType.weight) return 'body_comp_weight_logs';
    if (type == BodyMetricType.fat) return 'body_comp_fats_logs';
    return 'body_comp_muscle_logs';
  }

  // --- Conversion Helpers ---

  double getDisplayValue(BodyCompLog log) {
    if (log.unit == BodyMetricUnit.percentage) return log.valueKg;
    return _settings.weightUnit == WeightUnit.kgs ? log.valueKg : log.valueLbs;
  }

  String getDisplayUnit(BodyCompLog log) {
    if (log.unit == BodyMetricUnit.percentage) return "%";
    return _settings.weightUnit == WeightUnit.kgs ? "KG" : "LBS";
  }

  Map<String, double> calculateDualValues(double value, BodyMetricUnit inputUnit) {
    if (inputUnit == BodyMetricUnit.percentage) {
      return {'kg': value, 'lbs': value};
    }
    
    // 1. Enforce strict 3-decimal truncation for input
    String valStr = value.toStringAsFixed(10);
    int dotIdx = valStr.indexOf('.');
    double cleanValue = double.parse(valStr.substring(0, dotIdx + 4));
    
    if (_settings.weightUnit == WeightUnit.kgs) {
      double rawLbs = cleanValue * kgToLbsMultiplier;
      String lbsStr = rawLbs.toStringAsFixed(10);
      int lbsDotIdx = lbsStr.indexOf('.');

      return {
        'kg': cleanValue,
        'lbs': double.parse(lbsStr.substring(0, lbsDotIdx + 4)),
      };
    } else {
      double rawKg = cleanValue / kgToLbsMultiplier;
      String kgStr = rawKg.toStringAsFixed(10);
      int kgDotIdx = kgStr.indexOf('.');

      return {
        'kg': double.parse(kgStr.substring(0, kgDotIdx + 4)),
        'lbs': cleanValue,
      };
    }
  }

  Future<void> _syncLocalToCloud() async {
    if (_localRepo == null) return;

    final syncProv = SyncProvider();
    syncProv.startFeatureSync();

    try {
      final count = await _localRepo!.getUnsyncedCount();
      syncProv.addTotalItems(count);

      // 1. Push Unsynced Deletions
      final deletions = await _localRepo!.getPendingDeletions();
      for (var del in deletions) {
        final id = del['id'] as String;
        final table = del['table_name'] as String;
        final type = _getTypeFromTable(table);
        try {
          await _cloudRepo.deleteLog(id, type);
          await _localRepo!.removeFromDeletionQueue(id);
          syncProv.incrementCompleted();
        } catch (_) {}
      }

      // 2. Push Unsynced Logs
      final unsyncedLogs = await _localRepo!.getUnsyncedLogs();
      for (var log in unsyncedLogs) {
        try {
          await _cloudRepo.insertLog(log);
          await _localRepo!.markLogSynced(log.id, log.type);
          syncProv.incrementCompleted();
        } catch (_) {}
      }

      // 3. Push Unsynced Settings
      final unsyncedSettings = await _localRepo!.getUnsyncedSettings();
      if (unsyncedSettings != null) {
        try {
          await _cloudRepo.saveSettings(unsyncedSettings);
          await _localRepo!.markSettingsSynced();
          syncProv.incrementCompleted();
        } catch (_) {}
      }
    } finally {
      syncProv.endFeatureSync();
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_localRepo == null) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // MANDATORY: Push local offline changes BEFORE pulling from cloud
      await _syncLocalToCloud();

      _settings = await _localRepo!.getSettings();
      _logs = await _localRepo!.getAllLogs();
      
      // Schedule reminders after local load
      _notificationService.scheduleBodyCompReminders(_settings);
      
      notifyListeners();

      final cloudSettings = await _cloudRepo.getSettings();
      if (cloudSettings != null) {
        if (_settings.isSynced == 1) {
          _settings = cloudSettings;
          await _localRepo!.saveSettings(_settings);
          _notificationService.scheduleBodyCompReminders(_settings);
        }
      } else {
        // If settings don't exist in cloud, push our local ones
        _syncBodyCompSettings(_settings);
      }

      final cloudLogs = await _cloudRepo.getAllLogs();
      if (cloudLogs != null) {
        final localLogs = await _localRepo!.getAllLogs();
        final localMap = {for (var l in localLogs) l.id: l};

        bool logChanged = false;

        // 2. Add/Update logs from cloud
        for (var log in cloudLogs) {
          final localL = localMap[log.id];
          if (localL == null || localL.isSynced == 1) {
            await _localRepo!.insertLog(log);
            logChanged = true;
          }
        }
        if (logChanged) _logs = await _localRepo!.getAllLogs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading body comp data: $e");
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> forceRefresh() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint("BodyCompProvider: FORCE REFRESH TRIGGERED");
      await _syncLocalToCloud();
      await _loadData(silent: true);
      debugPrint("BodyCompProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("BodyCompProvider: Force Refresh Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLog(BodyCompLog log) async {
    if (_localRepo == null) return;
    final localLog = log.copyWith(
      isSynced: 0, 
      userId: _localRepo!.userId,
      updatedAt: DateTime.now(),
    );
    _logs.add(localLog);
    _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();

    try {
      await _localRepo!.insertLog(localLog);
      _syncBodyCompLog(localLog);
    } catch (e) {
      debugPrint("Error saving body comp log locally: $e");
    }
  }

  Future<void> _syncBodyCompLog(BodyCompLog log) async {
    try {
      await _cloudRepo.insertLog(log);
      await _localRepo!.markLogSynced(log.id, log.type);
      final idx = _logs.indexWhere((l) => l.id == log.id);
      if (idx != -1) {
        _logs[idx] = log.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Body Comp Add): $e");
    }
  }

  Future<void> deleteLog(String id, BodyMetricType type) async {
    if (_localRepo == null) return;
    _logs.removeWhere((l) => l.id == id);
    notifyListeners();

    try {
      await _localRepo!.deleteLog(id, type);
      await _localRepo!.addToDeletionQueue(id, _getTableFromType(type));
      _syncBodyCompDelete(id, type);
    } catch (e) {
      debugPrint("Error deleting body comp log locally: $e");
    }
  }

  Future<void> _syncBodyCompDelete(String id, BodyMetricType type) async {
    try {
      await _cloudRepo.deleteLog(id, type);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Body Comp Delete): $e");
    }
  }

  Future<void> updateSettings(BodyCompSettings settings) async {
    if (_localRepo == null) return;
    final localSettings = settings.copyWith(
      isSynced: 0,
      updatedAt: DateTime.now(),
    );
    _settings = localSettings;
    
    // Trigger notification scheduling
    _notificationService.scheduleBodyCompReminders(_settings);
    
    notifyListeners();
    try {
      await _localRepo!.saveSettings(localSettings);
      await _syncBodyCompSettings(localSettings);
    } catch (e) {
      debugPrint("Error saving body comp settings locally: $e");
    }
  }

  Future<void> _syncBodyCompSettings(BodyCompSettings settings) async {
    try {
      await _cloudRepo.saveSettings(settings);
      await _localRepo!.markSettingsSynced();
      if (_settings.isSynced == 0) {
        _settings = _settings.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Body Comp Settings): $e");
    }
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _logs.clear();
    _localRepo = null;
    notifyListeners();
  }
}
