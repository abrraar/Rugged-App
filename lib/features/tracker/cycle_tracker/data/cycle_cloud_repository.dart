import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/provider/auth_provider.dart';
import '../model/training_cycle.dart';
import '../model/workout.dart';
import '../model/exercise.dart';
import '../model/exercise_log.dart';

class CycleCloudRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;
  bool get _isPro => AuthProvider().isPro;

  // --- Deep Retrieval ---

  Future<List<TrainingCycle>?> getAllCycles() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      // Standard Relational Fetch
      final List<Map<String, dynamic>> response = await _supabase
          .from('hit_cycles')
          .select('''
            *,
            workouts:hit_workouts (
              *,
              exercises:hit_exercises (*)
            )
          ''')
          .eq('user_id', uid);

      return response.map((cycleMap) {
        final List<dynamic> workoutData = cycleMap['workouts'] ?? [];
        final workouts = workoutData.map((wMap) {
          final List<dynamic> exerciseData = wMap['exercises'] ?? [];
          final exercises = exerciseData.map((eMap) => Exercise.fromMap(eMap)).toList();
          return Workout.fromMap(wMap, exercises);
        }).toList();
        
        return TrainingCycle.fromMap(cycleMap, workouts);
      }).toList();
    } catch (e) {
      debugPrint("Cloud Cycle Error (getAllCycles): $e");
      rethrow;
    }
  }

  // --- Individual Syncs ---

  Future<void> insertCycle(TrainingCycle cycle) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = cycle.toMap();
    data['user_id'] = uid;
    data.remove('is_synced');
    data.remove('updated_at'); // Let database trigger handle this
    await _supabase.from('hit_cycles').upsert(data, onConflict: 'id');
  }

  Future<void> insertWorkout(Workout workout) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = workout.toMap();
    data['user_id'] = uid;
    data.remove('is_synced');
    data.remove('updated_at'); // Let database trigger handle this
    await _supabase.from('hit_workouts').upsert(data, onConflict: 'id');
  }

  Future<void> insertExercise(Exercise exercise) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = exercise.toMap();
    data['user_id'] = uid;
    data.remove('is_synced');
    data.remove('updated_at'); // Let database trigger handle this
    await _supabase.from('hit_exercises').upsert(data, onConflict: 'id');
  }

  Future<void> deleteWorkout(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    await _supabase.from('hit_workouts').delete().eq('id', id).eq('user_id', uid);
  }

  Future<void> deleteExercise(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    await _supabase.from('hit_exercises').delete().eq('id', id).eq('user_id', uid);
  }

  Future<void> deleteCycle(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    await _supabase.from('hit_cycles').delete().eq('id', id).eq('user_id', uid);
  }

  // --- Logs ---

  Future<List<ExerciseLog>?> getAllLogs() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('exercise_logs')
          .select()
          .eq('user_id', uid);

      return response.map((map) => ExerciseLog.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Cloud Cycle Error (getAllLogs): $e");
      rethrow;
    }
  }

  Future<void> insertLog(ExerciseLog log) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = log.toMap();
    data['user_id'] = uid;
    data.remove('is_synced');
    data.remove('updated_at'); // Let database trigger handle this
    
    await _supabase.from('exercise_logs').upsert(
      data, 
      onConflict: 'id',
    );
    debugPrint("CycleCloudRepository: Successfully upserted log ${log.id} to Supabase.");
  }

  Future<void> deleteLog(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    await _supabase.from('exercise_logs').delete().eq('id', id).eq('user_id', uid);
  }

  // --- Settings ---

  Future<Map<String, dynamic>?> getSettings() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final response = await _supabase
          .from('hit_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint("Cloud Cycle Error (getSettings): $e");
      return null;
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = Map<String, dynamic>.from(settings);
    data['user_id'] = uid;
    // Remove local DB specific fields
    data.remove('id'); 
    data.remove('is_synced');
    
    await _supabase.from('hit_settings').upsert(
      data, 
      onConflict: 'user_id'
    );
  }
}
