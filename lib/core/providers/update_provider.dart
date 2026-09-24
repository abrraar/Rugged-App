import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/notification_service.dart';

class UpdateProvider with ChangeNotifier {
  static const String _versionUrl = 'https://abrraar.github.io/Heavy-Duty-Website/version.json';
  
  String _currentVersion = "";
  String _latestVersion = "";
  int _currentBuildNumber = 0;
  int _latestBuildNumber = 0;
  String _downloadUrl = "";
  bool _isUpdateAvailable = false;
  bool _isLoading = false;

  String get currentVersion => _currentVersion;
  String get latestVersion => _latestVersion;
  bool get isUpdateAvailable => _isUpdateAvailable;
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final packageInfo = await PackageInfo.fromPlatform();
    _currentVersion = packageInfo.version;
    _currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    notifyListeners();
    await checkForUpdates();
  }

  Future<void> checkForUpdates({bool showNotification = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(Uri.parse(_versionUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _latestVersion = data['latest_version'] ?? "";
        _latestBuildNumber = data['build_number'] ?? 0;
        _downloadUrl = data['url'] ?? "";

        if (_latestBuildNumber > _currentBuildNumber) {
          _isUpdateAvailable = true;
          if (showNotification) {
            _showUpdateNotification();
          }
        } else {
          _isUpdateAvailable = false;
        }
      }
    } catch (e) {
      debugPrint("Update Check Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _showUpdateNotification() {
    NotificationService().showInstantNotification(
      id: 999,
      title: "UPGRADE DETECTED",
      body: "Master your HIT training with the latest Rugged update.",
      payload: "update_available",
    );
  }

  Future<void> launchUpdateUrl() async {
    if (_downloadUrl.isEmpty) return;
    final Uri url = Uri.parse(_downloadUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $_downloadUrl');
    }
  }
}
