// lib/features/tracker/sleep/provider/sleep_alarm_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:uuid/uuid.dart';
import '../model/sleep_alarm.dart';
import '../../../../core/utils/id_utils.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/sleep_alarm_repository.dart';

class SleepAlarmProvider with ChangeNotifier {
  List<SleepAlarm> _alarms = [];
  bool _isInitialized = false;
  SleepAlarmRepository? _repo;
  SleepAlarmSettings _settings = SleepAlarmSettings();

  List<SleepAlarm> get alarms => _alarms;
  SleepAlarmSettings get settings => _settings;
  
  static const int bedtimeId = 888;
  static const int wakeUpId = 999;

  bool get isBedtimeAlarmEnabled => _settings.bedtimeEnabled;
  bool get isWakeUpAlarmEnabled => _settings.wakeUpEnabled;

  void initializeForUser(String userId) {
    _repo = SleepAlarmRepository(userId: userId);
    init();
  }

  Future<void> init() async {
    if (!_isInitialized) {
      _isInitialized = true;
    }

    if (_repo != null) {
      _settings = await _repo!.getSettings();
    }
    await _loadAlarms();
    notifyListeners();
  }

  Future<bool> checkAndRequestPermissions(BuildContext context) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final notificationStatus = await Permission.notification.status;
      if (notificationStatus.isDenied) {
        await Permission.notification.request();
      }
    }

    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied) {
        if (context.mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600;
                return AlertDialog(
                  backgroundColor: const Color(0xFF1A1A1A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isCompact ? 28 : 20.0),
                  ),
                  title: Text(
                    "Alarm Permissions", 
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? null : 18.0,
                    )
                  ),
                  content: Text(
                    "To wake you up reliably, Rugged needs permission to set exact alarms. Please enable this in the next screen.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isCompact ? null : 13.0,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        "CANCEL", 
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: isCompact ? null : 12.0,
                        )
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(
                        "OPEN SETTINGS", 
                        style: TextStyle(
                          color: const Color(0xFFD32F2F),
                          fontSize: isCompact ? null : 12.0,
                          fontWeight: FontWeight.w500,
                        )
                      ),
                    ),
                  ],
                );
              },
            ),
          );

          if (proceed == true) {
            const intent = AndroidIntent(
              action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
            );
            await intent.launch();
          }
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _loadAlarms() async {
    _alarms = [];
    if (_settings.bedtimeEnabled) {
      _alarms.add(SleepAlarm(
        id: bedtimeId,
        label: 'Sleep Time',
        time: _getNextOccurrence(_settings.bedtimeHour, _settings.bedtimeMinute),
        audioPath: _settings.bedtimeAudioPath ?? 'assets/audio/alarm.mp3',
        isEnabled: true,
        type: AlarmType.bedtime,
      ));
    }
    if (_settings.wakeUpEnabled) {
      _alarms.add(SleepAlarm(
        id: wakeUpId,
        label: 'Wake Up',
        time: _getNextOccurrence(_settings.wakeUpHour, _settings.wakeUpMinute),
        audioPath: _settings.wakeUpAudioPath ?? 'assets/audio/alarm.mp3',
        isEnabled: true,
        type: AlarmType.wakeUp,
      ));
    }
    notifyListeners();
  }

  DateTime _getNextOccurrence(int hour, int minute) {
    final now = DateTime.now();
    DateTime target = DateTime(now.year, now.month, now.day, hour, minute);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));
    return target;
  }

  Future<void> updateSettings({
    bool? bedtimeEnabled,
    int? bedtimeHour,
    int? bedtimeMinute,
    String? bedtimeAudioPath,
    bool? wakeUpEnabled,
    int? wakeUpHour,
    int? wakeUpMinute,
    String? wakeUpAudioPath,
  }) async {
    final now = DateTime.now();
    _settings = _settings.copyWith(
      bedtimeEnabled: bedtimeEnabled,
      bedtimeHour: bedtimeHour,
      bedtimeMinute: bedtimeMinute,
      bedtimeAudioPath: bedtimeAudioPath,
      wakeUpEnabled: wakeUpEnabled,
      wakeUpHour: wakeUpHour,
      wakeUpMinute: wakeUpMinute,
      wakeUpAudioPath: wakeUpAudioPath,
      isSynced: 0,
      updatedAt: now,
    );

    notifyListeners();

    if (_repo != null) {
      try {
        await _repo!.saveSettings(_settings);
        _settings = _settings.copyWith(isSynced: 1);
        notifyListeners();
      } catch (e) {
        debugPrint("SleepAlarmProvider: Sync error: $e");
      }
    }

    if (_settings.bedtimeEnabled) {
      await _scheduleBedtime();
    } else {
      await Alarm.stop(bedtimeId);
    }

    if (_settings.wakeUpEnabled) {
      await _scheduleWakeUp();
    } else {
      await Alarm.stop(wakeUpId);
    }

    await _loadAlarms();
  }

  Future<void> _scheduleBedtime() async {
    final target = _getNextOccurrence(_settings.bedtimeHour, _settings.bedtimeMinute);

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: bedtimeId,
        dateTime: target,
        assetAudioPath: _settings.bedtimeAudioPath ?? 'assets/audio/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings: const VolumeSettings.fixed(volume: 0.7),
        notificationSettings: const NotificationSettings(
          title: "SLEEP TIME",
          body: "Time for your growth protocol recovery session.",
          stopButton: "STOP",
        ),
      ),
    );
  }

  Future<void> _scheduleWakeUp() async {
    final target = _getNextOccurrence(_settings.wakeUpHour, _settings.wakeUpMinute);

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: wakeUpId,
        dateTime: target,
        assetAudioPath: _settings.wakeUpAudioPath ?? 'assets/audio/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings: const VolumeSettings.fixed(volume: 0.7),
        notificationSettings: const NotificationSettings(
          title: "WAKE UP",
          body: "Rise and shine. Growth protocol active.",
          stopButton: "STOP",
        ),
      ),
    );
  }

  Future<void> setIndividualAlarm({
    required int id,
    required DateTime time,
    required String audioPath,
    required String title,
    required String body,
    double volume = 0.7,
  }) async {
    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: id,
        dateTime: time,
        assetAudioPath: audioPath,
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fixed(volume: volume),
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          stopButton: "STOP",
        ),
      ),
    );
    await _loadAlarms();
  }

  Future<void> stopAlarm(int id) async {
    await Alarm.stop(id);
    
    if (id == bedtimeId) {
       await updateSettings(bedtimeEnabled: false);
    } else if (id == wakeUpId) {
       await updateSettings(wakeUpEnabled: false);
    }
    await _loadAlarms();
  }

  Future<void> setNapAlarm(Duration duration, {String audioPath = 'assets/audio/alarm.mp3'}) async {
    final int id = IdUtils.stringToIntId("NAP_${const Uuid().v4()}");
    final DateTime time = DateTime.now().add(duration);

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: id,
        dateTime: time,
        assetAudioPath: audioPath,
        loopAudio: true,
        vibrate: true,
        volumeSettings: const VolumeSettings.fixed(volume: 0.7),
        notificationSettings: const NotificationSettings(
          title: "NAP OVER",
          body: "Power nap completed. Return to protocol.",
          stopButton: "STOP",
        ),
      ),
    );
    await _loadAlarms();
  }

  Future<void> stopAll() async {
    await Alarm.stopAll();
    await updateSettings(bedtimeEnabled: false, wakeUpEnabled: false);
    await _loadAlarms();
  }
}
