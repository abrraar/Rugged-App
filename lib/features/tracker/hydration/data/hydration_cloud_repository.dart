import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/provider/auth_provider.dart';
import '../model/hydration_log.dart';
import '../model/hydration_settings.dart';

class HydrationCloudRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;
  bool get _isPro => AuthProvider().isPro;

  // --- Logs ---

  Future<List<HydrationLog>?> getAllLogs() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('hydration_logs')
          .select()
          .eq('user_id', uid)
          .order('timestamp', ascending: false);

      return response.map((map) => HydrationLog.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Cloud Hydration Error (getAllLogs): $e");
      rethrow;
    }
  }

  Future<void> insertLog(HydrationLog log) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = log.toMap();
    data['user_id'] = uid;
    data.remove('is_synced');
    await _supabase.from('hydration_logs').upsert(data, onConflict: 'id');
  }

  Future<void> deleteLog(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    await _supabase.from('hydration_logs').delete().eq('id', id).eq('user_id', uid);
  }

  // --- Settings ---

  Future<HydrationSettings?> getSettings() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final response = await _supabase
          .from('hydration_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response != null) {
        return HydrationSettings.fromMap(response);
      }
    } catch (e) {
      debugPrint("Cloud Hydration Error (getSettings): $e");
    }
    return null;
  }

  Future<void> saveSettings(HydrationSettings settings) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = settings.toMap();
    data['user_id'] = uid;
    data['is_synced'] = 1;
    data.remove('id'); 
    await _supabase.from('hydration_settings').upsert(data, onConflict: 'user_id');
  }
}
