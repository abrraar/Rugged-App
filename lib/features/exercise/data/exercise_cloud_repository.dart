import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/provider/auth_provider.dart';
import '../model/exercise_template.dart';

class ExerciseCloudRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;
  bool get _isPro => AuthProvider().isPro;

  Future<List<ExerciseTemplate>> getAllTemplates() async {
    if (!_isPro) return [];
    final uid = _currentUserId;
    if (uid == null) return [];

    final List<Map<String, dynamic>> response = await _supabase
        .from('exercise_templates')
        .select()
        .eq('user_id', uid)
        .order('name', ascending: true);

    return response.map((map) => ExerciseTemplate.fromMap(map)).toList();
  }

  Future<bool> insertTemplate(ExerciseTemplate template) async {
    if (!_isPro) {
      debugPrint("Cloud Exercise: Skipped sync for non-Pro user.");
      return false;
    }

    final uid = _currentUserId;
    if (uid == null) {
      debugPrint("Cloud Exercise Error: No authenticated user session found.");
      return false;
    }

    try {
      final Map<String, dynamic> data = {
        'id': template.id,
        'user_id': uid,
        'name': template.name,
        'target_muscles': template.targetMuscles,
        'intensity': template.intensity,
        'is_default': template.isDefault,
        'type': template.type.name,
        'about_the_movement': template.aboutTheMovement,
        'image_url': template.imageUrl,
      };
      
      // Standard upsert - Supabase handles the conflict using the Primary Key (id)
      await _supabase.from('exercise_templates').upsert(data);
          
      debugPrint("Cloud Exercise: Successfully saved ${template.name} to cloud.");
      return true;
    } catch (e) {
      debugPrint("Cloud Exercise Error (insertTemplate): $e");
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    await _supabase.from('exercise_templates').delete().eq('id', id).eq('user_id', uid);
  }
}

