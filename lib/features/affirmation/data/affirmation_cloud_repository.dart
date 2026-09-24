import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/provider/auth_provider.dart';
import '../model/affirmation.dart';
import '../model/affirmation_settings.dart';

class AffirmationCloudRepository {
  SupabaseClient get _supabase => Supabase.instance.client;
  bool get _isPro => AuthProvider().isPro;

  Future<List<Affirmation>?> getAllAffirmations() async {
    if (!_isPro) return null;
    final response = await _supabase
        .from('affirmations')
        .select()
        .order('display_order', ascending: true);
    
    return (response as List).map((map) => Affirmation.fromMap(map)).toList();
  }

  Future<void> insertAffirmation(Affirmation affirmation) async {
    if (!_isPro) return;
    final data = affirmation.toMap();
    data.remove('is_synced');
    data['user_id'] = _supabase.auth.currentUser?.id;
    await _supabase.from('affirmations').upsert(data);
  }

  Future<void> deleteAffirmation(String id) async {
    if (!_isPro) return;
    await _supabase.from('affirmations').delete().eq('id', id);
  }

  Future<AffirmationSettings?> getSettings() async {
    if (!_isPro) return null;
    final response = await _supabase
        .from('affirmation_settings')
        .select()
        .maybeSingle();
    if (response != null) return AffirmationSettings.fromMap(response);
    return null;
  }

  Future<void> saveSettings(AffirmationSettings settings) async {
    if (!_isPro) return;
    final data = settings.toMap();
    data['user_id'] = _supabase.auth.currentUser?.id;
    await _supabase.from('affirmation_settings').upsert(data);
  }
}

