// lib/features/tracker/sleep/provider/sleep_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/services/connectivity_service.dart';
import '../data/sleep_local_repository.dart';
import '../data/sleep_cloud_repository.dart';
import '../model/sleep_log.dart';
import '../model/sleep_settings.dart';

import 'package:rugged/core/providers/sync_provider.dart';

class SleepProvider with ChangeNotifier {
  SleepLocalRepository? _localRepo;
  SleepCloudRepository _cloudRepo = SleepCloudRepository();
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  void setRepositories({SleepLocalRepository? local, SleepCloudRepository? cloud}) {
    if (local != null) _localRepo = local;
    if (cloud != null) _cloudRepo = cloud;
  }

  List<SleepLog> _logs = [];
  SleepSettings _settings = SleepSettings(userId: '');
  bool _isLoading = false;

  List<SleepLog> get logs => _logs;
  SleepSettings get settings => _settings;
  bool get isLoading => _isLoading;

  void initializeForUser(String userId) {
    _localRepo = SleepLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    debugPrint("SleepProvider: Reconnected. Triggering sync...");
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscription(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:sleep_sync:$userId');

    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sleep_logs',
      callback: (payload) async {
        debugPrint("Realtime Sleep Log Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final log = SleepLog.fromMap(payload.newRecord);
          await _localRepo!.insertLog(log);
          
          final index = _logs.indexWhere((l) => l.id == log.id);
          if (index != -1) {
            _logs[index] = log;
          } else {
            _logs.insert(0, log);
            _logs.sort((a, b) => b.bedtime.compareTo(a.bedtime));
          }
          notifyListeners();
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

    // 2. Listen for Sleep Settings
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sleep_settings',
      callback: (payload) async {
        debugPrint("Realtime Sleep Settings Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final newSettings = SleepSettings.fromMap(payload.newRecord);
          if (_settings.isSynced == 1) {
            _settings = newSettings;
            await _localRepo!.saveSettings(newSettings);
            notifyListeners();
          }
        }
      },
    );

    _realtimeChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("SleepProvider: Realtime Subscribed/Reconnected. Syncing...");
        await _syncLocalToCloud();
        await _loadData(silent: true);
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
        try {
          await _cloudRepo.deleteLog(id);
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
      final currentSettings = await _localRepo!.getSettings();
      if (currentSettings != null && currentSettings.isSynced == 0) {
        try {
          await _cloudRepo.saveSettings(currentSettings);
          await _localRepo!.saveSettings(currentSettings.copyWith(isSynced: 1));
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

      _logs = await _localRepo!.getAllLogs();
      _settings = await _localRepo!.getSettings() ?? SleepSettings(userId: _localRepo!.userId);
      notifyListeners();

      // 2. Fetch remote settings
      try {
        final cloudSettings = await _cloudRepo.getSettings();
        if (cloudSettings != null) {
          await _localRepo!.saveSettings(cloudSettings, isFromCloud: true);
          _settings = await _localRepo!.getSettings() ?? _settings;
        }
      } catch (e) {
        debugPrint("SleepProvider: Settings sync failed: $e");
      }

      // 3. Fetch and Add/Update Logs
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
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading sleep data: $e");
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
      debugPrint("SleepProvider: FORCE REFRESH TRIGGERED");
      await _syncLocalToCloud();
      await _loadData(silent: true);
      debugPrint("SleepProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("SleepProvider: Force Refresh Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSleepLog(SleepLog log) async {
    if (_localRepo == null) return;
    final localLog = log.copyWith(
      isSynced: 0,
      updatedAt: DateTime.now(),
    );

    _logs.insert(0, localLog);
    _logs.sort((a, b) => b.bedtime.compareTo(a.bedtime));
    notifyListeners();

    try {
      await _localRepo!.insertLog(localLog);
      await _cloudRepo.insertLog(localLog);
      await _localRepo!.markLogSynced(localLog.id);
      final idx = _logs.indexWhere((l) => l.id == localLog.id);
      if (idx != -1) {
        _logs[idx] = localLog.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error saving sleep log: $e");
    }
  }

  Future<void> deleteLog(String id) async {
    if (_localRepo == null) return;

    _logs.removeWhere((l) => l.id == id);
    notifyListeners();

    try {
      await _localRepo!.deleteLog(id);
      await _localRepo!.addToDeletionQueue(id, 'sleep_logs');
      await _cloudRepo.deleteLog(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Error deleting sleep log: $e");
    }
  }

  Future<void> updateSettings(SleepSettings settings) async {
    if (_localRepo == null) return;
    final localSettings = settings.copyWith(
      isSynced: 0,
      updatedAt: DateTime.now(),
    );
    _settings = localSettings;
    notifyListeners();

    try {
      await _localRepo!.saveSettings(localSettings);
      await _cloudRepo.saveSettings(localSettings);
      await _localRepo!.saveSettings(localSettings.copyWith(isSynced: 1));
      _settings = _settings.copyWith(isSynced: 1);
      notifyListeners();
    } catch (e) {
      debugPrint("Error saving sleep settings: $e");
    }
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _logs.clear();
    _localRepo = null;
    notifyListeners();
  }

  Duration get averageDuration {
    if (_logs.isEmpty) return Duration.zero;
    final total = _logs.fold(Duration.zero, (prev, log) => prev + log.duration);
    return Duration(minutes: total.inMinutes ~/ _logs.length);
  }

  int get averageQuality {
    if (_logs.isEmpty) return 0;
    final total = _logs.fold(0, (prev, log) => prev + log.quality);
    return total ~/ _logs.length;
  }

  SleepLog? findOverlap(DateTime start, DateTime end) {
    for (var log in _logs) {
      // Logic: new range overlaps existing range if NOT (newEnd <= existingStart OR newStart >= existingEnd)
      if (!(end.isBefore(log.bedtime) || end.isAtSameMomentAs(log.bedtime) || 
            start.isAfter(log.wakeUpTime) || start.isAtSameMomentAs(log.wakeUpTime))) {
        return log;
      }
    }
    return null;
  }
}
