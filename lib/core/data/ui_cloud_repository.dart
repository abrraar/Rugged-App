import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/provider/auth_provider.dart';

class UiCloudRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  bool get _isPro => AuthProvider().isPro;

  Future<Map<String, dynamic>?> getSettings() async {
    if (!_isPro) return null;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _supabase
        .from('home_widget_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    
    return response;
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    if (!_isPro) return;
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final data = Map<String, dynamic>.from(settings);
    data['user_id'] = userId;
    data.remove('id'); // ID is handled by Supabase/Constraint

    await _supabase.from('home_widget_settings').upsert(data);
  }
}

