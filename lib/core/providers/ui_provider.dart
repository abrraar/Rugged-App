import 'package:flutter/material.dart';
import '../data/ui_local_repository.dart';
import '../data/ui_cloud_repository.dart';
import '../models/ui_settings.dart';

import 'package:rugged/core/providers/sync_provider.dart';

class UiProvider with ChangeNotifier {
  UiLocalRepository? _localRepo;
  UiCloudRepository _cloudRepo = UiCloudRepository();
  UiSettings _settings = UiSettings();
  bool _isLoading = false;

  void setRepositories({UiLocalRepository? local, UiCloudRepository? cloud}) {
    if (local != null) _localRepo = local;
    if (cloud != null) _cloudRepo = cloud;
  }

  UiSettings get settings => _settings;
  bool get isLoading => _isLoading;

  void initializeForUser(String userId) {
    _localRepo = UiLocalRepository(userId: userId);
    _loadData();
  }

  Future<void> _loadData() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();

    final syncProv = SyncProvider();
    syncProv.startFeatureSync();

    try {
      // 1. Initial Local Load
      final localMap = await _localRepo!.getSettings();
      if (localMap != null) {
        _settings = UiSettings.fromMap(localMap);
        notifyListeners();
      }

      final count = await _localRepo!.getUnsyncedCount();
      syncProv.addTotalItems(count);

      // 2. MANDATORY: Push local offline changes BEFORE pulling
      if (_settings.isSynced == 0) {
        try {
          await _cloudRepo.saveSettings(_settings.toMap());
          await _localRepo!.markSettingsSynced();
          _settings = _settings.copyWith(isSynced: 1);
          notifyListeners();
          syncProv.incrementCompleted();
        } catch (e) {
          debugPrint("UiProvider: Background settings sync failed: $e");
        }
      }

      // 3. Pull from Cloud
      try {
        final cloudMap = await _cloudRepo.getSettings();
        if (cloudMap != null) {
          await _localRepo!.saveSettings(cloudMap, isFromCloud: true);
          
          // Re-load after safe reconciliation
          final refreshedLocal = await _localRepo!.getSettings();
          if (refreshedLocal != null) {
            _settings = UiSettings.fromMap(refreshedLocal);
          }
        }
      } catch (e) {
        debugPrint("UiProvider: Cloud settings load failed: $e");
      }

    } catch (e) {
      debugPrint("Error loading UI settings: $e");
    } finally {
      syncProv.endFeatureSync();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> forceRefresh() async {
    await _loadData();
  }

  Future<void> updateHomeLayout(List<String> newLayout) async {
    _settings = _settings.copyWith(
      homeLayout: newLayout, 
      isSynced: 0,
      updatedAt: DateTime.now(),
    );
    notifyListeners();

    if (_localRepo != null) {
      try {
        await _localRepo!.saveSettings(_settings.toMap());
        
        // Push to Cloud
        await _cloudRepo.saveSettings(_settings.toMap());
        
        await _localRepo!.markSettingsSynced();
        _settings = _settings.copyWith(isSynced: 1);
        notifyListeners();
      } catch (e) {
        debugPrint("Error saving UI settings: $e");
      }
    }
  }

  void clearUserData() {
    _settings = UiSettings();
    _localRepo = null;
    notifyListeners();
  }
}
