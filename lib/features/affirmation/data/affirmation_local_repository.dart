import 'package:sqflite/sqflite.dart';
import 'package:rugged/core/database/database_helper.dart';
import '../model/affirmation.dart';
import '../model/affirmation_settings.dart';

class AffirmationLocalRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  AffirmationLocalRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  Future<List<Affirmation>> getAllAffirmations() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'affirmations', 
      where: 'user_id = ?', 
      whereArgs: [userId],
      orderBy: 'display_order ASC, created_at DESC'
    );
    return maps.map((map) => Affirmation.fromMap(map)).toList();
  }

  // --- Settings ---
  Future<AffirmationSettings> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('affirmation_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) {
      return AffirmationSettings.fromMap(maps.first);
    }
    return AffirmationSettings(userId: userId);
  }

  Future<void> saveSettings(AffirmationSettings settings, {bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final results = await db.query('affirmation_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
      if (results.isNotEmpty) {
        final localIsSynced = results.first['is_synced'] as int;
        final localUpdatedAt = results.first['updated_at'] != null 
            ? DateTime.tryParse(results.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (settings.updatedAt != null && localUpdatedAt != null && settings.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }

    final settingsWithUser = settings.copyWith(userId: userId);
    final data = settingsWithUser.toMap();
    data['id'] = 1;
    await db.insert('affirmation_settings', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAffirmationOrder(List<Affirmation> affirmations) async {
    final db = await _getDatabase();
    await db.transaction((txn) async {
      for (int i = 0; i < affirmations.length; i++) {
        await txn.update(
          'affirmations',
          {'display_order': i},
          where: 'id = ? AND user_id = ?',
          whereArgs: [affirmations[i].id, userId],
        );
      }
    });
  }

  Future<void> insertAffirmation(Affirmation affirmation, {bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final existing = await db.query('affirmations', where: 'id = ?', whereArgs: [affirmation.id]);
      if (existing.isNotEmpty) {
        final localIsSynced = existing.first['is_synced'] as int;
        final localUpdatedAt = existing.first['updated_at'] != null 
            ? DateTime.tryParse(existing.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (affirmation.updatedAt != null && localUpdatedAt != null && affirmation.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }

    final affirmationWithUser = affirmation.copyWith(userId: userId);
    await db.insert('affirmations', affirmationWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAffirmation(String id) async {
    final db = await _getDatabase();
    await db.delete('affirmations', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<List<Affirmation>> getUnsyncedAffirmations() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('affirmations', where: 'is_synced = 0 AND user_id = ?', whereArgs: [userId]);
    return maps.map((map) => Affirmation.fromMap(map)).toList();
  }

  Future<void> markAffirmationSynced(String id) async {
    final db = await _getDatabase();
    await db.update('affirmations', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<AffirmationSettings?> getUnsyncedSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('affirmation_settings', where: 'is_synced = 0 AND id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) return AffirmationSettings.fromMap(maps.first);
    return null;
  }

  Future<void> markSettingsSynced() async {
    final db = await _getDatabase();
    await db.update('affirmation_settings', {'is_synced': 1}, where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
  }

  Future<int> getUnsyncedCount() async {
    final db = await _getDatabase();
    final affs = await db.rawQuery('SELECT COUNT(*) as cnt FROM affirmations WHERE is_synced = 0 AND user_id = ?', [userId]);
    final settings = await db.rawQuery('SELECT COUNT(*) as cnt FROM affirmation_settings WHERE is_synced = 0 AND user_id = ?', [userId]);
    final dels = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_deletions WHERE user_id = ? AND table_name = ?', [userId, 'affirmations']);
    
    return (Sqflite.firstIntValue(affs) ?? 0) + (Sqflite.firstIntValue(settings) ?? 0) + (Sqflite.firstIntValue(dels) ?? 0);
  }

  Future<void> addToDeletionQueue(String id, String tableName) async {
    final db = await _getDatabase();
    await db.insert('pending_deletions', {'id': id, 'user_id': userId, 'table_name': tableName},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFromDeletionQueue(String id) async {
    final db = await _getDatabase();
    await db.delete('pending_deletions', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<List<Map<String, dynamic>>> getPendingDeletions() async {
    final db = await _getDatabase();
    return await db.query(
      'pending_deletions', 
      where: 'user_id = ? AND table_name = ?', 
      whereArgs: [userId, 'affirmations']
    );
  }

}
