import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/provider/auth_provider.dart';
import '../model/calorie_log.dart';
import '../model/calorie_settings.dart';
import '../model/saved_meal.dart';

class CalorieCloudRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;
  bool get _isPro => AuthProvider().isPro;

  // --- Logs ---

  Future<List<CalorieLog>?> getAllLogs() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('calorie_meal_logs')
          .select()
          .eq('user_id', uid)
          .order('timestamp', ascending: false);

      return response.map((map) => CalorieLog.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Cloud Calorie Error (getAllLogs): $e");
      rethrow;
    }
  }

  Future<void> insertLog(CalorieLog log) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      dynamic supps = [];
      if (log.addedSupplementsJson != null && log.addedSupplementsJson!.isNotEmpty) {
        try {
          supps = jsonDecode(log.addedSupplementsJson!);
        } catch (_) {}
      }

      dynamic stacks = [];
      if (log.addedStacksJson != null && log.addedStacksJson!.isNotEmpty) {
        try {
          stacks = jsonDecode(log.addedStacksJson!);
        } catch (_) {}
      }

      final Map<String, dynamic> data = {
        'id': log.id,
        'user_id': uid,
        'meal_name': log.mealName,
        'food_items': log.foodItems,
        'calories': log.calories,
        'protein': log.protein,
        'carbs': log.carbs,
        'fats': log.fats,
        'timestamp': log.timestamp.toIso8601String(),
        'added_supplements_json': supps,
        'added_stacks_json': stacks,
        'servings': log.servings,
      };

      await _supabase.from('calorie_meal_logs').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Calorie Error (insertLog): $e");
      rethrow;
    }
  }

  Future<void> deleteLog(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('calorie_meal_logs').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Calorie Error (deleteLog): $e");
      rethrow;
    }
  }

  // --- Settings ---

  Future<CalorieSettings?> getSettings() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final response = await _supabase
          .from('calorie_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response != null) {
        return CalorieSettings.fromMap(response);
      }
    } catch (e) {
      debugPrint("Cloud Calorie Error (getSettings): $e");
    }
    return null;
  }

  Future<void> saveSettings(CalorieSettings settings) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint("CalorieCloudRepo: No current user ID. Cannot save settings.");
      return;
    }

    try {
      final data = settings.toMap();
      data['user_id'] = uid;
      
      // Convert booleans to true/false for Supabase bool columns
      data['track_macros'] = settings.trackMacros;
      data['show_remaining'] = settings.showRemaining;
      
      data['is_synced'] = 1; // Mark as synced in Supabase too
      data.remove('id'); // Remove local SQLite ID
      
      debugPrint("CalorieCloudRepo: Attempting upsert for calorie_settings for user: $uid");
      debugPrint("CalorieCloudRepo: Data payload: $data");
      
      await _supabase.from('calorie_settings').upsert(data, onConflict: 'user_id');
      
      debugPrint("CalorieCloudRepo: Successfully saved settings to cloud.");
    } catch (e) {
      debugPrint("Cloud Calorie Error (saveSettings): $e");
      rethrow;
    }
  }

  // --- Saved Meals ---

  Future<List<SavedMeal>?> getSavedMeals() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('calorie_meals')
          .select()
          .eq('user_id', uid)
          .order('name', ascending: true);

      return response.map((map) => SavedMeal.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Cloud Calorie Error (getSavedMeals): $e");
      rethrow;
    }
  }

  Future<void> insertSavedMeal(SavedMeal meal) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      // Decode local JSON strings back to Objects for Supabase JSONB
      dynamic decodedSupps = [];
      if (meal.addedSupplementsJson != null && meal.addedSupplementsJson!.isNotEmpty) {
        try {
          decodedSupps = jsonDecode(meal.addedSupplementsJson!);
        } catch (_) {}
      }

      dynamic decodedStacks = [];
      if (meal.addedStacksJson != null && meal.addedStacksJson!.isNotEmpty) {
        try {
          decodedStacks = jsonDecode(meal.addedStacksJson!);
        } catch (_) {}
      }

      final reminders = meal.reminders.map((r) => r.toMap()).toList();

      final Map<String, dynamic> data = {
        'id': meal.id,
        'user_id': uid,
        'name': meal.name,
        'food_items': meal.foodItems,
        'calories': meal.calories,
        'protein': meal.protein,
        'carbs': meal.carbs,
        'fats': meal.fats,
        'is_pinned_to_home': meal.isPinnedToHome,
        'notifications_enabled': meal.notificationsEnabled,
        'reminders_json': reminders,
        'added_supplements_json': decodedSupps,
        'added_stacks_json': decodedStacks,
        'servings': meal.servings,
        'multiply_supps': meal.multiplySupps,
        'is_synced': 1,
      };

      debugPrint("CalorieCloudRepo: Attempting upsert for calorie_meals: ${meal.name} (ID: ${meal.id})");
      await _supabase.from('calorie_meals').upsert(data, onConflict: 'id');
      debugPrint("CalorieCloudRepo: Successfully saved meal to cloud.");
    } catch (e) {
      debugPrint("Cloud Calorie Error (insertSavedMeal): $e");
      rethrow;
    }
  }

  Future<void> deleteSavedMeal(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('calorie_meals').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Calorie Error (deleteSavedMeal): $e");
      rethrow;
    }
  }
}
