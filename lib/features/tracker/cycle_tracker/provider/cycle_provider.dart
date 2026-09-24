import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:rugged/core/services/connectivity_service.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import '../model/training_cycle.dart';
import '../model/workout.dart';
import '../model/exercise.dart';
import '../model/exercise_log.dart';
import '../model/cycle_settings.dart';
import '../data/cycle_local_repository.dart';
import '../data/cycle_cloud_repository.dart';

import 'package:rugged/core/providers/sync_provider.dart';

class CycleProvider with ChangeNotifier {
  CycleLocalRepository? _localRepo;
  CycleCloudRepository _cloudRepo = CycleCloudRepository();
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  void setRepositories({CycleLocalRepository? local, CycleCloudRepository? cloud}) {
    if (local != null) _localRepo = local;
    if (cloud != null) _cloudRepo = cloud;
  }

  void setCyclesForTest(List<TrainingCycle> list) {
    _cycles.clear();
    _cycles.addAll(list);
  }

  List<TrainingCycle> _cycles = [];
  final List<ExerciseLog> _logs = [];
  CycleSettings _settings = CycleSettings();
  bool _isLoading = false;

  // Persistent Selection State for Navigation & Two-Pane layouts
  String? _selectedWorkoutId;
  String? _selectedWorkoutName;
  String? _selectedExerciseId;
  String? _selectedExerciseName;

  String? get selectedWorkoutId => _selectedWorkoutId;
  String? get selectedWorkoutName => _selectedWorkoutName;
  String? get selectedExerciseId => _selectedExerciseId;
  String? get selectedExerciseName => _selectedExerciseName;

  void setWorkoutSelection(String? id, String? name) {
    _selectedWorkoutId = id;
    _selectedWorkoutName = name;
    _selectedExerciseId = null; // Clear exercise when workout changes
    _selectedExerciseName = null;
    notifyListeners();
  }

  void setExerciseSelection(String? id, String? name) {
    _selectedExerciseId = id;
    _selectedExerciseName = name;
    notifyListeners();
  }

  void clearSelection() {
    _selectedWorkoutId = null;
    _selectedWorkoutName = null;
    _selectedExerciseId = null;
    _selectedExerciseName = null;
    notifyListeners();
  }

  Set<String> get visibleMetrics => _settings.visibleMetrics;

  void setVisibleMetrics(Set<String> metrics) {
    updateSettings(_settings.copyWith(visibleMetrics: metrics));
  }

  // Performance Caches
  final Map<String, String> _exerciseNameCache = {};
  List<Workout> _cachedWorkouts = [];
  List<Exercise> _cachedExercises = [];

  List<TrainingCycle> get cycles => _cycles;
  List<ExerciseLog> get logs => _logs;
  CycleSettings get settings => _settings;
  bool get isLoading => _isLoading;

  // Helpers for UI compatibility
  List<Workout> get workouts => _cachedWorkouts;
  List<Exercise> get exercises => _cachedExercises;

  String? getExerciseName(String id) => _exerciseNameCache[id];

  Workout? getWorkoutForExercise(String exerciseId) {
    for (var cycle in _cycles) {
      for (var workout in cycle.workouts) {
        if (workout.exercises.any((e) => e.id == exerciseId)) {
          return workout;
        }
      }
    }
    return null;
  }

  Workout? getWorkoutById(String workoutId) {
    for (var cycle in _cycles) {
      for (var workout in cycle.workouts) {
        if (workout.id == workoutId) return workout;
      }
    }
    return null;
  }

  bool isExerciseInUse(String name) {
    final upperName = name.trim().toUpperCase();
    return _cachedExercises.any((e) => e.name.trim().toUpperCase() == upperName);
  }

  TrainingCycle? get activeCycle {
    try {
      return _cycles.firstWhere((c) => c.status == CycleStatus.active);
    } catch (_) {
      return null;
    }
  }

  List<TrainingCycle> get cycleHistory => _cycles.where((c) => c.status == CycleStatus.finished || c.status == CycleStatus.incomplete).toList();
  List<TrainingCycle> get libraryTemplates => _cycles.where((c) => c.status == CycleStatus.template).toList();

  void initializeForUser(String userId) {
    _localRepo = CycleLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    debugPrint("CycleProvider: [CONNECTIVITY] Reconnected to Internet. Starting background sync...");
    // Sequential Sync: Push MUST complete before Pull to avoid overwriting local changes
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscription(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:cycle_sync:$userId');

    // 1. Listen for Training Cycles (hit_cycles)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'hit_cycles',
      callback: (payload) async {
        debugPrint("Realtime Training Cycle Update: ${payload.eventType}");
        
        // Manual filter to ensure message reaches device even if server filters are finicky
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final cycleData = payload.newRecord;
          final localCycles = await _localRepo!.getAllCycles();
          final localIdx = localCycles.indexWhere((c) => c.id == cycleData['id']);
          
          if (localIdx == -1 || localCycles[localIdx].isSynced == 1) {
            final cycle = TrainingCycle.fromMap(cycleData, localIdx != -1 ? localCycles[localIdx].workouts : []);
            await _localRepo!.insertCycle(cycle);
            await _loadData(silent: true);
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteCycle(id);
            _cycles.removeWhere((c) => c.id == id);
            _rebuildCaches();
            notifyListeners();
          }
        }
      },
    );

    // 1b. Listen for Workouts (hit_workouts)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'hit_workouts',
      callback: (payload) async {
        debugPrint("Realtime Workout Update: ${payload.eventType}");
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final workout = Workout.fromMap(payload.newRecord);
          await _localRepo!.insertWorkout(workout);
          await _loadData(silent: true);
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteWorkout(id);
            await _loadData(silent: true);
          }
        }
      },
    );

    // 1c. Listen for Exercises (hit_exercises)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'hit_exercises',
      callback: (payload) async {
        debugPrint("Realtime Exercise Update: ${payload.eventType}");
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final exercise = Exercise.fromMap(payload.newRecord);
          await _localRepo!.insertExercise(exercise);
          await _loadData(silent: true);
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteExercise(id);
            await _loadData(silent: true);
          }
        }
      },
    );

    // 2. Listen for Exercise Logs
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'exercise_logs',
      callback: (payload) async {
        debugPrint("Realtime Exercise Log Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final log = ExerciseLog.fromMap(payload.newRecord);
          
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

    // 3. Listen for Cycle Settings (hit_settings)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'hit_settings',
      callback: (payload) async {
        debugPrint("Realtime Cycle Settings Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final settings = CycleSettings.fromMap(payload.newRecord);
          if (_settings.isSynced == 1) {
            await _localRepo!.saveSettings(settings.toMap());
            _settings = settings;
            notifyListeners();
          }
        }
      },
    );

    _realtimeChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("CycleProvider: Realtime Subscribed/Reconnected. Syncing...");
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
      debugPrint("CycleProvider: [SYNC-PUSH] Found ${deletions.length} pending deletions.");
      for (var del in deletions) {
        final id = del['id'] as String;
        final table = del['table_name'] as String;
        try {
          debugPrint("CycleProvider: [SYNC-PUSH] Deleting $id from $table on Cloud...");
          if (table == 'hit_cycles') await _cloudRepo.deleteCycle(id);
          if (table == 'hit_workouts') await _cloudRepo.deleteWorkout(id);
          if (table == 'hit_exercises') await _cloudRepo.deleteExercise(id);
          if (table == 'exercise_logs') await _cloudRepo.deleteLog(id);
          await _localRepo!.removeFromDeletionQueue(id);
          debugPrint("CycleProvider: [SYNC-PUSH] Successfully deleted $id and removed from queue.");
          syncProv.incrementCompleted();
        } catch (e) {
          debugPrint("CycleProvider: [SYNC-PUSH] Failed to delete $id: $e");
        }
      }

      // 2. Push Unsynced Cycles (Deep Sync)
      final unsyncedCycles = await _localRepo!.getUnsyncedCycles();
      debugPrint("CycleProvider: [SYNC-PUSH] Found ${unsyncedCycles.length} unsynced cycles.");
      for (var cycle in unsyncedCycles) {
        if (_shouldSyncCycle(cycle)) {
          try {
            debugPrint("CycleProvider: [SYNC-PUSH] Pushing Cycle '${cycle.name}' (${cycle.id})...");
            await _syncCycle(cycle);
            syncProv.incrementCompleted();
          } catch (e) {
            debugPrint("CycleProvider: [SYNC-PUSH] Failed to push cycle ${cycle.id}: $e");
          }
        }
      }

      // 3. Push Unsynced Logs
      final unsyncedLogs = await _localRepo!.getUnsyncedLogs();
      debugPrint("CycleProvider: [SYNC-PUSH] Found ${unsyncedLogs.length} unsynced exercise logs.");
      for (var log in unsyncedLogs) {
        try {
          debugPrint("CycleProvider: [SYNC-PUSH] Pushing Log ${log.id}...");
          await _cloudRepo.insertLog(log);
          await _localRepo!.markLogSynced(log.id);
          syncProv.incrementCompleted();
        } catch (e) {
          debugPrint("CycleProvider: [SYNC-PUSH] Failed to push log ${log.id}: $e");
        }
      }

      // 4. Push Unsynced Settings
      final unsyncedSettings = await _localRepo!.getUnsyncedSettings();
      if (unsyncedSettings != null) {
        try {
          debugPrint("CycleProvider: [SYNC-PUSH] Pushing updated settings...");
          await _cloudRepo.saveSettings(unsyncedSettings);
          await _localRepo!.markSettingsSynced();
          syncProv.incrementCompleted();
        } catch (e) {
          debugPrint("CycleProvider: [SYNC-PUSH] Failed to push settings: $e");
        }
      }
    } finally {
      syncProv.endFeatureSync();
    }
  }

  Future<void> forceRefresh() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint("CycleProvider: FORCE REFRESH TRIGGERED");
      
      // 1. First, try to push anything unsynced (so we don't lose local data)
      await _syncLocalToCloud();
      
      // 2. Perform a fresh load (which pulls from cloud)
      await _loadData(silent: true);
      
      debugPrint("CycleProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("CycleProvider: Force Refresh Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_localRepo == null) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // 1. Initial Local Load for Responsiveness
      final settingsMap = await _localRepo!.getSettings();
      if (settingsMap != null) _settings = CycleSettings.fromMap(settingsMap);
      
      _cycles = await _localRepo!.getAllCycles();

      // AUTO-INITIALIZE RUGGED ROUTINE LIBRARY:
      // If no library templates are found (fresh install or migration), seed them locally.
      if (_cycles.where((c) => c.isDefault && c.status == CycleStatus.template).isEmpty) {
        debugPrint("CycleProvider: [INITIALIZE] Seeding Rugged routine library locally...");
        await _initializeRuggedDefaults();
        _cycles = await _localRepo!.getAllCycles(); // Refresh memory
      }

      _rebuildCaches();
      notifyListeners();

      // 2. THE RECONCILIATION PROCESS (PRO ONLY)
      if (AuthProvider().isPro) {
        debugPrint("CycleProvider: [SYNC-PULL] RECONCILIATION START");

        // 2a. Fetch Cloud Data
        debugPrint("CycleProvider: [SYNC-PULL] Fetching cloud data...");
        final cloudCycles = await _cloudRepo.getAllCycles();
        final cloudLogs = await _cloudRepo.getAllLogs();
        final cloudSettings = await _cloudRepo.getSettings();
        debugPrint("CycleProvider: [SYNC-PULL] Cloud Data: ${cloudCycles?.length ?? 0} cycles, ${cloudLogs?.length ?? 0} logs.");

        if (cloudSettings != null) {
          await _localRepo!.saveSettings(cloudSettings, isFromCloud: true);
          final refreshedSettings = await _localRepo!.getSettings();
          if (refreshedSettings != null) _settings = CycleSettings.fromMap(refreshedSettings);
        }

        if (cloudCycles != null) {
          final pendingDels = await _localRepo!.getPendingDeletions();
          final pendingIds = pendingDels.map((d) => d['id'] as String).toSet();

          // 2b. Merge Cloud -> Local (Only non-dirty items)
          for (var c in cloudCycles) {
            if (pendingIds.contains(c.id)) continue;
            
            // Filter out deleted sub-items based on pending deletion queue
            final filteredWorkouts = c.workouts.where((w) => !pendingIds.contains(w.id)).map((w) {
              final filteredEx = w.exercises.where((e) => !pendingIds.contains(e.id)).toList();
              return w.copyWith(exercises: filteredEx);
            }).toList();
            
            final filteredCycle = c.copyWith(workouts: filteredWorkouts);
            
            // CRITICAL: isFromCloud: true prevents overwriting local unsynced work
            await _localRepo!.insertCycle(filteredCycle, isFromCloud: true);
          }
        }

        if (cloudLogs != null) {
          final pendingDels = await _localRepo!.getPendingDeletions();
          final pendingIds = pendingDels.map((d) => d['id'] as String).toSet();

          for (var l in cloudLogs) {
            if (pendingIds.contains(l.id)) continue;
            await _localRepo!.insertLog(l, isFromCloud: true);
          }
        }

        // 3. PUSH LOCAL CHANGES (Push second so local additions win)
        await _syncLocalToCloud();

        // 4. Final Verification: Prune anything that was deleted on OTHER devices
        if (cloudCycles != null) {
          final currentLocal = await _localRepo!.getAllCycles();
          final cloudCycleIds = cloudCycles.map((c) => c.id).toSet();
          final cloudWorkoutIds = cloudCycles.expand((c) => c.workouts.map((w) => w.id)).toSet();
          final cloudExerciseIds = cloudCycles.expand((c) => c.workouts.expand((w) => w.exercises.map((e) => e.id))).toSet();

          for (var lc in currentLocal) {
            if (lc.isSynced == 1 && !lc.isDefault && !cloudCycleIds.contains(lc.id)) {
              await _localRepo!.deleteCycle(lc.id);
            } else if (!lc.isDefault) {
              for (var lw in lc.workouts) {
                if (lw.isSynced == 1 && !cloudWorkoutIds.contains(lw.id)) {
                  await _localRepo!.deleteWorkout(lw.id);
                }
                for (var le in lw.exercises) {
                  if (le.isSynced == 1 && !cloudExerciseIds.contains(le.id)) {
                    await _localRepo!.deleteExercise(le.id);
                  }
                }
              }
            }
          }
        }
      }

      // 5. Final Memory Refresh
      _cycles = await _localRepo!.getAllCycles();
      final allLogsRefresh = await _localRepo!.getAllLogs();
      _logs.clear();
      _logs.addAll(allLogsRefresh);
      _rebuildCaches();
      await _reconcileLogTimestamps();
      
      debugPrint("CycleProvider: [SYNC-PULL] RECONCILIATION COMPLETE");
    } catch (e) {
      debugPrint("CycleProvider: [SYNC-PULL] Sync Error: $e");
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _rebuildCaches() {
    _exerciseNameCache.clear();
    _cachedWorkouts = [];
    _cachedExercises = [];
    
    for (var cycle in _cycles) {
      for (var workout in cycle.workouts) {
        _cachedWorkouts.add(workout);
        for (var exercise in workout.exercises) {
          _cachedExercises.add(exercise);
          _exerciseNameCache[exercise.id] = exercise.name;
        }
      }
    }
  }

  Future<void> _reconcileLogTimestamps() async {
    if (_localRepo == null || _logs.isEmpty) return;

    final Map<String, DateTime?> exerciseWorkoutDateMap = {};
    for (var cycle in _cycles) {
      for (var workout in cycle.workouts) {
        for (var exercise in workout.exercises) {
          exerciseWorkoutDateMap[exercise.id] = workout.completedAt;
        }
      }
    }

    bool needsResort = false;
    for (int j = 0; j < _logs.length; j++) {
      final log = _logs[j];
      final workoutCompletedAt = exerciseWorkoutDateMap[log.exerciseId];

      if (workoutCompletedAt != null) {
        if (log.timestamp.year != workoutCompletedAt.year ||
            log.timestamp.month != workoutCompletedAt.month ||
            log.timestamp.day != workoutCompletedAt.day) {
          final newTimestamp = DateTime(
            workoutCompletedAt.year,
            workoutCompletedAt.month,
            workoutCompletedAt.day,
            log.timestamp.hour,
            log.timestamp.minute,
            log.timestamp.second,
          );
          final updatedLog = log.copyWith(
            timestamp: () => newTimestamp,
            isSynced: 0,
            updatedAt: DateTime.now(),
          );
          _logs[j] = updatedLog;
          await _localRepo!.insertLog(updatedLog);
          needsResort = true;
          debugPrint("CycleProvider: Reconciled log ${log.id} timestamp to $newTimestamp");
        }
      }
    }

    if (needsResort) {
      _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
  }

  // --- Actions ---

  bool _shouldSyncCycle(TrainingCycle cycle) {
    // Only skip sync for the built-in library templates.
    // Active cycles, finished history, and custom templates ALWAYS sync.
    if (cycle.isDefault && cycle.status == CycleStatus.template) {
      return false;
    }
    return true;
  }

  Future<void> addCycle(TrainingCycle cycle) async {
    if (_localRepo == null) return;
    
    final localCycle = cycle.copyWith(
      isSynced: 0,
      updatedAt: DateTime.now(),
    );
    _cycles.add(localCycle);
    _rebuildCaches();
    notifyListeners();

    try {
      await _localRepo!.insertCycle(localCycle);
      // Everything goes to the cloud EXCEPT the static library templates
      if (_shouldSyncCycle(localCycle)) {
        await _syncCycle(localCycle);
      }
    } catch (e) {
      debugPrint("Error saving new cycle locally: $e");
    }
  }

  Future<void> _syncCycle(TrainingCycle cycle) async {
    try {
      // 1. Push Cycle Header
      await _cloudRepo.insertCycle(cycle);
      await _localRepo!.markCycleSynced(cycle.id);
      
      // 2. Push Workouts & Exercises with Individual Error Isolation
      for (var workout in cycle.workouts) {
        try {
          await _cloudRepo.insertWorkout(workout);
          await _localRepo!.markWorkoutSynced(workout.id);
          
          for (var exercise in workout.exercises) {
            try {
              await _cloudRepo.insertExercise(exercise);
              await _localRepo!.markExerciseSynced(exercise.id);
            } catch (e) {
              debugPrint("Background Sync Error (Exercise ${exercise.id}): $e");
            }
          }
        } catch (e) {
          debugPrint("Background Sync Error (Workout ${workout.id}): $e");
        }
      }

      final idx = _cycles.indexWhere((c) => c.id == cycle.id);
      if (idx != -1) {
        _cycles[idx] = _cycles[idx].copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Cycle Root): $e");
    }
  }

  Future<void> activateCycle(String templateId) async {
    if (_localRepo == null) return;
    
    final now = DateTime.now();

    // 1. OPTIMISTIC UI: Deactivate current active cycle in memory
    TrainingCycle? oldActiveToPersist;
    for (int i = 0; i < _cycles.length; i++) {
      if (_cycles[i].status == CycleStatus.active) {
        oldActiveToPersist = _cycles[i].copyWith(
          status: _cycles[i].isReadyToFinish ? CycleStatus.finished : CycleStatus.incomplete,
          completedAt: () => now,
          isSynced: 0,
          updatedAt: now,
        );
        _cycles[i] = oldActiveToPersist;
      }
    }

    // 2. Find template and prepare NEW active instance
    final template = _cycles.firstWhere((c) => c.id == templateId);
    final newCycleId = const Uuid().v4();
    final newActiveCycle = template.copyWith(
      id: newCycleId,
      status: CycleStatus.active,
      startedAt: () => now,
      isDefault: false, 
      isSynced: 0,
      updatedAt: now,
      workouts: template.workouts.map((tw) {
        final nwId = const Uuid().v4();
        return tw.copyWith(
          id: nwId,
          cycleId: newCycleId,
          status: WorkoutStatus.pending,
          completedAt: () => null,
          isSynced: 0,
          updatedAt: now,
          exercises: tw.exercises.map((te) => te.copyWith(
            id: const Uuid().v4(),
            workoutId: nwId,
            isSynced: 0,
            updatedAt: now,
          )).toList(),
        );
      }).toList(),
    );

    // 3. OPTIMISTIC UI: Add the new one and refresh view IMMEDIATELY
    _cycles.add(newActiveCycle);
    _rebuildCaches();
    notifyListeners();

    // 4. BACKGROUND PERSISTENCE: Handle DB and Cloud without blocking UI
    _persistActivationFlow(oldActiveToPersist, newActiveCycle);
  }

  Future<void> _persistActivationFlow(TrainingCycle? oldCycle, TrainingCycle newCycle) async {
    try {
      if (oldCycle != null) {
        await _localRepo!.insertCycle(oldCycle);
        _syncCycle(oldCycle);
      }
      
      await _localRepo!.insertCycle(newCycle);
      if (_shouldSyncCycle(newCycle)) {
        await _syncCycle(newCycle);
      }
    } catch (e) {
      debugPrint("CycleProvider: Background Activation Error: $e");
    }
  }

  Future<void> _markCycleAsModified(String cycleId) async {
    final idx = _cycles.indexWhere((c) => c.id == cycleId);
    if (idx != -1 && _cycles[idx].isDefault) {
      final updatedCycle = _cycles[idx].copyWith(isDefault: false, isSynced: 0);
      _cycles[idx] = updatedCycle;
      await _localRepo!.insertCycle(updatedCycle);
      _syncCycle(updatedCycle);
      notifyListeners();
    }
  }

  Future<void> addWorkout(Workout workout) async {
    if (_localRepo == null) return;
    
    // Find parent cycle
    final cycleIdx = _cycles.indexWhere((c) => c.id == workout.cycleId);
    if (cycleIdx == -1) return;

    // LOCK: Do not allow modifying default blueprints
    if (_cycles[cycleIdx].isDefault && _cycles[cycleIdx].status == CycleStatus.template) {
      debugPrint("CycleProvider: Blocked modification of a locked Default Blueprint.");
      return;
    }

    // 1. INSTANT MEMORY UPDATE: Update UI state immediately (0ms)
    final now = DateTime.now();
    final updatedWorkout = workout.copyWith(
      isSynced: 0,
      updatedAt: now,
    );
    
    final updatedCycle = _cycles[cycleIdx].copyWith(
      workouts: [..._cycles[cycleIdx].workouts, updatedWorkout],
      isSynced: 0,
      updatedAt: now,
    );
    _cycles[cycleIdx] = updatedCycle;
    _rebuildCaches();
    notifyListeners();
    
    // 2. BACKGROUND PERSISTENCE & SYNC: Save to local DB & Cloud asynchronously
    try {
      await _markCycleAsModified(workout.cycleId);
      await _localRepo!.insertWorkout(updatedWorkout);
      await _localRepo!.insertCycle(updatedCycle);
      
      if (_shouldSyncCycle(updatedCycle)) {
        await _syncCycle(updatedCycle);
      }
    } catch (e) {
      debugPrint("Error saving workout: $e");
    }
  }

  Future<void> addExercise(Exercise exercise) async {
    if (_localRepo == null) return;
    
    // 1. Find parent cycle and check if it is a locked blueprint
    int? pCycleIdx;
    for (int i = 0; i < _cycles.length; i++) {
      if (_cycles[i].workouts.any((w) => w.id == exercise.workoutId)) {
        pCycleIdx = i;
        break;
      }
    }

    if (pCycleIdx != null && _cycles[pCycleIdx].isDefault && _cycles[pCycleIdx].status == CycleStatus.template) {
      debugPrint("CycleProvider: Blocked exercise addition to a locked Default Blueprint.");
      return;
    }

    // 2. OPTIMISTIC UPDATE: Find parent workout and update memory state
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == exercise.workoutId);
      if (wIdx != -1) {
        await _markCycleAsModified(_cycles[i].id);
        
        final now = DateTime.now();
        final updatedExercise = exercise.copyWith(
          isSynced: 0,
          updatedAt: now,
        );

        final updatedWorkout = _cycles[i].workouts[wIdx].copyWith(
          exercises: [..._cycles[i].workouts[wIdx].exercises, updatedExercise],
          isSynced: 0,
          updatedAt: now,
        );
        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        
        final updatedCycle = _cycles[i].copyWith(
          workouts: updatedWorkouts,
          isSynced: 0,
          updatedAt: now,
        );
        _cycles[i] = updatedCycle;
        _rebuildCaches();
        notifyListeners();

        // 2. Persistent Save
        try {
          await _localRepo!.insertExercise(updatedExercise);
          await _localRepo!.insertWorkout(updatedWorkout);
          await _localRepo!.insertCycle(updatedCycle);

          await _checkWorkoutCompletion(workoutId: exercise.workoutId);

          if (_shouldSyncCycle(updatedCycle)) {
            await _syncCycle(updatedCycle);
          }
        } catch (e) {
          debugPrint("Error saving exercise: $e");
        }
        break;
      }
    }
  }

  Future<void> deleteWorkout(String id) async {
    if (_localRepo == null) return;
    
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == id);
      if (wIdx != -1) {
        // LOCK check
        if (_cycles[i].isDefault && _cycles[i].status == CycleStatus.template) {
          debugPrint("CycleProvider: Blocked deletion from a locked Default Blueprint.");
          return;
        }

        await _markCycleAsModified(_cycles[i].id);

        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts)..removeAt(wIdx);
        final updatedCycle = _cycles[i].copyWith(
          workouts: updatedWorkouts,
          isSynced: 0,
        );
        _cycles[i] = updatedCycle;
        _rebuildCaches();
        notifyListeners();
        
        await _localRepo!.deleteWorkout(id);
        await _localRepo!.insertCycle(updatedCycle);
        await _localRepo!.addToDeletionQueue(id, 'hit_workouts');
        _syncWorkoutDelete(id);
        
        if (_shouldSyncCycle(updatedCycle)) {
          _syncCycle(updatedCycle);
        }
        break;
      }
    }
  }

  Future<void> _syncWorkoutDelete(String id) async {
    try {
      await _cloudRepo.deleteWorkout(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (_) {}
  }

  Future<void> deleteExercise(String id) async {
    if (_localRepo == null) return;
    
    bool found = false;
    for (int i = 0; i < _cycles.length; i++) {
      for (int j = 0; j < _cycles[i].workouts.length; j++) {
        final List<Exercise> exList = _cycles[i].workouts[j].exercises;
        final exIdx = exList.indexWhere((e) => e.id == id);
        if (exIdx != -1) {
          // LOCK check
          if (_cycles[i].isDefault && _cycles[i].status == CycleStatus.template) {
            debugPrint("CycleProvider: Blocked exercise deletion from a locked Default Blueprint.");
            return;
          }

          await _markCycleAsModified(_cycles[i].id);

          final String workoutId = _cycles[i].workouts[j].id;

          final updatedExercises = List<Exercise>.from(exList)..removeAt(exIdx);
          final updatedWorkout = _cycles[i].workouts[j].copyWith(exercises: updatedExercises);
          final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
          updatedWorkouts[j] = updatedWorkout;
          
          final updatedCycle = _cycles[i].copyWith(
            workouts: updatedWorkouts,
            isSynced: 0,
          );
          _cycles[i] = updatedCycle;
          _rebuildCaches();
          notifyListeners();
          
          await _localRepo!.deleteExercise(id);
          await _localRepo!.insertCycle(updatedCycle);
          await _localRepo!.addToDeletionQueue(id, 'hit_exercises');
          _syncExerciseDelete(id);

          await _checkWorkoutCompletion(workoutId: workoutId);
          
          if (_shouldSyncCycle(updatedCycle)) {
            _syncCycle(updatedCycle);
          }
          found = true;
          break;
        }
      }
      if (found) break;
    }
  }

  Future<void> _syncExerciseDelete(String id) async {
    try {
      await _cloudRepo.deleteExercise(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (_) {}
  }

  Future<void> deleteCycle(String id) async {
    if (_localRepo == null) return;
    
    final cycle = _cycles.firstWhere((c) => c.id == id, orElse: () => null as dynamic);
    if (cycle.isDefault && cycle.status == CycleStatus.template) {
      debugPrint("CycleProvider: Blocked deletion of a locked Default Blueprint.");
      return;
    }

    _cycles.removeWhere((c) => c.id == id);
    _rebuildCaches();
    notifyListeners();

    await _localRepo!.deleteCycle(id);
    await _localRepo!.addToDeletionQueue(id, 'hit_cycles');
    _syncCycleDelete(id);
  }

  Future<void> _syncCycleDelete(String id) async {
    try {
      await _cloudRepo.deleteCycle(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Cycle Delete): $e");
    }
  }

  Future<void> finishCycle(String cycleId) async {
    if (_localRepo == null) return;
    
    final index = _cycles.indexWhere((c) => c.id == cycleId);
    if (index != -1) {
      final finishedCycle = _cycles[index].copyWith(
        status: CycleStatus.finished,
        completedAt: () => DateTime.now(),
        isSynced: 0
      );
      _cycles[index] = finishedCycle;
      
      await _localRepo!.insertCycle(finishedCycle);
      _syncCycle(finishedCycle);
      
      _rebuildCaches();
      notifyListeners();
      debugPrint("CycleProvider: Cycle '$cycleId' marked as FINISHED.");
    }
  }

  Future<void> addExerciseLog(ExerciseLog log) async {
    if (_localRepo == null) return;
    final localLog = log.copyWith(isSynced: 0);

    _logs.insert(0, localLog);
    notifyListeners();
    await _localRepo!.insertLog(localLog);
    _syncExerciseLog(localLog);
  }

  Future<void> _syncExerciseLog(ExerciseLog log) async {
    try {
      debugPrint("CycleProvider: Attempting Cloud Sync for Log: ${log.id}");
      await _cloudRepo.insertLog(log);
      debugPrint("CycleProvider: Cloud Sync Success for Log: ${log.id}");
      await _localRepo!.markLogSynced(log.id);
      
      // Update in-memory sync status
      final idx = _logs.indexWhere((l) => l.id == log.id);
      if (idx != -1) {
        _logs[idx] = _logs[idx].copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("CycleProvider: Cloud Sync Failed for Log: ${log.id} - Error: $e");
    }
  }

  Future<void> upsertExerciseLog(ExerciseLog log) async {
    if (_localRepo == null) return;
    
    // 1. OPTIMISTIC UPDATE
    final localLog = log.copyWith(
      isSynced: 0,
      updatedAt: DateTime.now(),
    );
    final index = _logs.indexWhere((l) => l.id == localLog.id);
    if (index != -1) {
      _logs[index] = localLog;
    } else {
      _logs.insert(0, localLog);
      _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    
    notifyListeners();

    // 2. PERSIST LOCAL
    await _localRepo!.insertLog(localLog); 

    // 3. BACKGROUND SYNC
    await _syncExerciseLog(localLog);

    // 4. CHECK COMPLETION (Updates UI via _updateWorkoutInCycle)
    await _checkWorkoutCompletion(exerciseId: localLog.exerciseId);
  }

  Future<void> deleteExerciseLog(String logId) async {
    if (_localRepo == null) return;
    
    final logIdx = _logs.indexWhere((l) => l.id == logId);
    if (logIdx != -1) {
      final log = _logs[logIdx];
      final exId = log.exerciseId;
      _logs.removeAt(logIdx);
      notifyListeners();
      
      await _localRepo!.deleteLog(logId);
      await _localRepo!.addToDeletionQueue(logId, 'exercise_logs');
      _syncExerciseLogDelete(logId);
      
      // Check if workout completion status needs to change
      await _checkWorkoutCompletion(exerciseId: exId);
    }
  }

  Future<void> _syncExerciseLogDelete(String id) async {
    try {
      await _cloudRepo.deleteLog(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Exercise Log Delete): $e");
    }
  }

  Future<void> _checkWorkoutCompletion({String? exerciseId, String? workoutId}) async {
    try {
      Workout? targetWorkout;
      TrainingCycle? targetCycle;
      
      // 1. Locate the specific Workout/Cycle
      if (workoutId != null) {
        for (var c in _cycles) {
          final wIdx = c.workouts.indexWhere((w) => w.id == workoutId);
          if (wIdx != -1) {
            targetWorkout = c.workouts[wIdx];
            targetCycle = c;
            break;
          }
        }
      } else if (exerciseId != null) {
        final active = activeCycle;
        if (active != null) {
          for (var w in active.workouts) {
            if (w.exercises.any((e) => e.id == exerciseId)) {
              targetWorkout = w;
              targetCycle = active;
              break;
            }
          }
        }

        // If not in active cycle, search everywhere (Fallback)
        if (targetWorkout == null) {
          for (var c in _cycles) {
            for (var w in c.workouts) {
              if (w.exercises.any((e) => e.id == exerciseId)) {
                targetWorkout = w;
                targetCycle = c;
                break;
              }
            }
            if (targetWorkout != null) break;
          }
        }
      }

      if (targetWorkout == null || targetCycle == null) {
        debugPrint("CycleProvider: Target workout/cycle not found for instance ID $exerciseId");
        return;
      }
      
      final currentTargetCycle = targetCycle;
      final currentTargetWorkout = targetWorkout;

      bool allExercisesFinished = true;
      for (var ex in currentTargetWorkout.exercises) {
        // Find latest log for THIS specific exercise instance ID
        final exLogs = _logs.where((l) => l.exerciseId == ex.id).toList();
        
        bool hasValidLog = false;
        for (var l in exLogs) {
          // A valid HIT set must have a base load (Weight) AND at least one intensifier value
          final hasBaseLoad = l.weightKg > 0 || l.weightLbs > 0;
          final hasIntensifier = l.positiveReps > 0 || 
                               l.staticHoldSeconds > 0 || 
                               l.negativeReps > 0 || 
                               l.forcedReps > 0;
          
          if (hasBaseLoad && hasIntensifier) {
            hasValidLog = true;
            break;
          }
        }
        
        if (!hasValidLog) {
          allExercisesFinished = false;
          break;
        }
      }

      final bool isCurrentlyCompleted = currentTargetWorkout.status == WorkoutStatus.completed;

      if (allExercisesFinished && currentTargetWorkout.exercises.isNotEmpty) {
        // --- 1. POTENTIAL COMPLETION ---
        // A workout is complete ONLY if all exercises are done.
        if (!isCurrentlyCompleted) {
          debugPrint("CycleProvider: All exercises finished. Updating workout '${currentTargetWorkout.name}' to COMPLETED.");
          
          DateTime? autoDate = currentTargetWorkout.completedAt;

          // SMART AUTO WORKOUT DATE LOG:
          if (_settings.smartAutoDateEnabled && autoDate == null) {
            final now = DateTime.now();
            bool hasWorkoutToday = false;

            // Check across ALL workouts in ALL cycles (current or previous)
            for (var c in _cycles) {
              for (var w in c.workouts) {
                if (w.id == currentTargetWorkout.id) continue;

                if (w.completedAt != null) {
                  final d = w.completedAt!;
                  if (d.year == now.year && d.month == now.month && d.day == now.day) {
                    hasWorkoutToday = true;
                    break;
                  }
                }
              }
              if (hasWorkoutToday) break;
            }

            if (!hasWorkoutToday) {
              autoDate = now;
              debugPrint("CycleProvider: Smart Auto Date applied today's date ($now) to '${currentTargetWorkout.name}'.");
            } else {
              debugPrint("CycleProvider: Smart Auto Date skipped setting today's date because another workout is already logged for today.");
            }
          }

          final updatedWorkout = currentTargetWorkout.copyWith(
            status: WorkoutStatus.completed,
            completedAt: autoDate != null ? () => autoDate : null,
          );
          await _updateWorkoutInCycle(currentTargetCycle, updatedWorkout);
        }
      } 
      else if ((!allExercisesFinished || currentTargetWorkout.exercises.isEmpty) && isCurrentlyCompleted) {
        // --- 2. REVERT TO PENDING ---
        debugPrint("CycleProvider: Exercise removed or invalidated. Reverting workout '${currentTargetWorkout.name}' to PENDING.");
        final updatedWorkout = currentTargetWorkout.copyWith(
          status: WorkoutStatus.pending,
          // We keep the date even if it reverts to pending, as it might have been set manually
        );

        final cIdx = _cycles.indexWhere((c) => c.id == currentTargetCycle.id);
        if (cIdx != -1) {
          final updatedWorkouts = List<Workout>.from(_cycles[cIdx].workouts);
          final wIdx = updatedWorkouts.indexWhere((w) => w.id == updatedWorkout.id);
          if (wIdx != -1) {
            updatedWorkouts[wIdx] = updatedWorkout;
          }

          TrainingCycle updatedCycle = _cycles[cIdx].copyWith(
            workouts: updatedWorkouts,
            isSynced: 0,
          );

          // If the cycle was already FINISHED, it now becomes INCOMPLETE because a workout was invalidated
          if (updatedCycle.status == CycleStatus.finished) {
            updatedCycle = updatedCycle.copyWith(status: CycleStatus.incomplete);
            debugPrint("CycleProvider: Cycle '${updatedCycle.id}' status reverted to INCOMPLETE.");
          }

          _cycles[cIdx] = updatedCycle;
          _rebuildCaches();
          notifyListeners();

          await _localRepo!.insertCycle(updatedCycle);
          _syncCycle(updatedCycle);
        }
      }
    } catch (e) {
      debugPrint("CycleProvider Error in _checkWorkoutCompletion: $e");
    }
  }

  Future<void> _updateWorkoutInCycle(TrainingCycle targetCycle, Workout updatedWorkout) async {
    // 1. UPDATE MEMORY IMMEDIATELY
    final cIdx = _cycles.indexWhere((c) => c.id == targetCycle.id);
    if (cIdx != -1) {
      final wIdx = _cycles[cIdx].workouts.indexWhere((w) => w.id == updatedWorkout.id);
      if (wIdx != -1) {
        final now = DateTime.now();
        final updatedWorkouts = List<Workout>.from(_cycles[cIdx].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        
        // IMPORTANT: Mark the parent cycle as unsynced so the whole sequence is updated
        _cycles[cIdx] = _cycles[cIdx].copyWith(
          workouts: updatedWorkouts,
          isSynced: 0,
          updatedAt: now,
        );
        
        _rebuildCaches();
        notifyListeners();

        // 2. SAVE LOCAL (Both workout and parent cycle)
        await _localRepo!.insertWorkout(updatedWorkout);
        await _localRepo!.insertCycle(_cycles[cIdx]);
        
        // 3. SYNC CLOUD
        if (_shouldSyncCycle(_cycles[cIdx])) {
          await _syncCycle(_cycles[cIdx]);
        }
      }
    }
  }

  /// Calculates the allowed date range for a specific workout based on its position in the overall training sequence.
  Map<String, DateTime?> getWorkoutDateRange(String workoutId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 1. Find target workout and its cycle
    Workout? targetWorkout;
    TrainingCycle? targetCycle;
    for (var c in _cycles) {
      final w = c.workouts.cast<Workout?>().firstWhere((w) => w?.id == workoutId, orElse: () => null);
      if (w != null) {
        targetWorkout = w;
        targetCycle = c;
        break;
      }
    }

    if (targetWorkout == null || targetCycle == null) return {'min': null, 'max': today};

    // 2. Identify all "active" tracking cycles (non-templates) and sort by chronological start
    final List<TrainingCycle> timelineCycles = _cycles
        .where((c) => c.status != CycleStatus.template)
        .toList();
    
    timelineCycles.sort((a, b) {
      if (a.startedAt == null && b.startedAt == null) return 0;
      if (a.startedAt == null) return 1;
      if (b.startedAt == null) return -1;
      return a.startedAt!.compareTo(b.startedAt!);
    });

    // 3. Create a flattened sequence of all workouts across the timeline
    final List<Workout> flattenedWorkouts = [];
    for (var cycle in timelineCycles) {
      final sortedWorkouts = List<Workout>.from(cycle.workouts)..sort((a, b) => a.order.compareTo(b.order));
      flattenedWorkouts.addAll(sortedWorkouts);
    }

    // 4. Find current workout position
    final int targetIdx = flattenedWorkouts.indexWhere((w) => w.id == workoutId);
    if (targetIdx == -1) return {'min': null, 'max': today};

    DateTime? minDate;
    DateTime? maxDate = today;

    // 5. Look for PREVIOUS neighbor with a date
    for (int i = targetIdx - 1; i >= 0; i--) {
      if (flattenedWorkouts[i].completedAt != null) {
        minDate = flattenedWorkouts[i].completedAt!.add(const Duration(days: 1));
        break;
      }
    }

    // 6. Look for NEXT neighbor with a date
    for (int i = targetIdx + 1; i < flattenedWorkouts.length; i++) {
      if (flattenedWorkouts[i].completedAt != null) {
        final neighborDate = flattenedWorkouts[i].completedAt!;
        final possibleMax = neighborDate.subtract(const Duration(days: 1));
        if (maxDate == null || possibleMax.isBefore(maxDate)) {
          maxDate = possibleMax;
        }
        break;
      }
    }

    // Handle edge case where next workout is on the same day as previous (shouldn't happen with +1 logic but for safety)
    if (minDate != null && maxDate != null && minDate.isAfter(maxDate)) {
      // If the window is impossible, we return the neighbors themselves to let showDatePicker handle it or show error
    }

    return {'min': minDate, 'max': maxDate};
  }

  Future<void> updateWorkoutDate(String workoutId, DateTime? date) async {
    if (_localRepo == null) return;
    debugPrint("CycleProvider: Updating Workout $workoutId Date to: $date");

    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == workoutId);
      if (wIdx != -1) {
        final targetWorkout = _cycles[i].workouts[wIdx];
        
        // 1. Update the date
        final updatedWorkout = targetWorkout.copyWith(
          completedAt: () => date,
          isSynced: 0,
          updatedAt: DateTime.now(),
        );

        debugPrint("CycleProvider: Workout Status remains: ${updatedWorkout.status}");

        await _updateWorkoutInCycle(_cycles[i], updatedWorkout);

        // 2. Cascade timestamp update to associated ExerciseLogs
        final exerciseIds = targetWorkout.exercises.map((e) => e.id).toSet();
        if (exerciseIds.isNotEmpty) {
          for (int j = 0; j < _logs.length; j++) {
            if (exerciseIds.contains(_logs[j].exerciseId)) {
              final oldLog = _logs[j];
              DateTime newTimestamp;
              if (date != null) {
                newTimestamp = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  oldLog.timestamp.hour,
                  oldLog.timestamp.minute,
                  oldLog.timestamp.second,
                );
              } else {
                newTimestamp = oldLog.timestamp;
              }

              final updatedLog = oldLog.copyWith(
                timestamp: () => newTimestamp,
                isSynced: 0,
                updatedAt: DateTime.now(),
              );
              _logs[j] = updatedLog;
              await _localRepo!.insertLog(updatedLog);
            }
          }
          _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          _syncLocalToCloud();
        }

        // 3. Re-check if the workout should be "Completed" based on exercises
        await _checkWorkoutCompletion(workoutId: workoutId);
        break;
      }
    }
  }

  Future<void> updateWorkoutOrder(String cycleId, List<Workout> workouts) async {
    if (_localRepo == null) return;
    
    final idx = _cycles.indexWhere((c) => c.id == cycleId);
    if (idx != -1) {
      // LOCK check
      if (_cycles[idx].isDefault && _cycles[idx].status == CycleStatus.template) {
        debugPrint("CycleProvider: Blocked reordering of a locked Default Blueprint.");
        return;
      }

      await _markCycleAsModified(cycleId);

      final updatedWorkouts = workouts.asMap().entries.map((entry) {
        return entry.value.copyWith(order: entry.key);
      }).toList();
      
      final updatedCycle = _cycles[idx].copyWith(workouts: updatedWorkouts, isSynced: 0);
      _cycles[idx] = updatedCycle;
      _rebuildCaches();
      notifyListeners();
      
      await _localRepo!.insertCycle(updatedCycle);
      if (_shouldSyncCycle(updatedCycle)) {
        _syncCycle(updatedCycle);
      }
    }
  }

  Future<void> updateWorkoutName(String workoutId, String newName) async {
    if (_localRepo == null) return;
    
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == workoutId);
      if (wIdx != -1) {
        // LOCK check
        if (_cycles[i].isDefault && _cycles[i].status == CycleStatus.template) {
          debugPrint("CycleProvider: Blocked name update of a locked Default Blueprint.");
          return;
        }

        await _markCycleAsModified(_cycles[i].id);

        final now = DateTime.now();
        final updatedWorkout = _cycles[i].workouts[wIdx].copyWith(
          name: newName.toUpperCase(),
          isSynced: 0,
          updatedAt: now,
        );
        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        
        _cycles[i] = _cycles[i].copyWith(
          workouts: updatedWorkouts, 
          isSynced: 0,
          updatedAt: now,
        );
        _rebuildCaches();
        notifyListeners();
        
        await _localRepo!.insertWorkout(updatedWorkout);
        if (_shouldSyncCycle(_cycles[i])) {
          await _syncWorkout(updatedWorkout);
        }
        break;
      }
    }
  }

  Future<void> updateWorkoutNote(String workoutId, String note) async {
    if (_localRepo == null) return;
    
    // 1. OPTIMISTIC UPDATE
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == workoutId);
      if (wIdx != -1) {
        final updatedWorkout = _cycles[i].workouts[wIdx].copyWith(note: note);
        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        
        _cycles[i] = _cycles[i].copyWith(workouts: updatedWorkouts, isSynced: 0);
        _rebuildCaches();
        notifyListeners();
        
        // 2. PERSIST LOCAL & SYNC
        await _localRepo!.insertWorkout(updatedWorkout.copyWith(isSynced: 0));
        if (_shouldSyncCycle(_cycles[i])) {
          _syncWorkout(updatedWorkout);
        }
        break;
      }
    }
  }

  Future<void> _syncWorkout(Workout workout) async {
    try {
      await _cloudRepo.insertWorkout(workout);
      await _localRepo!.markWorkoutSynced(workout.id);
    } catch (_) {}
  }

  Future<void> updateCycleNote(String cycleId, String note) async {
    if (_localRepo == null) return;
    
    // 1. OPTIMISTIC UPDATE
    final index = _cycles.indexWhere((c) => c.id == cycleId);
    if (index != -1) {
      final updatedCycle = _cycles[index].copyWith(note: note, isSynced: 0);
      _cycles[index] = updatedCycle;
      
      _rebuildCaches();
      notifyListeners();

      // 2. PERSIST LOCAL
      await _localRepo!.insertCycle(updatedCycle);
      
      // 3. SYNC
      _syncCycle(updatedCycle);
    }
  }

  Future<void> updateCycleName(String cycleId, String newName) async {
    if (_localRepo == null) return;
    
    final index = _cycles.indexWhere((c) => c.id == cycleId);
    if (index != -1) {
      // LOCK check
      if (_cycles[index].isDefault && _cycles[index].status == CycleStatus.template) {
        debugPrint("CycleProvider: Blocked name update of a locked Default Blueprint.");
        return;
      }

      await _markCycleAsModified(cycleId);

      final updatedCycle = _cycles[index].copyWith(name: newName.toUpperCase(), isSynced: 0);
      _cycles[index] = updatedCycle;
      
      _rebuildCaches();
      notifyListeners();

      await _localRepo!.insertCycle(updatedCycle);
      if (_shouldSyncCycle(updatedCycle)) {
        _syncCycle(updatedCycle);
      }
    }
  }

  Future<void> updateSettings(CycleSettings settings) async {
    if (_localRepo == null) return;
    final localSettings = settings.copyWith(isSynced: 0);
    _settings = localSettings;
    notifyListeners();
    await _localRepo!.saveSettings(localSettings.toMap());
    _syncSettings(localSettings);
  }

  Future<void> _syncSettings(CycleSettings settings) async {
    try {
      await _cloudRepo.saveSettings(settings.toMap());
      await _localRepo!.markSettingsSynced();
      if (_settings.isSynced == 0) {
        _settings = _settings.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Cycle Settings): $e");
    }
  }

  Future<void> renameExerciseGlobally(String oldName, String newName) async {
    if (_localRepo == null) return;
    
    bool changed = false;
    final upperOld = oldName.trim().toUpperCase();
    final upperNew = newName.trim().toUpperCase();

    if (upperOld == upperNew) return;

    // 1. Update in memory
    for (int i = 0; i < _cycles.length; i++) {
      final updatedWorkouts = _cycles[i].workouts.map((workout) {
        final updatedExercises = workout.exercises.map((exercise) {
          if (exercise.name.trim().toUpperCase() == upperOld) {
            changed = true;
            return exercise.copyWith(name: upperNew, isSynced: 0);
          }
          return exercise;
        }).toList();
        return workout.copyWith(exercises: updatedExercises);
      }).toList();
      
      if (changed) {
        _cycles[i] = _cycles[i].copyWith(workouts: updatedWorkouts);
      }
    }

    if (changed) {
      _rebuildCaches();
      notifyListeners();

      // 2. Update in Local DB
      await _localRepo!.renameExerciseGlobally(upperOld, upperNew);

      // 3. Trigger Sync for affected exercises
      // We loop through all exercises in memory that were changed and sync them
      for (var cycle in _cycles) {
        for (var workout in cycle.workouts) {
          for (var exercise in workout.exercises) {
            if (exercise.name == upperNew && exercise.isSynced == 0) {
               _cloudRepo.insertExercise(exercise).then((_) {
                 _localRepo?.markExerciseSynced(exercise.id);
               }).catchError((_) {});
            }
          }
        }
      }
    }
  }

  // --- Conversion Helpers ---
  static const double _kgToLbsMultiplier = 2.205;

  double getWeightForDisplay(ExerciseLog log) {
    return _settings.weightUnit == WeightUnit.kgs ? log.weightKg : log.weightLbs;
  }

  // Use this when the user is typing a value in the current unit
  // Returns a Map with both values calculated and truncated to 3 decimals
  Map<String, double> calculateDualWeights(double inputValue) {
    // 1. Convert input to string with high precision, then truncate to exactly 3 decimals
    String inputStr = inputValue.toStringAsFixed(10);
    int dotIdx = inputStr.indexOf('.');
    double cleanInput = double.parse(inputStr.substring(0, dotIdx + 4));

    if (_settings.weightUnit == WeightUnit.kgs) {
      double rawLbs = cleanInput * _kgToLbsMultiplier;
      String lbsStr = rawLbs.toStringAsFixed(10);
      int lbsDotIdx = lbsStr.indexOf('.');
      
      return {
        'kg': cleanInput,
        'lbs': double.parse(lbsStr.substring(0, lbsDotIdx + 4)),
      };
    } else {
      double rawKg = cleanInput / _kgToLbsMultiplier;
      String kgStr = rawKg.toStringAsFixed(10);
      int kgDotIdx = kgStr.indexOf('.');

      return {
        'kg': double.parse(kgStr.substring(0, kgDotIdx + 4)),
        'lbs': cleanInput,
      };
    }
  }

  double convertToDisplay(double valueInLbs) {
    if (_settings.weightUnit == WeightUnit.kgs) {
      return valueInLbs / _kgToLbsMultiplier;
    }
    return valueInLbs;
  }

  Future<void> updateExerciseOrder(String workoutId, List<Exercise> exercises) async {
    if (_localRepo == null) return;
    
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == workoutId);
      if (wIdx != -1) {
        // LOCK check
        if (_cycles[i].isDefault && _cycles[i].status == CycleStatus.template) {
          debugPrint("CycleProvider: Blocked reordering of a locked Default Blueprint.");
          return;
        }

        await _markCycleAsModified(_cycles[i].id);

        final updatedExercises = exercises.asMap().entries.map((entry) {
          return entry.value.copyWith(order: entry.key);
        }).toList();
        
        final updatedWorkout = _cycles[i].workouts[wIdx].copyWith(exercises: updatedExercises);
        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        
        final updatedCycle = _cycles[i].copyWith(workouts: updatedWorkouts, isSynced: 0);
        _cycles[i] = updatedCycle;
        _rebuildCaches();
        notifyListeners();
        
        await _localRepo!.insertCycle(updatedCycle);
        if (!updatedCycle.isDefault) {
          _syncCycle(updatedCycle);
        }
        break;
      }
    }
  }

  double calculateCyclePerformance(String cycleId) {
    final cycle = _cycles.firstWhere((c) => c.id == cycleId, orElse: () => TrainingCycle(name: "None"));
    if (cycle.id.isEmpty || cycle.startedAt == null) return 0.0;

    double totalGrowth = 0.0;
    int exerciseCount = 0;

    for (var workout in cycle.workouts) {
      for (var exercise in workout.exercises) {
        // Filter logs specifically to this cycle's timeframe
        final cycleLogs = _logs.where((l) {
          final cachedName = getExerciseName(l.exerciseId);
          final bool isSameExercise = cachedName?.trim().toUpperCase() == exercise.name.trim().toUpperCase();
          final bool isWithinCycle = l.timestamp.isAfter(cycle.startedAt!) || l.timestamp.isAtSameMomentAs(cycle.startedAt!);
          return isSameExercise && isWithinCycle;
        }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        if (cycleLogs.length < 2) continue;

        // Compare first session of THIS cycle with latest session of THIS cycle
        final baseline = cycleLogs.first.weightKg * cycleLogs.first.positiveReps;
        final latest = cycleLogs.last.weightKg * cycleLogs.last.positiveReps;

        if (baseline > 0) {
          totalGrowth += (latest / baseline) - 1;
          exerciseCount++;
        }
      }
    }

    return exerciseCount > 0 ? totalGrowth / exerciseCount : 0.0;
  }

  // --- Progression Analysis: Strength (Brzycki) & Volume ---

  double _calculateBrzycki1RM(double weight, int reps) {
    if (weight <= 0 || reps <= 0) return 0.0;
    // Brzycki Formula: 1RM = Weight / (1.0278 - (0.0278 * Reps))
    // Note: Formula is most accurate for reps < 10, but we use it as a general strength estimator.
    return weight / (1.0278 - (0.0278 * reps));
  }

  double _calculateVolume(double weight, int reps) {
    return weight * reps;
  }

  /// Returns a map with 'strength' and 'volume' progression percentages.
  Map<String, double> calculateExerciseProgression(String exerciseName, {String? targetCycleId, String? exerciseId}) {
    if (exerciseId != null) {
      final instanceLogs = _logs.where((l) => l.exerciseId == exerciseId && (l.weightKg > 0 || l.weightLbs > 0) && l.positiveReps > 0).toList();
      if (instanceLogs.isEmpty) {
        return {"strength": 0.0, "volume": 0.0};
      }
    }

    final allLogs = _logs.where((l) {
      final cachedName = getExerciseName(l.exerciseId);
      if (cachedName?.trim().toUpperCase() != exerciseName.trim().toUpperCase()) return false;
      final workout = getWorkoutForExercise(l.exerciseId);
      return workout != null && workout.completedAt != null;
    }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (allLogs.isEmpty) return {"strength": 0.0, "volume": 0.0};

    final List<TrainingCycle> relevantCycles = _cycles.where((c) {
      return c.workouts.any((w) => w.exercises.any((e) => e.name.trim().toUpperCase() == exerciseName.trim().toUpperCase()));
    }).toList()..sort((a, b) => (a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

    if (relevantCycles.isEmpty) return {"strength": 0.0, "volume": 0.0};

    int targetIdx = relevantCycles.length - 1;
    if (targetCycleId != null) {
      targetIdx = relevantCycles.indexWhere((c) => c.id == targetCycleId);
    }

    if (targetIdx <= 0) return {"strength": 0.0, "volume": 0.0};

    final targetCycle = relevantCycles[targetIdx];

    ExerciseLog? latestLog;
    if (exerciseId != null) {
      final instanceLogs = _logs.where((l) => l.exerciseId == exerciseId && (l.weightKg > 0 || l.weightLbs > 0) && l.positiveReps > 0).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (instanceLogs.isNotEmpty) {
        latestLog = instanceLogs.last;
      }
    }

    if (latestLog == null) {
      final targetCycleLogs = allLogs.where((l) {
        return targetCycle.workouts.any((w) => w.exercises.any((e) => e.id == l.exerciseId));
      }).toList();

      if (targetCycleLogs.isEmpty) return {"strength": 0.0, "volume": 0.0};
      latestLog = targetCycleLogs.last;
    }

    final previousCycle = relevantCycles[targetIdx - 1];
    final previousCycleLogs = allLogs.where((l) {
      return previousCycle.workouts.any((w) => w.exercises.any((e) => e.id == l.exerciseId));
    }).toList();

    if (previousCycleLogs.isEmpty) return {"strength": 0.0, "volume": 0.0};
    final baselineLog = previousCycleLogs.last;

    if (latestLog.weightKg <= 0 || latestLog.positiveReps <= 0 || baselineLog.weightKg <= 0 || baselineLog.positiveReps <= 0) {
      return {"strength": 0.0, "volume": 0.0};
    }

    // Strength (Brzycki)
    final double current1RM = _calculateBrzycki1RM(latestLog.weightKg, latestLog.positiveReps);
    final double baseline1RM = _calculateBrzycki1RM(baselineLog.weightKg, baselineLog.positiveReps);
    final double strengthProg = (current1RM / baseline1RM) - 1;

    // Volume
    final double currentVol = _calculateVolume(latestLog.weightKg, latestLog.positiveReps);
    final double baselineVol = _calculateVolume(baselineLog.weightKg, baselineLog.positiveReps);
    final double volumeProg = (currentVol / baselineVol) - 1;

    return {
      "strength": strengthProg,
      "volume": volumeProg,
    };
  }

  Map<String, double> calculateWorkoutProgression(Workout workout, {String? targetCycleId}) {
    double totalStrength = 0.0;
    double totalVolume = 0.0;
    
    for (var exercise in workout.exercises) {
      final prog = calculateExerciseProgression(exercise.name, targetCycleId: targetCycleId ?? workout.cycleId, exerciseId: exercise.id);
      totalStrength += prog['strength']!;
      totalVolume += prog['volume']!;
    }
    
    return {
      "strength": totalStrength,
      "volume": totalVolume,
    };
  }

  Map<String, double> calculateCycleProgression(String cycleId) {
    final cycle = _cycles.firstWhere((c) => c.id == cycleId, orElse: () => TrainingCycle(name: ""));
    if (cycle.id.isEmpty) return {"strength": 0.0, "volume": 0.0};

    double totalStrength = 0.0;
    double totalVolume = 0.0;
    
    for (var workout in cycle.workouts) {
      final prog = calculateWorkoutProgression(workout, targetCycleId: cycleId);
      totalStrength += prog['strength']!;
      totalVolume += prog['volume']!;
    }
    
    return {
      "strength": totalStrength,
      "volume": totalVolume,
    };
  }

  // --- UI Compatibility Overrides (Maintains existing single-value calls if any) ---

  double calculateExerciseProgress(String exerciseName, {String? targetCycleId}) {
    return calculateExerciseProgression(exerciseName, targetCycleId: targetCycleId)['strength']!;
  }

  double calculateWorkoutProgress(Workout workout, {String? targetCycleId}) {
    return calculateWorkoutProgression(workout, targetCycleId: targetCycleId)['strength']!;
  }

  double calculateCycleProgress(String cycleId) {
    return calculateCycleProgression(cycleId)['strength']!;
  }

  Future<void> _initializeRuggedDefaults() async {
    if (_localRepo == null) return;

    // Ideal Routine
    const idealCycleId = "rugged_ideal_routine";
    final idealCycle = TrainingCycle(
      id: idealCycleId,
      name: "IDEAL ROUTINE", 
      description: "4 SESSIONS • THE CLASSIC HIT PROTOCOL", 
      isDefault: true,
      isSynced: 1, 
      updatedAt: DateTime.now(),
      workouts: [
        _createDefaultWorkout(idealCycleId, "rugged_ideal_w1", "WORKOUT ONE: CHEST & BACK", 0, [
          "Dumbbell Flyes", 
          "Incline Presses", 
          "Straight-Arm Lat Machine Pulldowns", 
          "Palms-Up Pulldowns", 
          "Deadlifts"
        ]),
        _createDefaultWorkout(idealCycleId, "rugged_ideal_w2", "WORKOUT TWO: LEGS & ABS", 1, [
          "Leg Extensions", 
          "Leg Presses", 
          "Standing Calf Raises", 
          "Sit-Ups"
        ]),
        _createDefaultWorkout(idealCycleId, "rugged_ideal_w3", "WORKOUT THREE: SHOULDERS & ARMS", 2, [
          "Dumbbell Lateral Raises", 
          "Bent-Over Dumbbell Laterals", 
          "Palms-Up Pulldowns", 
          "Triceps Pressdowns", 
          "Dips"
        ]),
        _createDefaultWorkout(idealCycleId, "rugged_ideal_w4", "WORKOUT FOUR: LEGS & ABS", 3, [
          "Leg Extensions", 
          "Leg Presses", 
          "Standing Calf Raises", 
          "Sit-Ups"
        ]),
      ],
    );

    await _localRepo!.insertCycle(idealCycle);

    // Consolidated Routine
    const consolidatedCycleId = "rugged_consolidated_routine";
    final consolidatedCycle = TrainingCycle(
      id: consolidatedCycleId,
      name: "CONSOLIDATED", 
      description: "2 SESSIONS • MAX RECOVERY", 
      isDefault: true,
      isSynced: 1, 
      updatedAt: DateTime.now(),
      workouts: [
        _createDefaultWorkout(consolidatedCycleId, "rugged_cons_w1", "WORKOUT ONE", 0, [
          "Squats", 
          "Palms-Up Pulldowns", 
          "Dips"
        ]),
        _createDefaultWorkout(consolidatedCycleId, "rugged_cons_w2", "WORKOUT TWO", 1, [
          "Deadlifts", 
          "Press Behind Neck", 
          "Standing Calf Raises"
        ]),
      ],
    );

    await _localRepo!.insertCycle(consolidatedCycle);

    // Beginner Routine
    const beginnerCycleId = "rugged_beginner_routine";
    final beginnerExercises = [
      "Squats", 
      "Barbell Rows", 
      "Bench Press", 
      "Press Behind Neck", 
      "Deadlifts", 
      "Standing Barbell Curls", 
      "Standing Calf Raises", 
      "Sit-Ups"
    ];

    final beginnerCycle = TrainingCycle(
      id: beginnerCycleId,
      name: "BEGINNER ROUTINE",
      description: "5 DAYS • FUNDAMENTAL HIT MOVEMENTS",
      isDefault: true,
      isSynced: 1,
      updatedAt: DateTime.now(),
      workouts: List.generate(5, (i) => _createDefaultWorkout(
        beginnerCycleId, 
        "rugged_beg_w${i + 1}", 
        "DAY ${i + 1}", 
        i, 
        beginnerExercises
      )),
    );

    await _localRepo!.insertCycle(beginnerCycle);

    // Productive Routine
    const productiveCycleId = "rugged_productive_routine";
    final productiveCycle = TrainingCycle(
      id: productiveCycleId,
      name: "PRODUCTIVE ROUTINE",
      description: "2 SESSIONS • HIGH INTENSITY SUPERSETS",
      isDefault: true,
      isSynced: 1,
      updatedAt: DateTime.now(),
      workouts: [
        _createDefaultWorkout(productiveCycleId, "rugged_prod_w1", "WORKOUT ONE (MONDAY)", 0, [
          "Leg Extensions",
          "Squats",
          "Leg Curls",
          "Standing Calf Raises",
          "Toe Presses",
          "Dumbbell Flyes",
          "Incline Presses",
          "Dips",
          "Triceps Pressdowns",
          "Dips",
          "Lying Triceps Extensions"
        ]),
        _createDefaultWorkout(productiveCycleId, "rugged_prod_w2", "WORKOUT TWO (WEDNESDAY)", 1, [
          "Nautilus Machine Pullovers",
          "Palms-Up Pulldowns",
          "Barbell Rows",
          "Shrugs",
          "Upright Rows",
          "Dumbbell Lateral Raises",
          "Machine Presses",
          "One-Arm Dumbbell Rows",
          "Standing Barbell Curls",
          "Concentration Curls"
        ]),
      ],
    );

    await _localRepo!.insertCycle(productiveCycle);

    // One-Set Intensity Routine
    const dorianCycleId = "rugged_dorian_yates_routine";
    final dorianCycle = TrainingCycle(
      id: dorianCycleId,
      name: "ONE-SET INTENSITY ROUTINE",
      description: "3 SESSIONS • THE HIGH INTENSITY PROTOCOL",
      isDefault: true,
      isSynced: 1,
      updatedAt: DateTime.now(),
      workouts: [
        _createDefaultWorkout(dorianCycleId, "rugged_dorian_w1", "MONDAY'S WORKOUT", 0, [
          "Dumbbell Flyes",
          "Incline Presses",
          "Dumbbell Lateral Raises",
          "Bent-Over Dumbbell Laterals",
          "Triceps Pressdowns",
          "Dips"
        ]),
        _createDefaultWorkout(dorianCycleId, "rugged_dorian_w2", "WEDNESDAY'S WORKOUT", 1, [
          "Nautilus Machine Pullovers",
          "Palms-Up Pulldowns",
          "Barbell Rows",
          "Shrugs",
          "Preacher Curls",
          "Concentration Curls"
        ]),
        _createDefaultWorkout(dorianCycleId, "rugged_dorian_w3", "FRIDAY'S WORKOUT", 2, [
          "Leg Extensions",
          "Leg Presses",
          "Squats",
          "Leg Curls",
          "Deadlifts",
          "Standing Calf Raises"
        ]),
      ],
    );

    await _localRepo!.insertCycle(dorianCycle);
  }

  Workout _createDefaultWorkout(String cycleId, String workoutId, String name, int order, List<String> exerciseNames) {
    return Workout(
      id: workoutId,
      cycleId: cycleId,
      name: name,
      order: order,
      isSynced: 1,
      exercises: exerciseNames.asMap().entries.map((entry) {
        return Exercise(
          id: "${workoutId}_ex_${entry.key}", // Deterministic Exercise IDs
          workoutId: workoutId,
          name: entry.value,
          order: entry.key,
          isSynced: 1,
        );
      }).toList(),
    );
  }

  String? findMatchingTemplate(String cycleId) {
    final targetCycle = _cycles.firstWhere((c) => c.id == cycleId, orElse: () => TrainingCycle(name: ""));
    if (targetCycle.id.isEmpty) return null;

    final templates = _cycles.where((c) => c.status == CycleStatus.template).toList();
    
    for (var template in templates) {
      if (template.workouts.length != targetCycle.workouts.length) continue;
      
      bool allWorkoutsMatch = true;
      // Sort both by order to ensure we compare correctly
      final tWorkouts = [...template.workouts]..sort((a, b) => a.order.compareTo(b.order));
      final cWorkouts = [...targetCycle.workouts]..sort((a, b) => a.order.compareTo(b.order));

      for (int i = 0; i < tWorkouts.length; i++) {
        final tw = tWorkouts[i];
        final cw = cWorkouts[i];

        if (tw.exercises.length != cw.exercises.length) {
          allWorkoutsMatch = false;
          break;
        }

        final tEx = [...tw.exercises]..sort((a, b) => a.order.compareTo(b.order));
        final cEx = [...cw.exercises]..sort((a, b) => a.order.compareTo(b.order));

        for (int j = 0; j < tEx.length; j++) {
          if (tEx[j].name.trim().toUpperCase() != cEx[j].name.trim().toUpperCase()) {
            allWorkoutsMatch = false;
            break;
          }
        }
        if (!allWorkoutsMatch) break;
      }

      if (allWorkoutsMatch) return template.name;
    }
    return null;
  }

  Future<void> saveCycleAsTemplate(String cycleId, String name, String description) async {
    final cycle = _cycles.firstWhere((c) => c.id == cycleId);
    
    final templateId = const Uuid().v4();
    final template = TrainingCycle(
      id: templateId,
      name: name.toUpperCase(),
      description: description.isNotEmpty ? description.toUpperCase() : "CUSTOM ARCHITECTURE",
      status: CycleStatus.template,
      isDefault: false,
      isSynced: 0,
      workouts: cycle.workouts.map((w) {
        final nwId = const Uuid().v4();
        return w.copyWith(
          id: nwId,
          cycleId: templateId,
          status: WorkoutStatus.pending,
          completedAt: () => null,
          isSynced: 0,
          exercises: w.exercises.map((e) => e.copyWith(
            id: const Uuid().v4(),
            workoutId: nwId,
            isSynced: 0,
          )).toList(),
        );
      }).toList(),
    );

    await addCycle(template);
  }

  bool isUnmodifiedDefault(String cycleId) {
    final cycle = _cycles.firstWhere((c) => c.id == cycleId, orElse: () => TrainingCycle(name: ""));
    if (cycle.id.isEmpty) return false;

    // A cycle is an unmodified default if its structure matches one of the internal default routines
    final matchingName = findMatchingTemplate(cycleId);
    if (matchingName == null) return false;

    final systemNames = [
      "IDEAL ROUTINE", 
      "CONSOLIDATED", 
      "BEGINNER ROUTINE", 
      "PRODUCTIVE ROUTINE", 
      "MENTZER PRODUCTIVE ROUTINE",
      "ONE-SET INTENSITY ROUTINE",
      "ONE-SET HEAVY DUTY (DORIAN YATES)"
    ];
    
    return systemNames.contains(matchingName);
  }

  Future<String?> generateShareableLink(String cycleId, String userName) async {
    if (!AuthProvider().isPro) {
      debugPrint("CycleProvider: Sharing skipped - Pro status required.");
      return null;
    }

    final cycle = _cycles.firstWhere((c) => c.id == cycleId);
    
    final Map<String, dynamic> shareData = {
      'name': cycle.name,
      'description': cycle.description,
      'sender': userName,
      'workouts': cycle.workouts.map((w) => {
        'name': w.name,
        'order': w.order,
        'exercises': w.exercises.map((e) => {
          'name': e.name,
          'order': e.order,
          'target_muscles': e.targetMuscles,
        }).toList(),
      }).toList(),
    };

    try {
      final response = await _supabase.from('shared_data').insert({
        'data': shareData,
      }).select('id').single();

      final shareId = response['id'] as String;
      // Using the actual confirmed domain: affulabs.com/rugged
      return "https://affulabs.com/rugged/app/share/cycle?id=$shareId&from=${Uri.encodeComponent(userName)}";
    } catch (e) {
      debugPrint("Error generating share link: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSharedCycle(String shareId) async {
    try {
      final response = await _supabase
          .from('shared_data')
          .select()
          .eq('id', shareId)
          .single();
      
      final createdAt = DateTime.parse(response['created_at']);
      final now = DateTime.now();
      
      if (now.difference(createdAt).inDays >= 7) {
        return {'expired': true};
      }

      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error fetching shared cycle: $e");
      return null;
    }
  }

  Future<void> importSharedCycle(Map<String, dynamic> data) async {
    if (_localRepo == null) return;

    final String cycleName = (data['name'] as String).toUpperCase();
    final List workoutsData = data['workouts'] as List;

    final newCycleId = const Uuid().v4();
    final newCycle = TrainingCycle(
      id: newCycleId,
      name: "$cycleName (SHARED)",
      description: data['description'] ?? "SHARED HIT ROUTINE",
      status: CycleStatus.template,
      sharedBy: data['sender'] as String?,
      isDefault: false,
      isSynced: 0,
      workouts: workoutsData.asMap().entries.map((wEntry) {
        final w = wEntry.value;
        final nwId = const Uuid().v4();
        final List exercisesData = w['exercises'] as List;

        return Workout(
          id: nwId,
          cycleId: newCycleId,
          name: (w['name'] as String).toUpperCase(),
          order: wEntry.key,
          status: WorkoutStatus.pending,
          isSynced: 0,
          exercises: exercisesData.asMap().entries.map((eEntry) {
            final e = eEntry.value;
            return Exercise(
              id: const Uuid().v4(),
              workoutId: nwId,
              name: (e['name'] as String).toUpperCase(),
              order: eEntry.key,
              targetMuscles: e['target_muscles'],
              isSynced: 0,
            );
          }).toList(),
        );
      }).toList(),
    );

    await addCycle(newCycle);
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _cycles.clear();
    _logs.clear();
    _localRepo = null;
    notifyListeners();
  }
}
