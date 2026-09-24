import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/services/connectivity_service.dart';
import 'package:rugged/core/services/notification_service.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../model/calorie_log.dart';
import '../model/calorie_settings.dart';
import '../model/saved_meal.dart';
import '../data/calorie_local_repository.dart';
import '../data/calorie_cloud_repository.dart';

import 'package:rugged/core/providers/sync_provider.dart';

class CalorieProvider with ChangeNotifier {
  CalorieLocalRepository? _localRepo;
  CalorieCloudRepository _cloudRepo = CalorieCloudRepository();
  NotificationService _notificationService = NotificationService();
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  // Added for testing injection
  void setRepositories({CalorieLocalRepository? local, CalorieCloudRepository? cloud, NotificationService? notifications}) {
    if (local != null) _localRepo = local;
    if (cloud != null) _cloudRepo = cloud;
    if (notifications != null) _notificationService = notifications;
  }

  List<CalorieLog> _logs = [];
  List<SavedMeal> _savedMeals = [];
  CalorieSettings _settings = CalorieSettings();
  bool _isLoading = false;

  List<CalorieLog> get logs => _logs;
  List<SavedMeal> get savedMeals => _savedMeals;
  List<SavedMeal> get pinnedMeals => _savedMeals.where((m) => m.isPinnedToHome).toList();
  CalorieSettings get settings => _settings;
  Set<String> get visibleMetrics => _settings.visibleMetrics;
  bool get isLoading => _isLoading;

  Future<void> setVisibleMetrics(Set<String> metrics) async {
    await updateSettings(_settings.copyWith(visibleMetrics: metrics));
  }

  CalorieProvider() {
    _notificationService.addNotificationActionListener(_handleNotificationAction);
  }

  void _handleNotificationAction(String? payload, String? actionId) {
    if (actionId == 'log_meal' && payload != null) {
      try {
        final meal = _savedMeals.firstWhere((m) => m.id == payload);
        addLog(CalorieLog(
          id: const Uuid().v4(),
          userId: _localRepo?.userId,
          mealName: meal.name,
          foodItems: meal.foodItems,
          calories: meal.calories,
          protein: meal.protein,
          carbs: meal.carbs,
          fats: meal.fats,
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        debugPrint("CalorieProvider: Notification meal not found: $payload");
      }
    }
  }

  // Daily totals
  int get consumedCalories {
    final now = DateTime.now();
    final double total = _logs
        .where((l) =>
            l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day)
        .fold(0.0, (sum, l) => sum + l.calories);
    return total.toInt();
  }

  double? get proteinTotal {
    final now = DateTime.now();
    final dayLogs = _logs.where((l) =>
            l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day).toList();
    if (dayLogs.isEmpty) return null;
    if (dayLogs.every((l) => l.protein == null)) return null;
    return dayLogs.fold<double>(0.0, (sum, l) => sum + (l.protein ?? 0.0));
  }

  double? get carbsTotal {
    final now = DateTime.now();
    final dayLogs = _logs.where((l) =>
            l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day).toList();
    if (dayLogs.isEmpty) return null;
    if (dayLogs.every((l) => l.carbs == null)) return null;
    return dayLogs.fold<double>(0.0, (sum, l) => sum + (l.carbs ?? 0.0));
  }

  double? get fatsTotal {
    final now = DateTime.now();
    final dayLogs = _logs.where((l) =>
            l.timestamp.year == now.year &&
            l.timestamp.month == now.month &&
            l.timestamp.day == now.day).toList();
    if (dayLogs.isEmpty) return null;
    if (dayLogs.every((l) => l.fats == null)) return null;
    return dayLogs.fold<double>(0.0, (sum, l) => sum + (l.fats ?? 0.0));
  }

  void initializeForUser(String userId) {
    _localRepo = CalorieLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    debugPrint("CalorieProvider: Reconnected. Triggering sync...");
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscription(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:calorie_sync:$userId');

    // 1. Listen for Calorie Logs (calorie_meal_logs)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'calorie_meal_logs',
      callback: (payload) async {
        debugPrint("Realtime Calorie Log Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final log = CalorieLog.fromMap(payload.newRecord);
          
          final localLogs = await _localRepo!.getAllLogs();
          final localIdx = localLogs.indexWhere((l) => l.id == log.id);

          if (localIdx == -1 || localLogs[localIdx].isSynced == 1) {
            await _localRepo!.insertLog(log);
            
            final index = _logs.indexWhere((l) => l.id == log.id);
            if (index != -1) {
              _logs[index] = log;
            } else {
              _logs.insert(0, log);
              _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            }
            notifyListeners();
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

    // 2. Listen for Calorie Settings
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'calorie_settings',
      callback: (payload) async {
        debugPrint("Realtime Calorie Settings Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final newSettings = CalorieSettings.fromMap(payload.newRecord);
          if (_settings.isSynced == 1) {
            _settings = newSettings;
            await _localRepo!.saveSettings(newSettings);
            notifyListeners();
          }
        }
      },
    );

    // 3. Listen for Saved Meals (calorie_meals)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'calorie_meals',
      callback: (payload) async {
        debugPrint("Realtime Saved Meal Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final meal = SavedMeal.fromMap(payload.newRecord);
          
          final localMeals = await _localRepo!.getSavedMeals();
          final localIdx = localMeals.indexWhere((m) => m.id == meal.id);

          if (localIdx == -1 || localMeals[localIdx].isSynced == 1) {
            await _localRepo!.insertSavedMeal(meal);
            
            final index = _savedMeals.indexWhere((m) => m.id == meal.id);
            if (index != -1) {
              _savedMeals[index] = meal;
            } else {
              _savedMeals.add(meal);
              _savedMeals.sort((a, b) => a.name.compareTo(b.name));
            }
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteSavedMeal(id);
            _savedMeals.removeWhere((m) => m.id == id);
            notifyListeners();
          }
        }
      },
    );

    _realtimeChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("CalorieProvider: Realtime Subscribed/Reconnected. Syncing...");
        await _syncLocalToCloud();
        await _loadData(silent: true);
      }
    });
  }

  Future<void> _syncLocalToCloud() async {
    if (_localRepo == null) return;
    if (!AuthProvider().isPro) return;

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
          if (table == 'calorie_meal_logs') await _cloudRepo.deleteLog(id);
          if (table == 'calorie_meals') await _cloudRepo.deleteSavedMeal(id);
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

      // 4. Push Unsynced Saved Meals
      final unsyncedMeals = await _localRepo!.getUnsyncedSavedMeals();
      for (var meal in unsyncedMeals) {
        try {
          debugPrint("CalorieProvider: Syncing unsynced meal: ${meal.name}");
          await _cloudRepo.insertSavedMeal(meal);
          await _localRepo!.markSavedMealSynced(meal.id);
          syncProv.incrementCompleted();
        } catch (e) {
          debugPrint("CalorieProvider: Unsynced meal sync failed: ${meal.name} - $e");
        }
      }
    } catch (e) {
      debugPrint("CalorieProvider SyncLocalToCloud Error: $e");
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

      // 1. Load local state first for immediate UI availability
      _settings = await _localRepo!.getSettings();
      _logs = await _localRepo!.getAllLogs();
      _savedMeals = await _localRepo!.getSavedMeals();
      notifyListeners();

      // 2. Fetch remote data (PRO ONLY)
      if (AuthProvider().isPro) {
        try {
          final cloudSettings = await _cloudRepo.getSettings();
          if (cloudSettings != null) {
            await _localRepo!.saveSettings(cloudSettings, isFromCloud: true);
            _settings = await _localRepo!.getSettings();
          }
        } catch (e) {
          debugPrint("CalorieProvider: Settings sync failed: $e");
        }

        // 3. Fetch and Add/Update Logs
        try {
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

            // Pulling: Add/Update logs from cloud
            for (var log in cloudLogs) {
              await _localRepo!.insertLog(log, isFromCloud: true);
              logChanged = true;
            }
            if (logChanged) _logs = await _localRepo!.getAllLogs();
          }
        } catch (e) {
          debugPrint("CalorieProvider: Logs reconciliation failed: $e");
        }

        // 4. Fetch and Add/Update Saved Meals
        try {
          final cloudSavedMeals = await _cloudRepo.getSavedMeals();
          if (cloudSavedMeals != null) {
            final localMeals = await _localRepo!.getSavedMeals();
            final cloudIds = cloudSavedMeals.map((m) => m.id).toSet();

            // Deletion Reconciliation: Remove local synced meals missing from cloud
            for (var localM in localMeals) {
              if (localM.isSynced == 1 && !cloudIds.contains(localM.id)) {
                await _localRepo!.deleteSavedMeal(localM.id);
              }
            }

            bool mealChanged = false;

            // Pulling: Add/Update meals from cloud
            for (var meal in cloudSavedMeals) {
              await _localRepo!.insertSavedMeal(meal, isFromCloud: true);
              mealChanged = true;
            }
            if (mealChanged) _savedMeals = await _localRepo!.getSavedMeals();
          }
        } catch (e) {
          debugPrint("CalorieProvider: Saved meals reconciliation failed: $e");
        }
      }

      // 5. Schedule notifications
      for (var meal in _savedMeals) {
        if (meal.notificationsEnabled) {
          _notificationService.scheduleMealReminders(meal);
        }
      }
    } catch (e) {
      debugPrint("CalorieProvider Load Error (Major): $e");
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> addLog(CalorieLog log) async {
    if (_localRepo == null) return;
    
    final localLog = log.copyWith(
      isSynced: 0, 
      userId: _localRepo!.userId,
      updatedAt: DateTime.now(),
    );
    
    // UPSERT LOGIC: Check if log already exists in memory
    final index = _logs.indexWhere((l) => l.id == localLog.id);
    if (index != -1) {
      _logs[index] = localLog;
    } else {
      _logs.insert(0, localLog);
    }
    
    notifyListeners();

    try {
      await _localRepo!.insertLog(localLog);
      await _syncCalorieLog(localLog);
    } catch (e) {
      debugPrint("Error saving calorie log locally: $e");
    }
  }

  Future<void> _syncCalorieLog(CalorieLog log) async {
    try {
      await _cloudRepo.insertLog(log);
      await _localRepo!.markLogSynced(log.id);
      final idx = _logs.indexWhere((l) => l.id == log.id);
      if (idx != -1) {
        _logs[idx] = log.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Calorie Add): $e");
    }
  }

  Future<void> deleteLog(String id) async {
    if (_localRepo == null) return;
    _logs.removeWhere((l) => l.id == id);
    notifyListeners();

    try {
      await _localRepo!.deleteLog(id);
      await _localRepo!.addToDeletionQueue(id, 'calorie_meal_logs');
      await _syncCalorieDelete(id);
    } catch (e) {
      debugPrint("Error deleting calorie log locally: $e");
    }
  }

  Future<void> _syncCalorieDelete(String id) async {
    try {
      await _cloudRepo.deleteLog(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Calorie Delete): $e");
    }
  }

  Future<void> updateSettings(CalorieSettings settings) async {
    if (_localRepo == null) return;
    final localSettings = settings.copyWith(isSynced: 0);
    _settings = localSettings;
    notifyListeners();

    try {
      await _localRepo!.saveSettings(localSettings);
      _syncCalorieSettings(localSettings);
    } catch (e) {
      debugPrint("Error saving calorie settings locally: $e");
    }
  }

  Future<void> _syncCalorieSettings(CalorieSettings settings) async {
    try {
      await _cloudRepo.saveSettings(settings);
      await _localRepo!.markSettingsSynced();
      if (_settings.isSynced == 0) {
        _settings = _settings.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Calorie Settings): $e");
    }
  }

  // --- Saved Meals ---

  Future<void> saveMealTemplate(SavedMeal meal) async {
    if (_localRepo == null) return;
    
    // Check if meal with same name already exists to prevent duplicates in library
    final existingIndex = _savedMeals.indexWhere((m) => m.name.toLowerCase() == meal.name.toLowerCase());
    
    // Use existing ID if found, otherwise use provided/generated one
    final targetId = (existingIndex != -1) ? _savedMeals[existingIndex].id : meal.id;
    
    final localMeal = meal.copyWith(
      id: targetId,
      userId: _localRepo?.userId,
      isSynced: 0,
      updatedAt: DateTime.now(),
    );
    
    if (existingIndex != -1) {
      _savedMeals[existingIndex] = localMeal;
    } else {
      _savedMeals.add(localMeal);
    }
    _savedMeals.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();

    try {
      await _localRepo!.insertSavedMeal(localMeal);
      await _syncSavedMeal(localMeal);
    } catch (e) {
      debugPrint("Error saving meal template: $e");
    }
  }

  Future<void> _syncSavedMeal(SavedMeal meal) async {
    try {
      await _cloudRepo.insertSavedMeal(meal);
      await _localRepo!.markSavedMealSynced(meal.id);
      final idx = _savedMeals.indexWhere((m) => m.id == meal.id);
      if (idx != -1) {
        _savedMeals[idx] = meal.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Saved Meal): $e");
    }
  }

  Future<void> updateSavedMeal(SavedMeal meal) async {
    if (_localRepo == null) return;

    final localMeal = meal.copyWith(isSynced: 0, userId: _localRepo!.userId);
    final index = _savedMeals.indexWhere((m) => m.id == localMeal.id);
    if (index != -1) {
      _savedMeals[index] = localMeal;
      notifyListeners();

      try {
        await _localRepo!.insertSavedMeal(localMeal);
        _syncSavedMeal(localMeal);
        
        // Ensure notifications are updated
        if (localMeal.notificationsEnabled) {
          await _notificationService.scheduleMealReminders(localMeal);
        } else {
          await _notificationService.cancelMealReminders(localMeal.id);
        }
      } catch (e) {
        debugPrint("Error updating saved meal: $e");
      }
    }
  }

  Future<void> deleteSavedMeal(String id) async {
    if (_localRepo == null) return;
    _savedMeals.removeWhere((m) => m.id == id);
    notifyListeners();

    try {
      await _localRepo!.deleteSavedMeal(id);
      await _localRepo!.addToDeletionQueue(id, 'calorie_meals');
      await _syncSavedMealDelete(id);
    } catch (e) {
      debugPrint("Error deleting saved meal: $e");
    }
  }

  Future<void> _syncSavedMealDelete(String id) async {
    try {
      await _cloudRepo.deleteSavedMeal(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Saved Meal Delete): $e");
    }
  }

  Future<void> forceRefresh() async {
    if (_localRepo == null) return;
    await _syncLocalToCloud();
    await _loadData();
  }

  Future<String?> generateShareableLink(SavedMeal meal, String userName) async {
    if (!AuthProvider().isPro) {
      debugPrint("CalorieProvider: Sharing skipped - Pro status required.");
      return null;
    }

    final Map<String, dynamic> shareData = {
      'type': 'meal',
      'name': meal.name,
      'foodItems': meal.foodItems,
      'calories': meal.calories,
      'protein': meal.protein,
      'carbs': meal.carbs,
      'fats': meal.fats,
      'sender': userName,
    };

    try {
      final response = await _supabase.from('shared_data').insert({
        'data': shareData,
      }).select('id').single();

      final shareId = response['id'] as String;
      return "https://affulabs.com/rugged/app/share/meal?id=$shareId&from=${Uri.encodeComponent(userName)}";
    } catch (e) {
      debugPrint("CalorieProvider: Error generating share link: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSharedMeal(String shareId) async {
    try {
      final response = await _supabase.from('shared_data').select().eq('id', shareId).single();
      final createdAt = DateTime.parse(response['created_at']);
      if (DateTime.now().difference(createdAt).inDays >= 7) return {'expired': true};
      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint("CalorieProvider: Error fetching shared meal: $e");
      return null;
    }
  }

  Future<void> importSharedMeal(Map<String, dynamic> data) async {
    final meal = SavedMeal(
      id: const Uuid().v4(),
      name: (data['name'] as String).toUpperCase(),
      foodItems: data['foodItems'] ?? "",
      calories: (data['calories'] as num).toDouble(),
      protein: (data['protein'] as num?)?.toDouble(),
      carbs: (data['carbs'] as num?)?.toDouble(),
      fats: (data['fats'] as num?)?.toDouble(),
      sharedBy: data['sender'] as String?,
      isSynced: 0,
    );

    await saveMealTemplate(meal);
  }

  // --- Library Cleanup ---

  Future<void> removeSupplementFromAllMeals(String supplementId, double caloriesPerUnit, double proteinPerUnit, double carbsPerUnit, double fatsPerUnit) async {
    bool changed = false;
    for (int i = 0; i < _savedMeals.length; i++) {
      final meal = _savedMeals[i];
      if (meal.addedSupplementsJson == null) continue;

      try {
        final List<dynamic> decoded = jsonDecode(meal.addedSupplementsJson!);
        final int initialLength = decoded.length;
        
        // Find if this meal contains the supplement
        double removedCals = 0;
        double removedPro = 0, removedCarbs = 0, removedFats = 0;

        decoded.removeWhere((item) {
          final String id = (item is Map) ? item['id'] : item as String;
          if (id == supplementId) {
            final double amount = (item is Map) ? (item['amount'] as num).toDouble() : 1.0;
            // The template stores the MULTIPLIED amount.
            removedCals += caloriesPerUnit * amount;
            removedPro += proteinPerUnit * amount;
            removedCarbs += carbsPerUnit * amount;
            removedFats += fatsPerUnit * amount;
            return true;
          }
          return false;
        });

        if (decoded.length < initialLength) {
          // Recalculate meal totals to remove the supplement's impact
          final double? newPro = (meal.protein != null) ? (meal.protein! - removedPro).clamp(0, 9999) : null;
          final double? newCarbs = (meal.carbs != null) ? (meal.carbs! - removedCarbs).clamp(0, 9999) : null;
          final double? newFats = (meal.fats != null) ? (meal.fats! - removedFats).clamp(0, 9999) : null;

          _savedMeals[i] = meal.copyWith(
            addedSupplementsJson: decoded.isEmpty ? null : jsonEncode(decoded),
            clearSupplements: decoded.isEmpty,
            calories: (meal.calories - removedCals),
            protein: newPro != null && newPro > 0 ? newPro : null,
            carbs: newCarbs != null && newCarbs > 0 ? newCarbs : null,
            fats: newFats != null && newFats > 0 ? newFats : null,
            isSynced: 0,
          );
          await _localRepo!.insertSavedMeal(_savedMeals[i]);
          await _cloudRepo.insertSavedMeal(_savedMeals[i]);
          changed = true;
        }
      } catch (e) {
        debugPrint("Error cleaning supplement from meal ${meal.name}: $e");
      }
    }
    if (changed) notifyListeners();
  }

  Future<void> removeStackFromAllMeals(String stackId, double stackTotalCals, double stackPro, double stackCarbs, double stackFats) async {
    bool changed = false;
    for (int i = 0; i < _savedMeals.length; i++) {
      final meal = _savedMeals[i];
      if (meal.addedStacksJson == null) continue;

      try {
        final List<dynamic> decoded = jsonDecode(meal.addedStacksJson!);
        final int initialLength = decoded.length;

        decoded.removeWhere((item) {
          final String id = (item is Map) ? item['id'] : item as String;
          return id == stackId;
        });

        if (decoded.length < initialLength) {
          final double? newPro = (meal.protein != null) ? (meal.protein! - stackPro).clamp(0, 9999) : null;
          final double? newCarbs = (meal.carbs != null) ? (meal.carbs! - stackCarbs).clamp(0, 9999) : null;
          final double? newFats = (meal.fats != null) ? (meal.fats! - stackFats).clamp(0, 9999) : null;

          _savedMeals[i] = meal.copyWith(
            addedStacksJson: decoded.isEmpty ? null : jsonEncode(decoded),
            clearStacks: decoded.isEmpty,
            // Recalculate (Assuming multiplier applied to stack during save)
            // Note: Since stacks are complex, we subtract the cached stack totals
            calories: (meal.calories - stackTotalCals).clamp(0, 99999),
            protein: newPro != null && newPro > 0 ? newPro : null,
            carbs: newCarbs != null && newCarbs > 0 ? newCarbs : null,
            fats: newFats != null && newFats > 0 ? newFats : null,
            isSynced: 0,
          );
          await _localRepo!.insertSavedMeal(_savedMeals[i]);
          await _cloudRepo.insertSavedMeal(_savedMeals[i]);
          changed = true;
        }
      } catch (e) {
        debugPrint("Error cleaning stack from meal ${meal.name}: $e");
      }
    }
    if (changed) notifyListeners();
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _logs.clear();
    _savedMeals.clear();
    _settings = CalorieSettings();
    _localRepo = null;
    notifyListeners();
  }
}
