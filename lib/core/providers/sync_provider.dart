// lib/core/providers/sync_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rugged/core/services/connectivity_service.dart';

enum SyncUIState { idle, online, syncing, completed }

class SyncProvider with ChangeNotifier {
  static SyncProvider _instance = SyncProvider._internal();
  factory SyncProvider() => _instance;
  
  // Added for testing
  static void setMockInstance(SyncProvider mock) => _instance = mock;
  
  SyncUIState _state = SyncUIState.idle;
  int _totalItems = 0;
  int _completedItems = 0;
  int _activeFeatures = 0;
  
  // Controls whether the sync flow should be visible to the user.
  // We only show it on RECONNECTION, not on app launch.
  bool _shouldShowUI = false;
  
  bool _isSyncFlowStarted = false;
  Timer? _finalizeTimer;

  SyncUIState get state => _state;
  int get totalItems => _totalItems;
  int get completedItems => _completedItems;

  SyncProvider._internal() {
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() {
    // internet returned while app was open
    _shouldShowUI = true; 
    _resetCounters();
  }

  void _resetCounters() {
    _totalItems = 0;
    _completedItems = 0;
    _isSyncFlowStarted = false;
    _activeFeatures = 0;
  }

  void startFeatureSync() {
    _activeFeatures++;
    _finalizeTimer?.cancel();
  }

  void addTotalItems(int count) {
    if (count <= 0) return;
    
    _totalItems += count;
    
    // Trigger the UI sequence only if internet was JUST restored
    if (_shouldShowUI && !_isSyncFlowStarted) {
      _startVisualSequence();
    } else {
      // Background sync: still notify if UI is already up, 
      // but don't wake it up for background-only work.
      if (_isSyncFlowStarted) notifyListeners();
    }
  }

  Future<void> _startVisualSequence() async {
    if (_isSyncFlowStarted) return;
    _isSyncFlowStarted = true;

    // 1. Show "Internet Restored"
    _state = SyncUIState.online;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    // 2. Transition to "Syncing" bar
    if (_isSyncFlowStarted) {
      _state = SyncUIState.syncing;
      notifyListeners();
    }
  }

  void incrementCompleted() {
    _completedItems++;
    if (_completedItems > _totalItems) _totalItems = _completedItems;
    if (_isSyncFlowStarted) notifyListeners();
  }

  void endFeatureSync() {
    _activeFeatures--;
    if (_activeFeatures <= 0) {
      _finalizeTimer?.cancel();
      _finalizeTimer = Timer(const Duration(seconds: 2), () {
        if (_activeFeatures <= 0) {
          if (_isSyncFlowStarted) {
            finalizeSync();
          } else {
            _resetToIdle();
          }
        }
      });
    }
  }

  Future<void> finalizeSync() async {
    if (!_isSyncFlowStarted) return;
    
    if (_completedItems < _totalItems) _completedItems = _totalItems;
    
    _state = SyncUIState.completed;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 3));
    _resetToIdle();
  }

  void _resetToIdle() {
    _state = SyncUIState.idle;
    _totalItems = 0;
    _completedItems = 0;
    _isSyncFlowStarted = false;
    _shouldShowUI = false; // Reset for next reconnection
    notifyListeners();
  }

  @override
  void dispose() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _finalizeTimer?.cancel();
    super.dispose();
  }
}
