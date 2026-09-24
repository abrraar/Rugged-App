import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/provider/auth_provider.dart';
import '../model/supplement.dart';
import '../model/supplement_stack.dart';
import '../model/supplement_item.dart';
import '../model/supplement_settings.dart';

class SupplementCloudRepository {
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Helper to get the currently authenticated User's ID safely.
  String? get _currentUserId => _supabase.auth.currentUser?.id;
  bool get _isPro => AuthProvider().isPro;

  // ==========================================
  // 1. SUPPLEMENTS METHODS (Catalog inventory)
  // ==========================================

  /// Fetch the private supplement inventory library for the logged-in user
  Future<List<Supplement>?> getAllSupplements() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('ss_supplements')
          .select()
          .eq('user_id', uid);

      return response.map((map) => Supplement.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Cloud Repository Warning (getAllSupplements): $e");
      rethrow;
    }
  }

  /// Upsert a supplement (Insert or Update its properties/remaining stock row)
  Future<void> saveSupplement(Supplement supplement) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = supplement.toMap();
      data['user_id'] = uid;
      data.remove('is_synced');

      await _supabase.from('ss_supplements').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Repository Error (saveSupplement): $e");
      rethrow;
    }
  }

  /// Delete a supplement record row by its unique ID
  Future<void> deleteSupplement(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase
          .from('ss_supplements')
          .delete()
          .eq('id', id)
          .eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Repository Error (deleteSupplement): $e");
      rethrow;
    }
  }

  /// Update just the stock column value remotely
  Future<void> updateSupplementStock(
    String supplementId,
    double newStockAmount,
  ) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase
          .from('ss_supplements')
          .update({'remaining_stock': newStockAmount})
          .eq('id', supplementId)
          .eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Repository Error (updateSupplementStock): $e");
      rethrow;
    }
  }

  // ==========================================
  // 2. SUPPLEMENT LOGS METHODS (History metrics)
  // ==========================================

  /// Fetch all historical usage logs for this user, ordered by timestamp
  Future<List<SupplementItem>?> getAllHistoryEntries() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('ss_records')
          .select()
          .eq('user_id', uid)
          .order('timestamp', ascending: false);

      return response.map((map) => SupplementItem.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Cloud Repository Warning (getAllHistoryEntries): $e");
      rethrow;
    }
  }

  /// Insert or replace a new log record entry
  Future<void> insertSupplementItem(SupplementItem entry) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = entry.toMap();
      data['user_id'] = uid;
      data.remove('is_synced');

      await _supabase.from('ss_records').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Repository Error (insertSupplementItem): $e");
      rethrow;
    }
  }

  /// Delete a log record row by its unique ID
  Future<void> deleteSupplementItem(String id) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('ss_records').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Repository Error (deleteSupplementItem): $e");
      rethrow;
    }
  }

  // ==========================================
  // 3. STACKS METHODS (Routines saved as JSON strings)
  // ==========================================

  /// Fetch all routine stacks created by the user
  Future<List<SupplementStack>?> getAllStacks(
    List<Supplement> allSupplements,
  ) async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('ss_stack')
          .select()
          .eq('user_id', uid);

      return response.map((stackMap) {
        final String? idsJson = stackMap['supplement_ids_json'] as String?;
        final List<dynamic> targetIds = idsJson != null
            ? jsonDecode(idsJson)
            : [];

        List<Supplement> associatedItems = allSupplements.where((supp) {
          return targetIds.contains(supp.id);
        }).toList();

        return SupplementStack.fromMap(stackMap, associatedItems);
      }).toList();
    } catch (e) {
      debugPrint("Cloud Repository Warning (getAllStacks): $e");
      rethrow;
    }
  }

  /// Save or modify routine stack layouts
  Future<void> saveStack(SupplementStack stack) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = stack.toMap();
      data['user_id'] = uid;
      data.remove('is_synced');

      await _supabase.from('ss_stack').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Repository Error (saveStack): $e");
      rethrow;
    }
  }

  /// Delete a routine stack row by its unique ID
  Future<void> deleteStack(String stackId) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase
          .from('ss_stack')
          .delete()
          .eq('id', stackId)
          .eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Repository Error (deleteStack): $e");
      rethrow;
    }
  }

  // ==========================================
  // 4. SETTINGS METHODS
  // ==========================================

  Future<SupplementSettings?> getSettings() async {
    if (!_isPro) return null;
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final response = await _supabase
          .from('ss_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response != null) return SupplementSettings.fromMap(response);
    } catch (e) {
      debugPrint("Cloud Repository Error (getSettings): $e");
    }
    return null;
  }

  Future<void> saveSettings(SupplementSettings settings) async {
    if (!_isPro) return;
    final uid = _currentUserId;
    if (uid == null) return;

    final data = settings.toMap();
    data['user_id'] = uid;
    data.remove('id');
    data.remove('is_synced');
    
    await _supabase.from('ss_settings').upsert(data, onConflict: 'user_id');
  }
}
