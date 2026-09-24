// lib/features/tracker/hydration/provider/hydration_provider.dart

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/hydration_local_repository.dart';
import '../data/hydration_cloud_repository.dart';
import '../model/hydration_log.dart';
import '../model/hydration_settings.dart';
import '../model/hydration_reminder.dart';
import 'package:rugged/core/services/notification_service.dart';
import 'package:rugged/core/services/connectivity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/providers/sync_provider.dart';


class HydrationProvider with ChangeNotifier {
  HydrationLocalRepository? _localRepo;
  HydrationCloudRepository _cloudRepo = HydrationCloudRepository();
  NotificationService _notificationService = NotificationService();
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  void setRepositories({HydrationLocalRepository? local, HydrationCloudRepository? cloud, NotificationService? notifications}) {
    if (local != null) _localRepo = local;
    if (cloud != null) _cloudRepo = cloud;
    if (notifications != null) _notificationService = notifications;
  }
  
  List<HydrationLog> _logs = [];
  HydrationSettings _settings = HydrationSettings();
  bool _isLoading = false;

  static const double mlToOzFactor = 0.03;

  List<HydrationLog> get logs => _logs;
  HydrationSettings get settings => _settings;
  bool get isLoading => _isLoading;

  HydrationProvider() {
    _notificationService.addNotificationActionListener(_handleNotificationAction);
  }

  void _handleNotificationAction(String? payload, String? actionId) {
    if (actionId == 'log_water') {
      addWater(_settings.addValue);
    }
  }

  int get todayIntake {
    final now = DateTime.now();
    return _logs
        .where((log) =>
            log.timestamp.year == now.year &&
            log.timestamp.month == now.month &&
            log.timestamp.day == now.day)
        .fold(0, (sum, log) => sum + log.amountMl);
  }

  void initializeForUser(String userId) {
    _localRepo = HydrationLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    debugPrint("HydrationProvider: Reconnected. Triggering sync...");
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscription(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:hydration_sync:$userId');

    // 1. Listen for Hydration Logs
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'hydration_logs',
      callback: (payload) async {
        debugPrint("Realtime Hydration Log Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          try {
            final log = HydrationLog.fromMap(payload.newRecord);
            await _localRepo!.insertLog(log);
            
            final index = _logs.indexWhere((l) => l.id == log.id);
            if (index != -1) {
              _logs[index] = log;
            } else {
              _logs.insert(0, log);
              _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            }
            notifyListeners();
          } catch (e) {
            debugPrint("Error parsing Realtime Hydration Log: $e");
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteLog(id);
            _logs.removeWhere((l) => l.id == id);
            notifyListeners();
          }
        }
      },
    );

    // 2. Listen for Hydration Settings
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'hydration_settings',
      callback: (payload) async {
        debugPrint("Realtime Hydration Settings Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final newSettings = HydrationSettings.fromMap(payload.newRecord);
          _settings = newSettings;
          await _localRepo!.saveSettings(newSettings);
          _notificationService.scheduleHydrationReminders(newSettings);
          notifyListeners();
        }
      },
    );

    _realtimeChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("HydrationProvider: Realtime Subscribed/Reconnected. Syncing...");
        await _syncLocalToCloud();
        await _loadData(silent: true);
      }
      if (error != null) {
        debugPrint("Realtime Hydration Error: $error");
      }
    });
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
        try {
          if (table == 'hydration_logs') await _cloudRepo.deleteLog(id);
          await _localRepo!.removeFromDeletionQueue(id);
          syncProv.incrementCompleted();
        } catch (_) {}
      }

      // 2. Push Unsynced Logs
      final unsyncedLogs = await _localRepo!.getUnsyncedLogs();
      for (var log in unsyncedLogs) {
        try {
          await _cloudRepo.insertLog(log);
          await _localRepo!.markLogSynced(log.id);
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
      notifyListeners();

      final cloudSettings = await _cloudRepo.getSettings();
      if (cloudSettings != null) {
        await _localRepo!.saveSettings(cloudSettings, isFromCloud: true);
        _settings = await _localRepo!.getSettings();
      }

      final cloudLogs = await _cloudRepo.getAllLogs();
      if (cloudLogs != null) {
        final localLogs = await _localRepo!.getAllLogs();
        final cloudIds = cloudLogs.map((l) => l.id).toSet();

        // Deletion Reconciliation: Remove local synced logs missing from cloud
        for (var localL in localLogs) {
          if (localL.isSynced == 1 && !cloudIds.contains(localL.id)) {
            await _localRepo!.deleteLog(localL.id);
          }
        }

        bool logChanged = false;

        // 2. Add/Update logs from cloud
        for (var log in cloudLogs) {
          await _localRepo!.insertLog(log, isFromCloud: true);
          logChanged = true;
        }
        if (logChanged) _logs = await _localRepo!.getAllLogs();
      }
      
      _notificationService.scheduleHydrationReminders(_settings);

    } catch (e) {
      debugPrint("Error loading/syncing hydration data: $e");
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
      debugPrint("HydrationProvider: FORCE REFRESH TRIGGERED");
      await _syncLocalToCloud();
      await _loadData(silent: true);
      debugPrint("HydrationProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("HydrationProvider: Force Refresh Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addWater(int amountInMl, {DateTime? timestamp}) async {
    if (_localRepo == null) return;
    
    final targetDate = timestamp ?? DateTime.now();
    
    if (amountInMl < 0) {
      int toDeduct = amountInMl.abs();
      
      // Filter logs for the target day, sorted by timestamp DESC (latest first)
      final dayLogs = _logs.where((log) =>
          log.timestamp.year == targetDate.year &&
          log.timestamp.month == targetDate.month &&
          log.timestamp.day == targetDate.day &&
          log.amountMl > 0
      ).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      for (var log in dayLogs) {
        if (toDeduct <= 0) break;
        
        if (log.amountMl <= toDeduct) {
          toDeduct -= log.amountMl;
          await deleteLog(log.id);
        } else {
          final int newMl = log.amountMl - toDeduct;
          final updatedLog = log.copyWith(
            amountMl: newMl,
            amountOz: newMl * mlToOzFactor,
            isSynced: 0,
          );
          toDeduct = 0;
          
          final idx = _logs.indexWhere((l) => l.id == log.id);
          if (idx != -1) {
            _logs[idx] = updatedLog;
            notifyListeners();
          }
          
          try {
            await _localRepo!.insertLog(updatedLog);
            await _syncSingleHydrationLog(updatedLog);
          } catch (e) {
            debugPrint("Error updating hydration log locally: $e");
          }
        }
      }
      return;
    }

    if (amountInMl == 0) return;

    final log = HydrationLog(
      id: const Uuid().v4(),
      amountMl: amountInMl,
      amountOz: amountInMl * mlToOzFactor,
      timestamp: targetDate,
      isSynced: 0,
      updatedAt: DateTime.now(),
    );

    _logs.insert(0, log);
    _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();

    try {
      await _localRepo!.insertLog(log);
      await _syncSingleHydrationLog(log);
    } catch (e) {
      debugPrint("Error saving hydration log locally: $e");
    }
  }

  Future<void> _syncSingleHydrationLog(HydrationLog log) async {
    try {
      await _cloudRepo.insertLog(log);
      await _localRepo!.markLogSynced(log.id);
      final idx = _logs.indexWhere((l) => l.id == log.id);
      if (idx != -1) {
        _logs[idx] = log.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Hydration Add): $e");
    }
  }

  Future<void> deleteLog(String id) async {
    if (_localRepo == null) return;

    _logs.removeWhere((log) => log.id == id);
    notifyListeners();

    try {
      await _localRepo!.deleteLog(id);
      await _localRepo!.addToDeletionQueue(id, 'hydration_logs');
      _syncDeleteHydration(id);
    } catch (e) {
      debugPrint("Error deleting hydration log locally: $e");
    }
  }

  Future<void> _syncDeleteHydration(String id) async {
    try {
      await _cloudRepo.deleteLog(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Hydration Delete): $e");
    }
  }

  Future<void> updateSettings(HydrationSettings newSettings) async {
    if (_localRepo == null) return;

    // Validation for reminders
    List<HydrationReminder> validatedReminders = [];
    for (var r in newSettings.reminders) {
      if (r.mode == HydrationReminderMode.schedule) {
        // If days picked but no times, set current time
        if (r.days.isNotEmpty && r.times.isEmpty) {
          validatedReminders.add(r.copyWith(times: [TimeOfDay.now()]));
        } else {
          validatedReminders.add(r);
        }
      } else {
        // Interval mode
        validatedReminders.add(r);
      }
    }

    final localSettings = newSettings.copyWith(
      reminders: validatedReminders, 
      isSynced: 0,
      updatedAt: DateTime.now(),
    );
    _settings = localSettings;
    notifyListeners();

    try {
      await _localRepo!.saveSettings(localSettings);
      await _syncHydrationSettings(localSettings);
      _notificationService.scheduleHydrationReminders(_settings);
    } catch (e) {
      debugPrint("Error saving hydration settings locally: $e");
    }
  }

  Future<void> _syncHydrationSettings(HydrationSettings settings) async {
    try {
      await _cloudRepo.saveSettings(settings);
      await _localRepo!.markSettingsSynced();
      if (_settings.isSynced == 0) {
        _settings = _settings.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Hydration Settings): $e");
    }
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _logs.clear();
    _settings = HydrationSettings();
    _localRepo = null;
    notifyListeners();
  }

  // Helper conversion methods
  double mlToOz(int ml) => ml * mlToOzFactor;
  int ozToMl(double oz) => (oz / mlToOzFactor).round();

  String formatAmount(int ml) {
    if (_settings.unit == HydrationUnit.ml) {
      return "$ml ML";
    } else {
      return "${mlToOz(ml).toStringAsFixed(1)} OZ";
    }
  }
}
