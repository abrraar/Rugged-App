import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import '../model/body_comp_log.dart';
import '../model/body_comp_settings.dart';

class BodyCompCloudRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;
  bool get _isPro => AuthProvider().isPro;

  String _getTableName(BodyMetricType type) {
    switch (type) {
      case BodyMetricType.weight: return 'body_comp_weight_logs';
      case BodyMetricType.fat: return 'body_comp_fats_logs';
      case BodyMetricType.muscle: return 'body_comp_muscle_logs';
    }
  }

  // --- Settings ---

  Future<BodyCompSettings?> getSettings() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final response = await _supabase
          .from('body_comp_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response != null) {
        return BodyCompSettings.fromMap(response);
      }
    } catch (e) {
      debugPrint("Cloud Body Comp Error (getSettings): $e");
    }
    return null;
  }

  Future<void> saveSettings(BodyCompSettings settings) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = settings.toMap();
    data['user_id'] = uid;
    data['is_synced'] = 1;
    data.remove('id'); 
    await _supabase.from('body_comp_settings').upsert(data, onConflict: 'user_id');
  }

  // --- Logs ---

  Future<List<BodyCompLog>?> getAllLogs() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<BodyCompLog> allLogs = [];
      
      for (var type in BodyMetricType.values) {
        final List<Map<String, dynamic>> response = await _supabase
            .from(_getTableName(type))
            .select()
            .eq('user_id', uid)
            .order('timestamp', ascending: false);
            
        allLogs.addAll(response.map((map) => BodyCompLog.fromMap(map, type)));
      }
      
      allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allLogs;
    } catch (e) {
      debugPrint("Cloud Body Comp Error (getAllLogs): $e");
      rethrow;
    }
  }

  Future<void> insertLog(BodyCompLog log) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = log.toMap();
    data['user_id'] = uid;
    data.remove('is_synced');
    await _supabase.from(_getTableName(log.type)).upsert(data, onConflict: 'id');
  }

  Future<void> deleteLog(String id, BodyMetricType type) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    await _supabase.from(_getTableName(type)).delete().eq('id', id).eq('user_id', uid);
  }
}

