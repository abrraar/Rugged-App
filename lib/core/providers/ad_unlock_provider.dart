import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdUnlockProvider with ChangeNotifier {
  static const String _keyPrefix = 'ad_unlock_until_';
  final Map<String, DateTime> _unlockTimestamps = {};

  bool isUnlocked(String key) {
    final timestamp = _unlockTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().isBefore(timestamp);
  }

  String remainingTimeText(String key) {
    final timestamp = _unlockTimestamps[key];
    if (timestamp == null || !isUnlocked(key)) return '';
    final diff = timestamp.difference(DateTime.now());
    if (diff.inHours >= 1) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m left';
    }
    return '${diff.inMinutes}m left';
  }

  Future<void> loadUnlockState() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (var k in keys) {
      final millis = prefs.getInt(k);
      if (millis != null) {
        final keyName = k.substring(_keyPrefix.length);
        _unlockTimestamps[keyName] = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }
    notifyListeners();
  }

  Future<void> unlockForHours(String key, {int hours = 6}) async {
    final unlockUntil = DateTime.now().add(Duration(hours: hours));
    _unlockTimestamps[key] = unlockUntil;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_keyPrefix$key', unlockUntil.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> unlockFor24Hours(String key) => unlockForHours(key, hours: 24);
  Future<void> unlockFor6Hours(String key) => unlockForHours(key, hours: 6);
}
