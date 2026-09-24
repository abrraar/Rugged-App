import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rugged/core/services/connectivity_service.dart';
import 'package:rugged/features/auth/provider/auth_provider.dart';
import '../model/affirmation.dart';
import '../model/affirmation_settings.dart';
import '../data/affirmation_local_repository.dart';
import '../data/affirmation_cloud_repository.dart';

import 'package:rugged/core/providers/sync_provider.dart';

class AffirmationProvider with ChangeNotifier {
  AffirmationLocalRepository? _localRepo;
  AffirmationCloudRepository _cloudRepo = AffirmationCloudRepository();
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  void setRepositories({AffirmationLocalRepository? local, AffirmationCloudRepository? cloud}) {
    if (local != null) _localRepo = local;
    if (cloud != null) _cloudRepo = cloud;
  }

  List<Affirmation> _userAffirmations = [];
  Affirmation? _currentAffirmation;
  AffirmationSettings _settings = AffirmationSettings();
  bool _isLoading = false;
  Timer? _rotationTimer;
  int _currentIndex = 0;

  List<Affirmation> get customAffirmations => _userAffirmations;
  List<Affirmation> get allCustomAffirmations => _userAffirmations;
  List<Affirmation> get allSystemAffirmations => const [];
  AffirmationSettings get settings => _settings;
  Affirmation? get currentAffirmation => _currentAffirmation;
  bool get isLoading => _isLoading;

  List<Affirmation> get affirmations {
    final list = List<Affirmation>.from(_userAffirmations);
    if (_settings.orderDirection == 'desc') {
      return list.reversed.toList();
    }
    return list;
  }

  void initializeForUser(String userId) {
    _localRepo = AffirmationLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    if (!AuthProvider().isPro) return;
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscription(String userId) {
    if (!AuthProvider().isPro) return;
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:affirmations_sync:$userId');
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'affirmations',
      callback: (payload) async {
        if (payload.newRecord.isNotEmpty) {
          final affirmation = Affirmation.fromMap(payload.newRecord);
          await _localRepo!.insertAffirmation(affirmation);
          _refreshList();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteAffirmation(id);
            _refreshList();
          }
        }
      },
    );
    _realtimeChannel!.subscribe();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_localRepo == null) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // MANDATORY: Push local offline changes BEFORE pulling from cloud
      await _syncLocalToCloud();

      _userAffirmations = await _localRepo!.getAllAffirmations();
      _settings = await _localRepo!.getSettings();
      _updateCurrentAffirmation();
      _startRotation();
      notifyListeners();

      final cloudAffs = await _cloudRepo.getAllAffirmations();
      if (cloudAffs != null) {
        final localAffs = await _localRepo!.getAllAffirmations();
        final cloudIds = cloudAffs.map((a) => a.id).toSet();

        // Deletion Reconciliation: Remove local synced affirmations missing from cloud
        for (var localA in localAffs) {
          if (localA.isSynced == 1 && !cloudIds.contains(localA.id)) {
            await _localRepo!.deleteAffirmation(localA.id);
          }
        }

        for (var aff in cloudAffs) {
          await _localRepo!.insertAffirmation(aff, isFromCloud: true);
        }
        _userAffirmations = await _localRepo!.getAllAffirmations();
      }
      final cloudSettings = await _cloudRepo.getSettings();
      if (cloudSettings != null) {
        await _localRepo!.saveSettings(cloudSettings, isFromCloud: true);
        _settings = await _localRepo!.getSettings();
      }
      _updateCurrentAffirmation();
      _startRotation();
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _refreshList() async {
    if (_localRepo == null) return;
    _userAffirmations = await _localRepo!.getAllAffirmations();
    _updateCurrentAffirmation();
    notifyListeners();
  }

  void _updateCurrentAffirmation() {
    final available = affirmations;

    if (available.isEmpty) {
      _currentAffirmation = null;
      notifyListeners();
      return;
    }

    if (_settings.rotationMode == 'random') {
      _currentAffirmation = available[Random().nextInt(available.length)];
    } else {
      // 'continuous'
      _currentIndex = (_currentIndex + 1) % available.length;
      _currentAffirmation = available[_currentIndex];
    }
    notifyListeners();
  }

  void setManualAffirmation(Affirmation affirmation) {
    _currentAffirmation = affirmation;
    final list = affirmations;
    final idx = list.indexWhere((a) => a.id == affirmation.id);
    if (idx != -1) _currentIndex = idx;
    
    notifyListeners();
    _startRotation(); // Restart timer to give user full duration
  }

  void _startRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(Duration(minutes: _settings.rotationMinutes), (_) {
      _updateCurrentAffirmation();
    });
  }

  Future<void> updateSettings(AffirmationSettings settings) async {
    final updatedSettings = settings.copyWith(
      isSynced: 0,
      updatedAt: DateTime.now(),
    );
    _settings = updatedSettings;
    notifyListeners();
    if (_localRepo != null) {
      await _localRepo!.saveSettings(updatedSettings);
      try {
        await _cloudRepo.saveSettings(updatedSettings);
        await _localRepo!.markSettingsSynced();
        _settings = updatedSettings.copyWith(isSynced: 1);
        notifyListeners();
      } catch (e) {
        debugPrint("Sync Settings Error: $e");
      }
      _startRotation();
    }
  }

  Future<void> updateOrder(List<Affirmation> orderedList) async {
    _userAffirmations = orderedList;
    notifyListeners();
    if (_localRepo != null) {
      await _localRepo!.updateAffirmationOrder(orderedList);
      for (var aff in orderedList) {
        _cloudRepo.insertAffirmation(aff);
      }
    }
  }

  Future<void> addAffirmation(String text, {String? speaker, String? sharedBy}) async {
    if (_localRepo == null) return;
    final affirmation = Affirmation(
      text: text,
      speaker: speaker,
      sharedBy: sharedBy,
      isSynced: 0,
      updatedAt: DateTime.now(),
      displayOrder: _userAffirmations.length,
    );
    _userAffirmations.add(affirmation);
    notifyListeners();
    try {
      await _localRepo!.insertAffirmation(affirmation);
      await _cloudRepo.insertAffirmation(affirmation);
      await _localRepo!.markAffirmationSynced(affirmation.id);
      _refreshList();
    } catch (e) { debugPrint("Add Error: $e"); }
  }

  Future<void> updateAffirmation(Affirmation affirmation) async {
    if (_localRepo == null) return;
    final index = _userAffirmations.indexWhere((a) => a.id == affirmation.id);
    if (index != -1) {
      final updated = affirmation.copyWith(
        isSynced: 0,
        updatedAt: DateTime.now(),
      );
      _userAffirmations[index] = updated;
      notifyListeners();
      try {
        await _localRepo!.insertAffirmation(updated);
        await _cloudRepo.insertAffirmation(updated);
        await _localRepo!.markAffirmationSynced(affirmation.id);
        _refreshList();
      } catch (e) { debugPrint("Update Error: $e"); }
    }
  }

  Future<void> deleteAffirmation(String id) async {
    if (_localRepo == null) return;
    _userAffirmations.removeWhere((a) => a.id == id);
    notifyListeners();
    try {
      await _localRepo!.deleteAffirmation(id);
      await _localRepo!.addToDeletionQueue(id, 'affirmations');
      await _cloudRepo.deleteAffirmation(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) { debugPrint("Delete Error: $e"); }
  }

  Future<void> _syncLocalToCloud() async {
    if (_localRepo == null) return;
    
    final syncProv = SyncProvider();
    syncProv.startFeatureSync();

    try {
      final count = await _localRepo!.getUnsyncedCount();
      syncProv.addTotalItems(count);

      // 1. Push Deletions
      final deletions = await _localRepo!.getPendingDeletions();
      for (var del in deletions) {
        final id = del['id'] as String;
        final table = del['table_name'] as String;
        try {
          if (table == 'affirmations') await _cloudRepo.deleteAffirmation(id);
          await _localRepo!.removeFromDeletionQueue(id);
          syncProv.incrementCompleted();
        } catch (_) {}
      }

      // 2. Push Changes
      final unsynced = await _localRepo!.getUnsyncedAffirmations();
      for (var aff in unsynced) {
        try {
          await _cloudRepo.insertAffirmation(aff);
          await _localRepo!.markAffirmationSynced(aff.id);
          syncProv.incrementCompleted();
        } catch (_) {}
      }

      final unsyncedSettings = await _localRepo!.getUnsyncedSettings();
      if (unsyncedSettings != null) {
        try {
          await _cloudRepo.saveSettings(unsyncedSettings);
          await _localRepo!.markSettingsSynced();
          syncProv.incrementCompleted();
        } catch (_) {}
      }
    } finally {
      syncProv.endFeatureSync();
    }
  }

  Future<void> forceRefresh() async {
    await _syncLocalToCloud();
    await _loadData();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }
}
