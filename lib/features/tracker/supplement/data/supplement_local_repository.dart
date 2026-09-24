// lib/features/tracker/supplement/data/supplement_local_repository.dart

import 'dart:convert';
import 'package:rugged/features/tracker/supplement/model/supplement_item.dart';
import 'package:rugged/features/tracker/supplement/model/supplement_settings.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../../core/database/database_helper.dart';
import '../model/supplement.dart';
import '../model/supplement_stack.dart';

class SupplementLocalRepository {
  final String userId; // Added to scope repository to user
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  SupplementLocalRepository({required this.userId});
  

  // Helper method to get the specific DB for this user
  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }
  // ==========================================
  // 1. GLOBAL SUPPLEMENT OPERATION METHODS
  // ==========================================

  /// Updates only the stock column value inside the local SQLite database
  Future<void> updateSupplementStock(
    String supplementId,
    double newStockAmount,
  ) async {
    final db = await _getDatabase();

    await db.update(
      'ss_supplements', // Aligned table name
      {'remaining_stock': newStockAmount},
      where: 'id = ? AND user_id = ?',
      whereArgs: [supplementId, userId],
    );
  }

  /// Fetch all raw supplements saved in the database library
  Future<List<Supplement>> getAllSupplements() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'ss_supplements',
      where: 'user_id = ?',
      whereArgs: [userId],
    ); // Aligned table name

    return maps.map((map) => Supplement.fromMap(map)).toList();
  }

  /// Inserts or replaces a supplement model entry into local memory
  Future<void> saveSupplement(Supplement supplement, {bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final existing = await db.query('ss_supplements', where: 'id = ?', whereArgs: [supplement.id]);
      if (existing.isNotEmpty) {
        final localIsSynced = existing.first['is_synced'] as int;
        final localUpdatedAt = existing.first['updated_at'] != null 
            ? DateTime.tryParse(existing.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (supplement.updatedAt != null && localUpdatedAt != null && supplement.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }

    // Ensure the userId is set before saving
    final supplementWithUser = supplement.copyWith(userId: userId);
    await db.insert(
      'ss_supplements', // Aligned table name
      supplementWithUser.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Completely drops a supplement item from the inventory catalog
  Future<void> deleteSupplement(String id) async {
    final db = await _getDatabase();
    await db.delete(
      'ss_supplements',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    ); // Aligned table name
  }

  Future<List<Supplement>> getUnsyncedSupplements() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'ss_supplements',
      where: 'is_synced = ? AND user_id = ?',
      whereArgs: [0, userId],
    );
    return maps.map((map) => Supplement.fromMap(map)).toList();
  }

  Future<void> markSupplementSynced(String id) async {
    final db = await _getDatabase();
    await db.update(
      'ss_supplements',
      {'is_synced': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // ==========================================
  // 2. HISTORY / LOGGING METHODS
  // ==========================================

  /// Inserts a new operational intake or restock item log into the history ledger
  Future<void> insertSupplementItem(SupplementItem entry, {bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final existing = await db.query('ss_records', where: 'id = ?', whereArgs: [entry.id]);
      if (existing.isNotEmpty) {
        final localIsSynced = existing.first['is_synced'] as int;
        final localUpdatedAt = existing.first['updated_at'] != null 
            ? DateTime.tryParse(existing.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (entry.updatedAt != null && localUpdatedAt != null && entry.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }

    final entryWithUser = entry.copyWith(userId: userId);
    await db.insert(
      'ss_records', // Aligned table name
      entryWithUser.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates the synchronization status flag to true (1) following a backend push
  Future<void> markHistoryAsSynced(String id) async {
    final db = await _getDatabase();
    await db.update(
      'ss_records', // Aligned table name
      {'is_synced': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  /// Delete a specific history entry (used primarily for Undo rollback requests)
  Future<void> deleteSupplementItem(String id) async {
    final db = await _getDatabase();
    await db.delete(
      'ss_records',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    ); // Aligned table name
  }

  /// Retrieves all local history logs from the database, ordered by timestamp
  Future<List<SupplementItem>> getAllHistory() async {
    final db = await _getDatabase();

    final List<Map<String, dynamic>> maps = await db.query(
      'ss_records',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => SupplementItem.fromMap(map)).toList();
  }

  /// Retrieves all local history logs that have not been synced to the cloud yet
  Future<List<SupplementItem>> getUnsyncedHistory() async {
    final db = await _getDatabase();

    final List<Map<String, dynamic>> maps = await db.query(
      'ss_records', // Aligned table name
      where: 'is_synced = ? AND user_id = ?',
      whereArgs: [0, userId], // Pull rows where is_synced is false/0
    );

    return maps.map((map) => SupplementItem.fromMap(map)).toList();
  }

  // ==========================================
  // 3. STACK / ROUTINE METHODS
  // ==========================================

  /// Fetch all routine stacks saved locally
  Future<List<SupplementStack>> getAllStacks(
    List<Supplement> allSupplements,
  ) async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'ss_stack',
      where: 'user_id = ?',
      whereArgs: [userId],
    ); // Aligned table name

    return maps.map((stackMap) {
      final String? idsJson = stackMap['supplement_ids_json'] as String?;
      final List<dynamic> targetIds = idsJson != null ? jsonDecode(idsJson) : [];

      List<Supplement> associatedItems = targetIds.map((id) {
        return allSupplements.firstWhere(
          (supp) => supp.id == id,
          orElse:
              () => Supplement(
                id: id,
                name: "Deleted Item",
                servingUnit: "",
                weightPerServing: 0,
                weightUnit: "",
                isActive: false,
              ),
        );
      }).toList();

      return SupplementStack.fromMap(stackMap, associatedItems);
    }).toList();
  }

  /// Saves or alters a custom predefined combination routine stack structure
  Future<void> saveStack(SupplementStack stack, {bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final existing = await db.query('ss_stack', where: 'id = ?', whereArgs: [stack.id]);
      if (existing.isNotEmpty) {
        final localIsSynced = existing.first['is_synced'] as int;
        final localUpdatedAt = existing.first['updated_at'] != null 
            ? DateTime.tryParse(existing.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (stack.updatedAt != null && localUpdatedAt != null && stack.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }

    final stackWithUser = stack.copyWith(userId: userId);
    await db.insert(
      'ss_stack', // Aligned table name
      stackWithUser.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a custom combination routine stack layout completely
  Future<void> deleteStack(String id) async {
    final db = await _getDatabase();
    await db.delete(
      'ss_stack',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    ); // Aligned table name
  }

  Future<List<SupplementStack>> getUnsyncedStacks() async {
    final db = await _getDatabase();
    // We need to fetch supplements to rebuild the stack models properly
    final allSupps = await getAllSupplements();
    final List<Map<String, dynamic>> maps = await db.query(
      'ss_stack',
      where: 'is_synced = ? AND user_id = ?',
      whereArgs: [0, userId],
    );

    return maps.map((stackMap) {
      final String? idsJson = stackMap['supplement_ids_json'] as String?;
      final List<dynamic> targetIds = idsJson != null ? jsonDecode(idsJson) : [];

      List<Supplement> associatedItems = targetIds.map((id) {
        return allSupps.firstWhere(
          (supp) => supp.id == id,
          orElse:
              () => Supplement(
                id: id,
                name: "Deleted Item",
                servingUnit: "",
                weightPerServing: 0,
                weightUnit: "",
                isActive: false,
              ),
        );
      }).toList();

      return SupplementStack.fromMap(stackMap, associatedItems);
    }).toList();
  }

  Future<void> markStackSynced(String id) async {
    final db = await _getDatabase();
    await db.update(
      'ss_stack',
      {'is_synced': 1},
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  // ==========================================
  // 4. SETTINGS METHODS
  // ==========================================

  Future<SupplementSettings?> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('ss_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) return SupplementSettings.fromMap(maps.first);
    return null;
  }

  Future<void> saveSettings(SupplementSettings settings, {bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final results = await db.query('ss_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
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
    final map = settingsWithUser.toMap();
    map['id'] = 1;
    await db.insert('ss_settings', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getUnsyncedCount() async {
    final db = await _getDatabase();
    final supps = await db.rawQuery('SELECT COUNT(*) as cnt FROM ss_supplements WHERE is_synced = 0 AND user_id = ?', [userId]);
    final stacks = await db.rawQuery('SELECT COUNT(*) as cnt FROM ss_stack WHERE is_synced = 0 AND user_id = ?', [userId]);
    final records = await db.rawQuery('SELECT COUNT(*) as cnt FROM ss_records WHERE is_synced = 0 AND user_id = ?', [userId]);
    final dels = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_deletions WHERE user_id = ? AND table_name IN (?, ?, ?)', [userId, 'ss_supplements', 'ss_stack', 'ss_records']);
    
    return (Sqflite.firstIntValue(supps) ?? 0) + 
           (Sqflite.firstIntValue(stacks) ?? 0) + 
           (Sqflite.firstIntValue(records) ?? 0) + 
           (Sqflite.firstIntValue(dels) ?? 0);
  }

  // --- Sync Helpers ---

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
      where: 'user_id = ? AND table_name IN (?, ?, ?)', 
      whereArgs: [userId, 'ss_supplements', 'ss_stack', 'ss_records']
    );
  }

}
