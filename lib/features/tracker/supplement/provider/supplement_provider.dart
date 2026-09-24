// lib/features/tracker/supplement/provider/supplement_provider.dart

import 'package:flutter/material.dart';
import 'package:rugged/core/theme/app_colors.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_settings.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_stack.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/providers/sync_provider.dart';

import 'package:uuid/uuid.dart';
import '../../../../core/services/notification_service.dart';
import '../data/supplement_local_repository.dart';
import '../data/supplement_cloud_repository.dart';
import '../model/supplement.dart';
import '../model/supplement_item.dart';

// Helper class to represent stock predictions
class StockPrediction {
  final String dateString;
  final int daysRemaining;
  StockPrediction(this.dateString, this.daysRemaining);
}

class SupplementProvider with ChangeNotifier {
  // Dual-storage persistence pipeline configurations
  SupplementLocalRepository? _localRepo;
  SupplementCloudRepository _cloudRepo = SupplementCloudRepository();
  NotificationService _notificationService = NotificationService();
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  void setRepositories({SupplementLocalRepository? local, SupplementCloudRepository? cloud, NotificationService? notifications}) {
    if (local != null) _localRepo = local;
    if (cloud != null) _cloudRepo = cloud;
    if (notifications != null) _notificationService = notifications;
  }

  // Helper for integration tests to simulate state
  void setLibraryForTest(List<Supplement> items) {
    _library.clear();
    _library.addAll(items);
  }

  void setStacksForTest(List<SupplementStack> stacks) {
    _supplementStacks.clear();
    _supplementStacks.addAll(stacks);
  }

  SupplementProvider() {
    // No longer listening to notification actions for interventions
  }

  final List<Supplement> _library = [];
  final List<SupplementItem> _history = [];
  final List<SupplementStack> _supplementStacks = [];
  SupplementSettings _settings = SupplementSettings();

  String _searchQuery = "";
  String _historyCategory = "ALL";

  List<Supplement> get library => _library;
  List<SupplementStack> get supplementStacks => _supplementStacks;
  SupplementSettings get settings => _settings;

  void initializeForUser(String userId) {
    _localRepo = SupplementLocalRepository(userId: userId);
    loadFromDatabase();
    _setupRealtimeSubscription(userId);
  }

  void _setupRealtimeSubscription(String userId) {
    if (!AuthProvider().isPro) return;
    // Clean up existing channel if any
    _realtimeChannel?.unsubscribe();

    _realtimeChannel = _supabase.channel('public:supplement_sync:$userId');

    // 1. Listen for Supplement changes (ss_supplements)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ss_supplements',
      callback: (payload) async {
        debugPrint("Realtime Supplement Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          try {
            final supplement = Supplement.fromMap(payload.newRecord);
            await _localRepo!.saveSupplement(supplement);
            
            final index = _library.indexWhere((s) => s.id == supplement.id);
            if (index != -1) {
              _library[index] = supplement;
            } else {
              _library.add(supplement);
            }
            notifyListeners();
          } catch (e) {
            debugPrint("Error parsing Realtime Supplement: $e");
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteSupplement(id);
            _library.removeWhere((s) => s.id == id);
            notifyListeners();
          }
        }
      },
    );

    // 2. Listen for Stack changes (ss_stack)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ss_stack',
      callback: (payload) async {
        debugPrint("Realtime Stack Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          // Stacks need re-mapping with library items
          final updatedStacks = await _cloudRepo.getAllStacks(_library);
          if (updatedStacks != null) {
            _supplementStacks.clear();
            _supplementStacks.addAll(updatedStacks);
            
            for (var stack in updatedStacks) {
              await _localRepo!.saveStack(stack);
            }
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteStack(id);
            _supplementStacks.removeWhere((s) => s.id == id);
            notifyListeners();
          }
        }
      },
    );

    // 3. Listen for History changes (ss_records)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'ss_records',
      callback: (payload) async {
        debugPrint("Realtime History Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final entry = SupplementItem.fromMap(payload.newRecord);
          entry.isSynced = 1;
          await _localRepo!.insertSupplementItem(entry);
          
          final index = _history.indexWhere((h) => h.id == entry.id);
          if (index != -1) {
            _history[index] = entry;
          } else {
            _history.insert(0, entry);
          }
          notifyListeners();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteSupplementItem(id);
            _history.removeWhere((h) => h.id == id);
            notifyListeners();
          }
        }
      },
    );

    _realtimeChannel!.subscribe((status, error) {
      debugPrint("Realtime Supplement Channel Status: $status");
      if (error != null) {
        debugPrint("Realtime Supplement Error: $error");
      }
    });
  }

  // Clear data and disconnect repository upon logout
  void clearUserData() {
    _realtimeChannel?.unsubscribe();
    _library.clear();
    _history.clear();
    _supplementStacks.clear();
    _localRepo = null;
    notifyListeners();
  }

  List<Supplement> get activeSupplements {
    final now = DateTime.now();
    return _library.where((item) {
      if (!item.isActive) return false;
      if (!_settings.showExpired && item.expiryDate != null && item.expiryDate!.isBefore(now)) return false;
      if (_settings.hideEmptyStock && (item.remainingStock ?? 0) <= 0) return false;
      return true;
    }).toList();
  }

  List<Supplement> get pinnedSupplements {
    final items = _library.where((item) {
      if (!item.isActive || !item.isPinnedToHome) return false;
      if (_settings.hideEmptyStock && (item.remainingStock ?? 0) <= 0) return false;
      return true;
    }).toList();
    
    if (_settings.pinnedOrder.isEmpty) return items;

    // Sort according to pinnedOrder
    items.sort((a, b) {
      final idxA = _settings.pinnedOrder.indexOf(a.id);
      final idxB = _settings.pinnedOrder.indexOf(b.id);
      if (idxA == -1 && idxB == -1) return 0;
      if (idxA == -1) return 1;
      if (idxB == -1) return -1;
      return idxA.compareTo(idxB);
    });
    return items;
  }

  // Expose stacks that have been pinned for home quick-log
  List<SupplementStack> get pinnedStacks {
    final stacks = _supplementStacks.where((s) => s.isPinnedToHome).where((s) {
      if (!_settings.hideEmptyStock) return true;
      // Hide stack if any item is empty
      return s.items.every((item) {
        final libItem = _library.firstWhereOrNull((l) => l.id == item.id);
        return (libItem?.remainingStock ?? 0) > 0;
      });
    }).toList();

    if (_settings.pinnedOrder.isEmpty) return stacks;

    stacks.sort((a, b) {
      final idxA = _settings.pinnedOrder.indexOf(a.id);
      final idxB = _settings.pinnedOrder.indexOf(b.id);
      if (idxA == -1 && idxB == -1) return 0;
      if (idxA == -1) return 1;
      if (idxB == -1) return -1;
      return idxA.compareTo(idxB);
    });
    return stacks;
  }

  List<SupplementItem> get history => _history;

  List<SupplementItem> get filteredHistory {
    final List<SupplementItem> filtered = _history.where((entry) {
      final matchesSearch = entry.supplementName.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      bool matchesCategory = true;
      if (_historyCategory == "INTAKE") {
        matchesCategory = entry.type == "Intake";
      }
      if (_historyCategory == "RESTOCK") {
        matchesCategory = entry.type == "Restock";
      }

      if (_settings.hideEmptyStock) {
        final supp = _library.firstWhere((s) => s.id == entry.supplementId, orElse: () => null as dynamic);
        if ((supp.remainingStock ?? 0) <= 0) return false;
      }

      return matchesSearch && matchesCategory;
    }).toList();

    // Ensure we return most recent first
    filtered.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return filtered;
  }

  // ==========================================
  // CORE DATABASE LIFECYCLE INITIALIZER (REPAIRED & SYNC OPTIMIZED)
  // ==========================================

  /// Call this method in main.dart to load data instantly from local cache, then sync safely.
  Future<void> loadFromDatabase() async {
    try {
      // 0. Load Settings
      final localSettings = await _localRepo!.getSettings();
      if (localSettings != null) {
        _settings = localSettings;
      }

      // 1. Fetch data from local SQLite database storage partition instantly
      final localSupps = await _localRepo!.getAllSupplements();
      _library.clear();
      _library.addAll(localSupps);

      // Fetch all local history logs
      final allLocalHistory = await _localRepo!.getAllHistory();
      _history.clear();
      _history.addAll(allLocalHistory);

      final localStacks = await _localRepo!.getAllStacks(_library);
      _supplementStacks.clear();
      _supplementStacks.addAll(localStacks);

      notifyListeners();

      final syncProv = SyncProvider();
      syncProv.startFeatureSync();

      try {
        final count = await _localRepo!.getUnsyncedCount();
        syncProv.addTotalItems(count);

        // 2. MANDATORY: Push local offline changes BEFORE pulling from cloud
        // This ensures your offline work is the "source of truth."
        
        // 2a. Push Deletions
        final deletions = await _localRepo!.getPendingDeletions();
        for (var del in deletions) {
          final id = del['id'] as String;
          final table = del['table_name'] as String;
          try {
            if (table == 'ss_supplements') await _cloudRepo.deleteSupplement(id);
            if (table == 'ss_stack') await _cloudRepo.deleteStack(id);
            if (table == 'ss_records') await _cloudRepo.deleteSupplementItem(id);
            await _localRepo!.removeFromDeletionQueue(id);
            syncProv.incrementCompleted();
          } catch (_) {}
        }

        final unsyncedLogs = await _localRepo!.getUnsyncedHistory();
        for (var log in unsyncedLogs) {
          try {
            await _cloudRepo.insertSupplementItem(log);
            await _localRepo!.markHistoryAsSynced(log.id);
            // Update in-memory log status
            final index = _history.indexWhere((h) => h.id == log.id);
            if (index != -1) {
              _history[index].isSynced = 1;
            }
            syncProv.incrementCompleted();
          } catch (cloudError) {
            debugPrint("Background log sync failed (still offline): $cloudError");
          }
        }

        // Push Unsynced Supplements
        final unsyncedSupps = await _localRepo!.getUnsyncedSupplements();
        for (var supp in unsyncedSupps) {
          try {
            await _cloudRepo.saveSupplement(supp);
            await _localRepo!.markSupplementSynced(supp.id);
            syncProv.incrementCompleted();
          } catch (_) {}
        }

        // Push Unsynced Stacks
        final unsyncedStacks = await _localRepo!.getUnsyncedStacks();
        for (var stack in unsyncedStacks) {
          try {
            await _cloudRepo.saveStack(stack);
            await _localRepo!.markStackSynced(stack.id);
            syncProv.incrementCompleted();
          } catch (_) {}
        }
      } finally {
        syncProv.endFeatureSync();
      }

      // 3. Pull master records from Supabase
      // 3.1 Supplements
      final cloudSupps = await _cloudRepo.getAllSupplements();
      if (cloudSupps != null) {
        final localSuppsCurrent = await _localRepo!.getAllSupplements();
        final cloudIds = cloudSupps.map((s) => s.id).toSet();

        // Deletion Reconciliation: Remove local synced supplements missing from cloud
        for (var localS in localSuppsCurrent) {
          if (localS.isSynced == 1 && !cloudIds.contains(localS.id)) {
            await _localRepo!.deleteSupplement(localS.id);
          }
        }

        for (var cloudSupp in cloudSupps) {
          await _localRepo!.saveSupplement(cloudSupp, isFromCloud: true);
        }
      }

      // 3.2 Stacks
      final cloudStacks = await _cloudRepo.getAllStacks(cloudSupps ?? _library);
      if (cloudStacks != null) {
        final localStacksCurrent = await _localRepo!.getAllStacks(_library);
        final cloudIds = cloudStacks.map((s) => s.id).toSet();

        // Deletion Reconciliation: Remove local synced stacks missing from cloud
        for (var localSt in localStacksCurrent) {
          if (localSt.isSynced == 1 && !cloudIds.contains(localSt.id)) {
            await _localRepo!.deleteStack(localSt.id);
          }
        }

        for (var stack in cloudStacks) {
          await _localRepo!.saveStack(stack, isFromCloud: true);
        }
      }

      // 3.3 History
      final cloudHistory = await _cloudRepo.getAllHistoryEntries();
      if (cloudHistory != null) {
        final localHistoryCurrent = await _localRepo!.getAllHistory();
        final cloudIds = cloudHistory.map((h) => h.id).toSet();

        // Delete local history logs missing from cloud
        for (var localH in localHistoryCurrent) {
          if (localH.isSynced == 1 && !cloudIds.contains(localH.id)) {
            await _localRepo!.deleteSupplementItem(localH.id);
          }
        }

        for (var historyEntry in cloudHistory) {
          await _localRepo!.insertSupplementItem(historyEntry, isFromCloud: true);
        }
      }

      // 3.4 Settings
      final cloudSettings = await _cloudRepo.getSettings();
      if (cloudSettings != null) {
        await _localRepo!.saveSettings(cloudSettings, isFromCloud: true);
        _settings = await _localRepo!.getSettings() ?? _settings;
      }

      // 4. Re-read fresh state mutations back into current provider variable objects
      final updatedSupps = await _localRepo!.getAllSupplements();
      _library.clear();
      _library.addAll(updatedSupps);

      // IMPORTANT: Schedule notifications for all synced supplements
      for (var supp in _library) {
        await _notificationService.scheduleSupplementReminders(supp);
      }

      final updatedStacks = await _localRepo!.getAllStacks(_library);
      _supplementStacks.clear();
      _supplementStacks.addAll(updatedStacks);

      for (var stack in _supplementStacks) {
        await _notificationService.scheduleStackReminders(stack);
      }

      final updatedHistory = await _localRepo!.getAllHistory();
      _history.clear();
      _history.addAll(updatedHistory);

    } catch (e) {
      debugPrint(
        "Offline Sync Status: Fallback active. Serving local files: $e",
      );
    }
    notifyListeners();
  }

  Future<void> forceRefresh() async {
    if (_localRepo == null) return;
    notifyListeners();
    try {
      debugPrint("SupplementProvider: FORCE REFRESH TRIGGERED");
      await loadFromDatabase();
      debugPrint("SupplementProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("SupplementProvider: Force Refresh Error: $e");
    }
  }

  void updateNotificationSettings({
    required String targetId,
    required bool isStack,
    required bool masterEnabled,
    required bool recordEnabled,
    required bool restockEnabled,
    required List<SupplementReminder> intakeReminders,
    required Map<String, double> lowStockThresholds,
  }) async {
    debugPrint("SupplementProvider: updateNotificationSettings called for $targetId");
    
    // 1. Fetch current reminders to preserve what isn't being explicitly updated
    List<SupplementReminder> finalReminders = [];
    
    if (isStack) {
      final idx = _supplementStacks.indexWhere((s) => s.id == targetId);
      if (idx != -1) finalReminders = List.from(_supplementStacks[idx].reminders);
    } else {
      final idx = _library.indexWhere((s) => s.id == targetId);
      if (idx != -1) finalReminders = List.from(_library[idx].reminders);
    }

    // 2. Update Intake Reminders: Clear old ones and only add new ones if enabled
    finalReminders.removeWhere((r) => r.type == ReminderType.intake);
    if (recordEnabled) {
      for (var r in intakeReminders) {
        if (r.days.isNotEmpty && r.times.isEmpty) {
          r.times.add(TimeOfDay.now());
        }
      }
      finalReminders.addAll(intakeReminders);
    }

    // 3. Process Low Stock Alerts: Clear old ones and only add new ones if enabled
    for (var id in lowStockThresholds.keys) {
      finalReminders.removeWhere((r) => r.type == ReminderType.lowStock && r.supplementId == id);
    }

    if (restockEnabled) {
      lowStockThresholds.forEach((id, val) {
        finalReminders.add(
          SupplementReminder(
            days: [],
            times: [],
            value: val,
            type: ReminderType.lowStock,
            supplementId: id,
          ),
        );
      });
    }

    // 4. Routing the update & syncing to Local Storage + Cloud
    if (isStack) {
      final stackIndex = _supplementStacks.indexWhere((s) => s.id == targetId);
      if (stackIndex != -1) {
        _supplementStacks[stackIndex] = _supplementStacks[stackIndex].copyWith(
          reminders: finalReminders,
          notificationsEnabled: masterEnabled,
        );
        
        notifyListeners();
        await _localRepo!.saveStack(_supplementStacks[stackIndex]);
        await _notificationService.scheduleStackReminders(_supplementStacks[stackIndex]);

        // Sync low stock thresholds to individual supplements if applicable
        for (var entry in lowStockThresholds.entries) {
          final suppId = entry.key;
          final threshold = entry.value;
          final suppIndex = _library.indexWhere((s) => s.id == suppId);
          if (suppIndex != -1) {
            final List<SupplementReminder> suppReminders = List.from(_library[suppIndex].reminders);
            suppReminders.removeWhere((r) => r.type == ReminderType.lowStock);
            suppReminders.add(SupplementReminder(days: [], times: [], value: threshold, type: ReminderType.lowStock, supplementId: suppId));
            _library[suppIndex] = _library[suppIndex].copyWith(reminders: suppReminders);
            await _localRepo!.saveSupplement(_library[suppIndex]);
            if ((_library[suppIndex].remainingStock ?? 0.0) <= threshold) {
              _notificationService.showLowStockNotification(_library[suppIndex]);
            }
            try { await _cloudRepo.saveSupplement(_library[suppIndex]); } catch (_) {}
          }
        }

        try { await _cloudRepo.saveStack(_supplementStacks[stackIndex]); } catch (e) { debugPrint("Cloud Stack Sync Error: $e"); }
      }
    } else {
      final suppIndex = _library.indexWhere((s) => s.id == targetId);
      if (suppIndex != -1) {
        _library[suppIndex] = _library[suppIndex].copyWith(
          reminders: finalReminders,
          notificationsEnabled: masterEnabled,
        );
        
        notifyListeners();
        await _localRepo!.saveSupplement(_library[suppIndex]);
        
        if (masterEnabled && restockEnabled) {
          final double currentStock = _library[suppIndex].remainingStock ?? 0.0;
          final lowStockReminder = finalReminders.firstWhere(
            (r) => r.type == ReminderType.lowStock,
            orElse: () => SupplementReminder(days: [], times: [], value: -1, type: ReminderType.lowStock),
          );
          if (lowStockReminder.value >= 0 && currentStock <= lowStockReminder.value) {
            _notificationService.showLowStockNotification(_library[suppIndex]);
          }
        } else if (!masterEnabled) {
          _notificationService.cancelLowStockNotification(targetId);
        }

        await _notificationService.scheduleSupplementReminders(_library[suppIndex]);
        try { await _cloudRepo.saveSupplement(_library[suppIndex]); } catch (e) { debugPrint("Cloud Supplement Sync Error: $e"); }
      }
    }
  }

  // --- SUPPLEMENT MANAGEMENT --- LIBRARY SCREEN OPERATIONS

  void deleteSupplement(String id, {void Function(String id, double cals, double pro, double cho, double fat)? onDeactivated}) async {
    final supplement = _library.firstWhere((s) => s.id == id, orElse: () => null as dynamic);
    if (onDeactivated != null) {
      onDeactivated(
        id, 
        supplement.caloriesPerUnit ?? 0.0, 
        supplement.proteinPerUnit ?? 0.0, 
        supplement.carbsPerUnit ?? 0.0, 
        supplement.fatsPerUnit ?? 0.0
      );
    }

    _library.removeWhere((s) => s.id == id);
    
    // Notify listeners IMMEDIATELY for instant UI feedback
    notifyListeners();

    // Check if any stack becomes disabled and update settings accordingly
    for (int i = 0; i < _supplementStacks.length; i++) {
      final stack = _supplementStacks[i];
      if (stack.items.any((item) => item.id == id)) {
        // Count active supplements remaining in this stack
        final int activeCount = stack.items.where((item) {
          return _library.any((s) => s.id == item.id && s.isActive);
        }).length;

        if (activeCount < 2) {
          _supplementStacks[i] = stack.copyWith(
            isPinnedToHome: false,
            notificationsEnabled: false,
          );
          await _localRepo!.saveStack(_supplementStacks[i]);
          await _notificationService.cancelSupplementReminders(stack.id, cancelLowStock: true);
          try {
            await _cloudRepo.saveStack(_supplementStacks[i]);
          } catch (_) {}
        }
      }
    }

    await _localRepo!.deleteSupplement(id);
    await _localRepo!.addToDeletionQueue(id, 'ss_supplements');
    await _notificationService.cancelSupplementReminders(id, cancelLowStock: true);
    await _syncSupplementDelete(id);
    notifyListeners();
  }

  Future<void> _syncSupplementDelete(String id) async {
    try {
      await _cloudRepo.deleteSupplement(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Supplement Delete): $e");
    }
  }

  void addOrUpdateSupplement(Supplement item, {int? index}) async {
    final now = DateTime.now();
    final updatedItem = item.copyWith(
      isSynced: 0,
      updatedAt: now,
    );

    if (index != null) {
      _library[index] = updatedItem;
    } else {
      _library.add(updatedItem);
    }
    
    // Notify listeners IMMEDIATELY for instant UI feedback
    notifyListeners();

    await _localRepo!.saveSupplement(updatedItem);
    await _notificationService.scheduleSupplementReminders(updatedItem);
    try {
      await _cloudRepo.saveSupplement(updatedItem);
      await _localRepo!.markSupplementSynced(updatedItem.id);
      final idx = _library.indexWhere((s) => s.id == updatedItem.id);
      if (idx != -1) {
        _library[idx] = updatedItem.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Cloud Save Error: $e");
    }
  }

  void toggleSupplementStatus(int index, bool status, {void Function(String id, double cals, double pro, double cho, double fat)? onDeactivated}) async {
    final item = _library[index];
    _library[index] = item.copyWith(isActive: status);
    
    // If deactivating, trigger removal from meals
    if (!status && onDeactivated != null) {
      onDeactivated(
        item.id, 
        item.caloriesPerUnit ?? 0.0, 
        item.proteinPerUnit ?? 0.0, 
        item.carbsPerUnit ?? 0.0, 
        item.fatsPerUnit ?? 0.0
      );
    }

    // Notify listeners IMMEDIATELY to make the UI feel instant
    notifyListeners();

    // Perform background operations
    // If deactivating, check if any stacks become disabled
    if (!status) {
      for (int i = 0; i < _supplementStacks.length; i++) {
        final stack = _supplementStacks[i];
        if (stack.items.any((s) => s.id == item.id)) {
          final int activeCount = stack.items.where((s) {
            return _library.any((libItem) => libItem.id == s.id && libItem.isActive);
          }).length;

          if (activeCount < 2) {
            _supplementStacks[i] = stack.copyWith(
              isPinnedToHome: false,
              notificationsEnabled: false,
            );
            await _localRepo!.saveStack(_supplementStacks[i]);
            await _notificationService.cancelSupplementReminders(stack.id, cancelLowStock: true);
            try {
              await _cloudRepo.saveStack(_supplementStacks[i]);
            } catch (_) {}
          }
        }
      }
    }

    await _localRepo!.saveSupplement(_library[index]);
    await _notificationService.scheduleSupplementReminders(_library[index]);
    try {
      await _cloudRepo.saveSupplement(_library[index]);
    } catch (e) {
      debugPrint("Cloud Toggle Error: $e");
    }
    
    // Final notification in case any stacks were modified in the background
    notifyListeners();
  }

  void updateReminders(
    String id,
    List<SupplementReminder> reminders,
    bool enabled,
  ) async {
    final index = _library.indexWhere((s) => s.id == id);
    if (index != -1) {
      final item = _library[index];
      _library[index] = item.copyWith(
        notificationsEnabled: enabled,
        reminders: reminders,
      );

      await _localRepo!.saveSupplement(_library[index]);
      await _notificationService.scheduleSupplementReminders(_library[index]);
      try {
        await _cloudRepo.saveSupplement(_library[index]);
      } catch (_) {}
      notifyListeners();
    }
  }

  void updateShortcutSettings({
    required String id,
    required bool isPinned,
    required double intakeAmount,
    required bool useServingsIntake,
    required double restockAmount,
    required bool useServingsRestock,
  }) async {
    final index = _library.indexWhere((s) => s.id == id);
    if (index != -1) {
      _library[index] = _library[index].copyWith(
        isPinnedToHome: isPinned,
        pinnedIntakeAmount: intakeAmount,
        pinnedUseServingsIntake: useServingsIntake,
        pinnedRestockAmount: restockAmount,
        pinnedUseServingsRestock: useServingsRestock,
      );
      
      // Update pinnedOrder in settings
      List<String> newOrder = List.from(_settings.pinnedOrder);
      if (isPinned) {
        if (!newOrder.contains(id)) newOrder.add(id);
      } else {
        newOrder.remove(id);
      }
      _settings = _settings.copyWith(pinnedOrder: newOrder, isSynced: 0);

      // Notify listeners IMMEDIATELY for instant UI feedback
      notifyListeners();

      await _localRepo!.saveSupplement(_library[index]);
      await _localRepo!.saveSettings(_settings);
      await _notificationService.scheduleSupplementReminders(_library[index]);
      try {
        await _cloudRepo.saveSupplement(_library[index]);
        _syncSettings(_settings);
      } catch (_) {}
    }
  }

  // --- STACK MANAGEMENT METHODS --- STACK SCREEN OPERATIONS

  void toggleStackPin(String stackId) async {
    final index = _supplementStacks.indexWhere((s) => s.id == stackId);
    if (index != -1) {
      _supplementStacks[index] = _supplementStacks[index].copyWith(
        isPinned: !_supplementStacks[index].isPinned,
      );
      _supplementStacks.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return 0;
      });
      
      // Notify listeners IMMEDIATELY for instant UI feedback
      notifyListeners();

      await _localRepo!.saveStack(_supplementStacks[index]);
    }
  }

  void toggleStackNotifications(String stackId) async {
    final index = _supplementStacks.indexWhere((s) => s.id == stackId);
    if (index != -1) {
      _supplementStacks[index] = _supplementStacks[index].copyWith(
        notificationsEnabled: !_supplementStacks[index].notificationsEnabled,
      );
      
      // Notify listeners IMMEDIATELY for instant UI feedback
      notifyListeners();

      await _localRepo!.saveStack(_supplementStacks[index]);
    }
  }

  void updateStackNotifications(
    String stackId,
    List<SupplementReminder> reminders,
    bool enabled,
  ) async {
    final index = _supplementStacks.indexWhere((s) => s.id == stackId);
    if (index != -1) {
      _supplementStacks[index] = _supplementStacks[index].copyWith(
        notificationsEnabled: enabled,
        reminders: reminders,
      );

      await _localRepo!.saveStack(_supplementStacks[index]);
      await _notificationService.scheduleStackReminders(_supplementStacks[index]);
      try {
        await _cloudRepo.saveStack(_supplementStacks[index]);
      } catch (_) {}
      notifyListeners();
    }
  }

  Future<void> deleteStack(String stackId, {void Function(String id, double cals, double pro, double cho, double fat)? onDeleted}) async {
    final stack = _supplementStacks.firstWhere((s) => s.id == stackId, orElse: () => null as dynamic);
    if (onDeleted != null) {
      // Calculate stack totals
      double stCals = 0;
      double stPro = 0, stCho = 0, stFat = 0;
      for (var item in stack.items) {
        final amount = stack.pinnedAmounts[item.id] ?? 1.0;
        stCals += ((item.caloriesPerUnit ?? 0.0) * amount);
        stPro += (item.proteinPerUnit ?? 0.0) * amount;
        stCho += (item.carbsPerUnit ?? 0.0) * amount;
        stFat += (item.fatsPerUnit ?? 0.0) * amount;
      }
      onDeleted(stackId, stCals, stPro, stCho, stFat);
    }

    _supplementStacks.removeWhere((s) => s.id == stackId);
    await _localRepo!.deleteStack(stackId);
    await _localRepo!.addToDeletionQueue(stackId, 'ss_stack');
    await _notificationService.cancelSupplementReminders(stackId, cancelLowStock: true);
    await _syncStackDelete(stackId);
    notifyListeners();
  }

  Future<void> _syncStackDelete(String id) async {
    try {
      await _cloudRepo.deleteStack(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Stack Delete): $e");
    }
  }

  void addOrUpdateStack(SupplementStack stack) async {
    final now = DateTime.now();
    final updatedStack = stack.copyWith(
      isSynced: 0,
      updatedAt: now,
    );

    final index = _supplementStacks.indexWhere((s) => s.id == updatedStack.id);
    if (index != -1) {
      _supplementStacks[index] = updatedStack;
    } else {
      _supplementStacks.add(updatedStack);
    }
    
    // Notify listeners IMMEDIATELY for instant UI feedback
    notifyListeners();

    try {
      await _localRepo!.saveStack(updatedStack);
      await _notificationService.scheduleStackReminders(updatedStack);
      try {
        await _cloudRepo.saveStack(updatedStack);
        await _localRepo!.markStackSynced(updatedStack.id);
        final idx = _supplementStacks.indexWhere((s) => s.id == updatedStack.id);
        if (idx != -1) {
          _supplementStacks[idx] = updatedStack.copyWith(isSynced: 1);
          notifyListeners();
        }
      } catch (_) {}

      final dbStacks = await _localRepo!.getAllStacks(_library);
      _supplementStacks.clear();
      _supplementStacks.addAll(dbStacks);
    } catch (e) {
      debugPrint("Database write error: $e");
    }
  }

  void toggleStackHomePin({
    required String stackId,
    required Map<String, bool> recordModes,
    required Map<String, bool> useServings,
    required Map<String, double> amounts,
  }) async {
    final index = _supplementStacks.indexWhere((s) => s.id == stackId);
    if (index != -1) {
      final bool isCurrentlyPinned = _supplementStacks[index].isPinnedToHome;
      final bool newPinnedState = !isCurrentlyPinned;

      _supplementStacks[index] = _supplementStacks[index].copyWith(
        isPinnedToHome: newPinnedState,
        isPinned: newPinnedState,
        pinnedRecordModes: newPinnedState ? recordModes : {},
        pinnedUseServings: newPinnedState ? useServings : {},
        pinnedAmounts: newPinnedState ? amounts : {},
      );

      // Update pinnedOrder in settings
      List<String> newOrder = List.from(_settings.pinnedOrder);
      if (newPinnedState) {
        if (!newOrder.contains(stackId)) newOrder.add(stackId);
      } else {
        newOrder.remove(stackId);
      }
      _settings = _settings.copyWith(pinnedOrder: newOrder, isSynced: 0);

      _supplementStacks.sort((a, b) {
        if (a.isPinnedToHome && !b.isPinnedToHome) return -1;
        if (!a.isPinnedToHome && b.isPinnedToHome) return 1;
        return 0;
      });

      // Notify listeners IMMEDIATELY for instant UI feedback
      notifyListeners();

      await _localRepo!.saveStack(_supplementStacks[index]);
      await _localRepo!.saveSettings(_settings);
      try {
        await _cloudRepo.saveStack(_supplementStacks[index]);
        _syncSettings(_settings);
      } catch (_) {}
    }
  }

  // --- SUPPLEMENT ITEM OPERATION RECORDING ---

  Future<void> recordEntry({
    required Supplement supplement,
    required bool isIntake,
    required bool isRestock,
    required double weightAdjustment,
    required String historyDetails,
    required DateTime timestamp,
    String? sourceId,
  }) async {
    double updatedStock = (supplement.remainingStock ?? 0) + weightAdjustment;

    // Strict Discipline: Prevent negative stock for intakes
    if (isIntake && updatedStock < -0.0001) {
      debugPrint("SupplementProvider: Aborting intake for ${supplement.name} due to insufficient stock.");
      return;
    }

    final entry = SupplementItem(
      id: const Uuid().v4(),
      supplementId: supplement.id,
      supplementName: supplement.name,
      type: isIntake ? "Intake" : "Restock",
      details: historyDetails,
      weightAdjustment: weightAdjustment,
      timestamp: timestamp,
      sourceId: sourceId,
      isSynced: 0,
      updatedAt: DateTime.now(),
    );

    // 1. Commit to in-memory state and notify listeners IMMEDIATELY to keep UI responsive
    final suppIndex = _library.indexWhere((s) => s.id == supplement.id);
    if (suppIndex != -1) {
      _library[suppIndex] = _library[suppIndex].copyWith(
        remainingStock: () => updatedStock,
        isSynced: 0,
        updatedAt: DateTime.now(),
      );
    }
    
    // Also update history in-memory
    _history.insert(0, entry);
    notifyListeners();

    bool localSuccess = false;
    try {
      // 2. Commit to Local SQLite partition
      await _localRepo!.insertSupplementItem(entry);
      await _localRepo!.updateSupplementStock(supplement.id, updatedStock);
      localSuccess = true;

      // Check if low stock notifications are enabled (exists in reminders)
      if (suppIndex != -1) {
        final currentSupp = _library[suppIndex];
        final int lowStockIndex = currentSupp.reminders.indexWhere(
          (r) => r.type == ReminderType.lowStock,
        );

        if (lowStockIndex != -1) {
          final lowStockReminder = currentSupp.reminders[lowStockIndex];
          if (updatedStock <= (lowStockReminder.value + 0.001)) {
            _notificationService.showLowStockNotification(currentSupp);
          } else if (isRestock) {
            _notificationService.cancelLowStockNotification(supplement.id);
          }
        }
      }
    } catch (e) {
      debugPrint("SupplementProvider: Local recordEntry failure: $e");
    }

    if (localSuccess) {
      try {
        // 3. Transmit operation remotely to cloud backend tables
        await _cloudRepo.insertSupplementItem(entry);
        await _cloudRepo.updateSupplementStock(supplement.id, updatedStock);

        await _localRepo!.markHistoryAsSynced(entry.id);
        entry.isSynced = 1;
        // No need to notify again as UI already has the entry, but update it in memory if needed
        final idx = _history.indexWhere((e) => e.id == entry.id);
        if (idx != -1) _history[idx].isSynced = 1;
        
        debugPrint("SupplementProvider: Cloud recordEntry success for ${supplement.name}");
      } catch (e) {
        debugPrint(
          "SupplementProvider: Cloud sync queued/failed for ${supplement.name}: $e",
        );
      }
    }
  }

  Future<void> removeSupplementItem(String id, {void Function(String sourceId, String supplementId, double amount)? onSourceRollback}) async {
    SupplementItem? entryToRemove;

    try {
      // 1. Locate and run inversion mathematical updates inside local device files
      final entryIndex = _history.indexWhere((e) => e.id == id);
      if (entryIndex == -1) {
        debugPrint("Could not find log entry with ID: $id");
        return;
      }
      entryToRemove = _history[entryIndex];

      // TRIGGER SOURCE ROLLBACK IF CALLBACK PROVIDED
      if (entryToRemove.sourceId != null && onSourceRollback != null) {
        // Extract amount from details "MEAL LOG: NAME | [OPTIONAL CATEGORY] | 1.0 UNIT"
        final detailParts = entryToRemove.details.split('|');
        double amount = 1.0;
        
        // Look at the last part for the numeric value
        if (detailParts.isNotEmpty) {
          final lastPart = detailParts.last.trim();
          final numericMatch = RegExp(r"(\d+\.?\d*)").firstMatch(lastPart);
          if (numericMatch != null) {
            amount = double.tryParse(numericMatch.group(1)!) ?? 1.0;
          }
        }

        onSourceRollback(entryToRemove.sourceId!, entryToRemove.supplementId, amount);
      }

      final suppIndex = _library.indexWhere(
        (s) => s.id == entryToRemove!.supplementId,
      );

      if (suppIndex != -1) {
        final currentSupplement = _library[suppIndex];
        final currentStock = currentSupplement.remainingStock ?? 0.0;
        final reversedStock = currentStock - entryToRemove.weightAdjustment;

        _library[suppIndex] = currentSupplement.copyWith(
          remainingStock: () => reversedStock,
        );
      }

      _history.removeAt(entryIndex);
      
      // Notify listeners IMMEDIATELY for instant UI feedback
      notifyListeners();

      if (suppIndex != -1) {
        final currentSupplement = _library[suppIndex];
        await _localRepo!.updateSupplementStock(
          entryToRemove.supplementId,
          currentSupplement.remainingStock ?? 0.0,
        );
      }

      await _localRepo!.deleteSupplementItem(id);
      await _localRepo!.addToDeletionQueue(id, 'ss_records');
    } catch (e) {
      debugPrint("Local data remediation process failed: $e");
    }

    // 2. Synchronize removal parameters securely up to active cloud service
    if (entryToRemove != null) {
      try {
        final currentSupplement = _library.firstWhere(
          (s) => s.id == entryToRemove!.supplementId,
        );
        await _cloudRepo.updateSupplementStock(
          entryToRemove.supplementId,
          currentSupplement.remainingStock ?? 0.0,
        );
        await _cloudRepo.deleteSupplementItem(id);
        await _localRepo!.removeFromDeletionQueue(id);
      } catch (e) {
        debugPrint("Cloud storage deletion tracking sync failure context: $e");
      }
    }
  }

  // --- QUICK LOGGING METHODS ---

  void quickLog(String id) {
    final index = _library.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final item = _library[index];
    final now = DateTime.now();

    double weightToRemove = item.pinnedUseServingsIntake
        ? (item.pinnedIntakeAmount * item.weightPerServing)
        : item.pinnedIntakeAmount;

    recordEntry(
      supplement: item,
      isIntake: true,
      isRestock: false,
      weightAdjustment: -weightToRemove,
      historyDetails:
          "QUICK LOG: ${item.pinnedIntakeAmount} ${item.pinnedUseServingsIntake ? item.servingUnit : item.weightUnit}",
      timestamp: now,
    );

    double weightToAdd = item.pinnedUseServingsRestock
        ? (item.pinnedRestockAmount * item.weightPerServing)
        : item.pinnedRestockAmount;

    recordEntry(
      supplement: item,
      isIntake: false,
      isRestock: true,
      weightAdjustment: weightToAdd,
      historyDetails:
          "QUICK RESTOCK: ${item.pinnedRestockAmount} ${item.pinnedUseServingsRestock ? item.servingUnit : item.weightUnit}",
      timestamp: now.add(const Duration(microseconds: 10)),
    );
  }

  void quickLogIntakeOnly(String id, {double? forcedAmount, bool isNotification = false}) {
    if (!canLogSupplement(id, amount: forcedAmount)) return;
    
    final item = _library.firstWhere((s) => s.id == id);
    
    // Use the forced amount from notification if provided, otherwise use pinned settings
    double displayAmount = forcedAmount ?? item.pinnedIntakeAmount;
    
    // Prevent recording 0 or negative values
    if (displayAmount <= 0) return;

    double weight = item.pinnedUseServingsIntake
        ? (displayAmount * item.weightPerServing)
        : displayAmount;
        
    String method = isNotification ? "NOTIFICATION" : "QUICK LOG";
    String unitLabel = item.pinnedUseServingsIntake ? item.servingUnit : item.weightUnit;

    recordEntry(
      supplement: item,
      isIntake: true,
      isRestock: false,
      weightAdjustment: -weight,
      historyDetails:
          "$method: $displayAmount ${unitLabel.toUpperCase()}",
      timestamp: DateTime.now(),
    );
  }

  void quickLogRestockOnly(String id) {
    final item = _library.firstWhere((s) => s.id == id);
    
    // Prevent recording 0 or negative values
    if (item.pinnedRestockAmount <= 0) return;

    double weight = item.pinnedUseServingsRestock
        ? (item.pinnedRestockAmount * item.weightPerServing)
        : item.pinnedRestockAmount;
    recordEntry(
      supplement: item,
      isIntake: false,
      isRestock: true,
      weightAdjustment: weight,
      historyDetails:
          "QUICK RESTOCK: ${item.pinnedRestockAmount} ${item.pinnedUseServingsRestock ? item.servingUnit : item.weightUnit}",
      timestamp: DateTime.now(),
    );
  }

  bool _isStackProcessing = false;
  bool get isStackProcessing => _isStackProcessing;

  void quickLogStack(String stackId, {List<double>? forcedValues, bool isNotification = false}) async {
    if (!canLogStack(stackId) || _isStackProcessing) return;
    
    final index = _supplementStacks.indexWhere((s) => s.id == stackId);
    if (index == -1) return;

    final stack = _supplementStacks[index];
    _isStackProcessing = true;
    
    // 1. Perform ALL in-memory updates first for instant responsiveness
    final List<SupplementItem> newEntries = [];
    final now = DateTime.now();
    String method = isNotification ? "NOTIFICATION STACK" : "STACK LOG";

    for (int i = 0; i < stack.items.length; i++) {
      final stackItem = stack.items[i];
      final libraryItemIndex = _library.indexWhere((s) => s.id == stackItem.id && s.isActive);
      if (libraryItemIndex == -1) continue;
      
      final libraryItem = _library[libraryItemIndex];
      final bool isRecord = stack.pinnedRecordModes[libraryItem.id] ?? true;
      final bool servings = stack.pinnedUseServings[libraryItem.id] ?? true;
      
      double amount = 1.0;
      if (forcedValues != null && i < forcedValues.length) {
        amount = forcedValues[i];
      } else {
        amount = stack.pinnedAmounts[libraryItem.id] ?? 1.0;
      }
      if (amount <= 0) continue;

      double weightAdjustment = servings ? (amount * libraryItem.weightPerServing) : amount;
      double finalAdjustment = isRecord ? -weightAdjustment : weightAdjustment;
      final unitLabel = servings ? libraryItem.servingUnit : libraryItem.weightUnit;

      // Update Library Item in-memory
      _library[libraryItemIndex] = libraryItem.copyWith(
        remainingStock: () => (libraryItem.remainingStock ?? 0) + finalAdjustment
      );

      // Create History Entry
      final entry = SupplementItem(
        id: const Uuid().v4(),
        supplementId: libraryItem.id,
        supplementName: libraryItem.name,
        type: isRecord ? "Intake" : "Restock",
        details: "$method: ${stack.name.toUpperCase()} | $amount ${unitLabel.toUpperCase()}",
        weightAdjustment: finalAdjustment,
        timestamp: now.add(Duration(milliseconds: i)), // slightly different timestamps for order
        isSynced: 0,
      );
      newEntries.add(entry);
    }
    
    // Update History in-memory (most recent first)
    _history.insertAll(0, newEntries.reversed);
    
    // 2. Notify listeners IMMEDIATELY
    notifyListeners();

    // 3. Perform background operations (persistence)
    try {
      for (var entry in newEntries) {
        final libItem = _library.firstWhereOrNull((s) => s.id == entry.supplementId);
        if (libItem == null) continue;

        await _localRepo!.insertSupplementItem(entry);
        await _localRepo!.updateSupplementStock(libItem.id, libItem.remainingStock!);
        
        // Background cloud sync
        _cloudRepo.insertSupplementItem(entry).then((_) {
           _localRepo!.markHistoryAsSynced(entry.id);
           final idx = _history.indexWhere((e) => e.id == entry.id);
           if (idx != -1) {
             _history[idx].isSynced = 1;
             notifyListeners();
           }
        });
        
        _cloudRepo.updateSupplementStock(libItem.id, libItem.remainingStock!).catchError((e) => debugPrint("Cloud stock sync error: $e"));
      }
    } catch (e) {
      debugPrint("Background stack log persistence error: $e");
    } finally {
      _isStackProcessing = false;
      notifyListeners();
    }
  }

  Future<void> deleteLastEntry({void Function(String sourceId, String supplementId, double amount)? onSourceRollback}) async {
    if (_history.isEmpty) return;
    final lastEntry = _history.first;
    await removeSupplementItem(lastEntry.id, onSourceRollback: onSourceRollback);
  }

  void deleteSupplementItem(String id, {void Function(String sourceId, String supplementId, double amount)? onSourceRollback}) async {
    await removeSupplementItem(id, onSourceRollback: onSourceRollback);
  }

  // --- UTILITIES & CALCULATIONS ---

  StockPrediction getStockPrediction(Supplement item) {
    if (item.remainingStock == null || item.remainingStock! <= 0) {
      return StockPrediction("Out of stock", 0);
    }

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final recentLogs = _history
        .where(
          (entry) =>
              entry.supplementId == item.id &&
              entry.timestamp.isAfter(sevenDaysAgo) &&
              entry.type.toLowerCase() != "restock",
        )
        .toList();

    double dailyAverageWeight;
    if (recentLogs.isEmpty) {
      dailyAverageWeight = item.weightPerServing;
    } else {
      double totalWeightInWeek = recentLogs.fold(
        0,
        (sum, entry) => sum + entry.weightAdjustment.abs(),
      );
      dailyAverageWeight = totalWeightInWeek / 7;
    }

    if (dailyAverageWeight <= 0) return StockPrediction("Not in use", 999);

    int daysRemaining = (item.remainingStock! / dailyAverageWeight).floor();
    if (daysRemaining > 365) {
      return StockPrediction("1+ year left", daysRemaining);
    }
    if (daysRemaining == 0) return StockPrediction("Empty today", 0);

    final emptyDate = now.add(Duration(days: daysRemaining));
    return StockPrediction(
      "${emptyDate.day}/${emptyDate.month}/${emptyDate.year}",
      daysRemaining,
    );
  }

  Future<void> executeStackLog({
    required SupplementStack stack,
    required Map<String, bool> recordModes,
    required Map<String, bool> useServings,
    required Map<String, double> amounts,
    required DateTime selectedDateTime,
  }) async {
    if (_isStackProcessing) return;
    _isStackProcessing = true;

    // 1. Perform ALL in-memory updates first for instant responsiveness
    final List<SupplementItem> newEntries = [];
    
    for (int i = 0; i < stack.items.length; i++) {
      final stackItem = stack.items[i];
      final libraryItemIndex = _library.indexWhere((s) => s.id == stackItem.id && s.isActive);
      if (libraryItemIndex == -1) continue;
      
      final libraryItem = _library[libraryItemIndex];
      final bool isRecord = recordModes[libraryItem.id] ?? true;
      final bool servings = useServings[libraryItem.id] ?? true;
      final double amount = amounts[libraryItem.id] ?? 0.0;
      if (amount <= 0) continue;

      double weightAdjustment = servings ? (amount * libraryItem.weightPerServing) : amount;
      double finalAdjustment = isRecord ? -weightAdjustment : weightAdjustment;
      final unitLabel = servings ? libraryItem.servingUnit : libraryItem.weightUnit;

      // Update Library Item in-memory
      _library[libraryItemIndex] = libraryItem.copyWith(
        remainingStock: () => (libraryItem.remainingStock ?? 0) + finalAdjustment
      );

      // Create History Entry
      final entry = SupplementItem(
        id: const Uuid().v4(),
        supplementId: libraryItem.id,
        supplementName: libraryItem.name,
        type: isRecord ? "Intake" : "Restock",
        details: "STACK LOG: ${stack.name.toUpperCase()} | $amount ${unitLabel.toUpperCase()}",
        weightAdjustment: finalAdjustment,
        timestamp: selectedDateTime.add(Duration(milliseconds: i)),
        isSynced: 0,
      );
      newEntries.add(entry);
    }
    
    // Update History in-memory
    _history.insertAll(0, newEntries.reversed);
    
    // 2. Notify listeners IMMEDIATELY
    notifyListeners();

    // 3. Perform background operations
    try {
      for (var entry in newEntries) {
        final libItem = _library.firstWhereOrNull((s) => s.id == entry.supplementId);
        if (libItem == null) continue;

        await _localRepo!.insertSupplementItem(entry);
        await _localRepo!.updateSupplementStock(libItem.id, libItem.remainingStock!);
        
        // Background cloud sync
        _cloudRepo.insertSupplementItem(entry).then((_) {
           _localRepo!.markHistoryAsSynced(entry.id);
           final idx = _history.indexWhere((e) => e.id == entry.id);
           if (idx != -1) {
             _history[idx].isSynced = 1;
             notifyListeners();
           }
        });

        _cloudRepo.updateSupplementStock(libItem.id, libItem.remainingStock!).catchError((e) => debugPrint("Cloud stock sync error: $e"));
      }
    } catch (e) {
      debugPrint("Background execute stack persistence error: $e");
    } finally {
      _isStackProcessing = false;
      notifyListeners();
    }
  }

  String getRemainingServings(Supplement item) {
    if (item.remainingStock == null || item.weightPerServing <= 0) {
      return "0 ${item.servingUnit}";
    }
    double servingsLeft = item.remainingStock! / item.weightPerServing;
    String formattedValue = servingsLeft % 1 == 0
        ? servingsLeft.toInt().toString()
        : servingsLeft.toStringAsFixed(1);
    
    String unit = item.servingUnit;
    if (servingsLeft != 1 && !unit.endsWith('s')) {
      unit = "${unit}s";
    }
    
    return "$formattedValue $unit";
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  String get historyCategory => _historyCategory;
  void setHistoryCategory(String category) {
    _historyCategory = category;
    notifyListeners();
  }

  int getDaysUntilExpiry(DateTime? expiryDate) {
    if (expiryDate == null) return -1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return expiry.difference(today).inDays;
  }

  Color getExpiryColor(DateTime? expiryDate) {
    if (expiryDate == null) return AppColors.textSecondary;
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    if (difference <= 0) return AppColors.crimson;
    if (difference <= 30) return Colors.orange;
    return Colors.green;
  }

  Color getStockColor(Supplement item) {
    final double remaining = item.remainingStock ?? 0;
    final double total = item.totalStock ?? 0;
    if (total <= 0) return AppColors.crimson;
    final double ratio = remaining / total;
    if (ratio <= 0.10) return AppColors.crimson;
    if (ratio <= 0.25) return Colors.orange;
    return Colors.green;
  }

  // --- SHARING METHODS ---

  Future<String?> generateSupplementShareLink(Supplement supplement, String userName) async {
    if (!AuthProvider().isPro) {
      debugPrint("SupplementProvider: Sharing skipped - Pro status required.");
      return null;
    }

    final Map<String, dynamic> shareData = {
      'type': 'supplement',
      'name': supplement.name,
      'description': supplement.description,
      'serving_unit': supplement.servingUnit,
      'weight_per_serving': supplement.weightPerServing,
      'weight_unit': supplement.weightUnit,
      'calories_per_unit': supplement.caloriesPerUnit,
      'protein_per_unit': supplement.proteinPerUnit,
      'carbs_per_unit': supplement.carbsPerUnit,
      'fats_per_unit': supplement.fatsPerUnit,
      'total_stock': supplement.totalStock,
      'remaining_stock': supplement.remainingStock,
      'ingredients': supplement.ingredients.map((i) => {
        'name': i.name,
        'amount': i.amount,
        'unit': i.unit,
      }).toList(),
      'sender': userName,
    };

    try {
      final response = await _supabase.from('shared_data').insert({
        'data': shareData,
      }).select('id').single();

      final shareId = response['id'] as String;
      return "https://affulabs.com/rugged/app/share/supplement?id=$shareId&from=${Uri.encodeComponent(userName)}";
    } catch (e) {
      debugPrint("SupplementProvider: Error sharing supplement: $e");
      return null;
    }
  }

  Future<String?> generateStackShareLink(SupplementStack stack, String userName) async {
    if (!AuthProvider().isPro) {
      debugPrint("SupplementProvider: Sharing skipped - Pro status required.");
      return null;
    }

    final Map<String, dynamic> shareData = {
      'type': 'stack',
      'name': stack.name,
      'sender': userName,
      'items': stack.items.map((s) => {
        'name': s.name,
        'serving_unit': s.servingUnit,
        'weight_per_serving': s.weightPerServing,
        'weight_unit': s.weightUnit,
        'calories_per_unit': s.caloriesPerUnit,
        'protein_per_unit': s.proteinPerUnit,
        'carbs_per_unit': s.carbsPerUnit,
        'fats_per_unit': s.fatsPerUnit,
        'total_stock': s.totalStock,
        'remaining_stock': s.remainingStock,
        'ingredients': s.ingredients.map((i) => {
          'name': i.name,
          'amount': i.amount,
          'unit': i.unit,
        }).toList(),
      }).toList(),
    };

    try {
      final response = await _supabase.from('shared_data').insert({
        'data': shareData,
      }).select('id').single();

      final shareId = response['id'] as String;
      return "https://affulabs.com/rugged/app/share/stack?id=$shareId&from=${Uri.encodeComponent(userName)}";
    } catch (e) {
      debugPrint("SupplementProvider: Error sharing stack: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSharedEntity(String shareId) async {
    try {
      final response = await _supabase.from('shared_data').select().eq('id', shareId).single();
      final createdAt = DateTime.parse(response['created_at']);
      if (DateTime.now().difference(createdAt).inDays >= 7) return {'expired': true};
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint("SupplementProvider: Error fetching shared entity: $e");
      return null;
    }
  }

  Future<void> importSharedSupplement(Map<String, dynamic> data) async {
    final List<SupplementIngredient> ingredients = (data['ingredients'] as List? ?? []).map((i) => SupplementIngredient(
      name: i['name'],
      amount: (i['amount'] as num).toDouble(),
      unit: i['unit'],
    )).toList();

    final supplement = Supplement(
      id: const Uuid().v4(),
      name: (data['name'] as String).toUpperCase(),
      description: data['description'] ?? "",
      servingUnit: data['serving_unit'] ?? "Serving",
      weightPerServing: (data['weight_per_serving'] as num?)?.toDouble() ?? 1.0,
      weightUnit: data['weight_unit'] ?? "g",
      caloriesPerUnit: (data['calories_per_unit'] as num?)?.toDouble(),
      proteinPerUnit: (data['protein_per_unit'] as num?)?.toDouble() ?? 0.0,
      carbsPerUnit: (data['carbs_per_unit'] as num?)?.toDouble() ?? 0.0,
      fatsPerUnit: (data['fats_per_unit'] as num?)?.toDouble() ?? 0.0,
      totalStock: (data['total_stock'] as num?)?.toDouble(),
      remainingStock: (data['remaining_stock'] as num?)?.toDouble(),
      ingredients: ingredients,
      sharedBy: data['sender'] as String?,
      isActive: true,
    );

    addOrUpdateSupplement(supplement);
  }

  Future<void> importSharedStack(Map<String, dynamic> data) async {
    final List itemsData = data['items'] as List;
    final List<Supplement> importedItems = [];
    final String? sharedBy = data['sender'] as String?;

    for (var sData in itemsData) {
      final List<SupplementIngredient> ingredients = (sData['ingredients'] as List? ?? []).map((i) => SupplementIngredient(
        name: i['name'],
        amount: (i['amount'] as num).toDouble(),
        unit: i['unit'],
      )).toList();

      final supplement = Supplement(
        id: const Uuid().v4(),
        name: (sData['name'] as String).toUpperCase(),
        servingUnit: sData['serving_unit'] ?? "Serving",
        weightPerServing: (sData['weight_per_serving'] as num?)?.toDouble() ?? 1.0,
        weightUnit: sData['weight_unit'] ?? "g",
        caloriesPerUnit: (sData['calories_per_unit'] as num?)?.toDouble(),
        proteinPerUnit: (sData['protein_per_unit'] as num?)?.toDouble() ?? 0.0,
        carbsPerUnit: (sData['carbs_per_unit'] as num?)?.toDouble() ?? 0.0,
        fatsPerUnit: (sData['fats_per_unit'] as num?)?.toDouble() ?? 0.0,
        totalStock: (sData['total_stock'] as num?)?.toDouble(),
        remainingStock: (sData['remaining_stock'] as num?)?.toDouble(),
        ingredients: ingredients,
        sharedBy: sharedBy,
        isActive: true,
      );

      // Check for existing supplement by name to avoid duplicate entries in library
      final int existingIndex = _library.indexWhere(
        (s) => s.name.toUpperCase() == supplement.name.toUpperCase(),
      );

      if (existingIndex != -1) {
        // If it exists, update it with the shared details and the adjusted stock values
        final updatedExisting = _library[existingIndex].copyWith(
          description: supplement.description,
          servingUnit: supplement.servingUnit,
          weightPerServing: supplement.weightPerServing,
          weightUnit: supplement.weightUnit,
          caloriesPerUnit: () => supplement.caloriesPerUnit,
          proteinPerUnit: () => supplement.proteinPerUnit,
          carbsPerUnit: () => supplement.carbsPerUnit,
          fatsPerUnit: () => supplement.fatsPerUnit,
          totalStock: () => supplement.totalStock,
          remainingStock: () => supplement.remainingStock,
          ingredients: supplement.ingredients,
          sharedBy: sharedBy,
          isActive: true,
        );
        addOrUpdateSupplement(updatedExisting, index: existingIndex);
        importedItems.add(updatedExisting);
      } else {
        // If it's a new supplement, add it to the library
        addOrUpdateSupplement(supplement);
        importedItems.add(supplement);
      }
    }

    final stack = SupplementStack(
      id: const Uuid().v4(),
      name: (data['name'] as String).toUpperCase(),
      items: importedItems,
      sharedBy: sharedBy,
    );

    addOrUpdateStack(stack);
  }

  Future<void> updateSettings(SupplementSettings newSettings) async {
    if (_localRepo == null) return;
    final localSettings = newSettings.copyWith(isSynced: 0);
    _settings = localSettings;
    notifyListeners();

    try {
      await _localRepo!.saveSettings(localSettings);
      _syncSettings(localSettings);
    } catch (e) {
      debugPrint("Error saving supplement settings locally: $e");
    }
  }

  Future<void> _syncSettings(SupplementSettings settings) async {
    try {
      await _cloudRepo.saveSettings(settings);
      await _localRepo!.saveSettings(settings.copyWith(isSynced: 1));
      if (_settings.isSynced == 0) {
        _settings = _settings.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Supplement Settings): $e");
    }
  }

  Future<void> updatePinnedOrder(List<String> newOrder) async {
    final newSettings = _settings.copyWith(pinnedOrder: newOrder);
    await updateSettings(newSettings);
  }

  bool canLogSupplement(String id, {double? amount}) {
    final item = _library.firstWhereOrNull((s) => s.id == id);
    if (item == null) return false;
    double needed = amount ?? (item.pinnedUseServingsIntake ? (item.pinnedIntakeAmount * item.weightPerServing) : item.pinnedIntakeAmount);
    return (item.remainingStock ?? 0) >= (needed - 0.0001); // Precision tolerance
  }

  bool canLogStack(String stackId) {
    final stack = _supplementStacks.firstWhereOrNull((s) => s.id == stackId);
    if (stack == null) return false;
    for (var stackItem in stack.items) {
      final libraryItem = _library.firstWhereOrNull((s) => s.id == stackItem.id && s.isActive);
      if (libraryItem == null) continue;
      
      final bool isRecord = stack.pinnedRecordModes[libraryItem.id] ?? true;
      if (!isRecord) continue; 
      
      final bool servings = stack.pinnedUseServings[libraryItem.id] ?? true;
      final double amount = stack.pinnedAmounts[libraryItem.id] ?? 1.0;
      double needed = servings ? (amount * libraryItem.weightPerServing) : amount;
      
      if ((libraryItem.remainingStock ?? 0) < (needed - 0.0001)) return false;
    }
    return true;
  }
}
