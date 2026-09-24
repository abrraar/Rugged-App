// lib/core/services/notification_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../features/tracker/calorie/model/saved_meal.dart';
import '../../features/tracker/supplement/model/supplement.dart';
import '../../features/tracker/supplement/model/supplement_stack.dart';
import '../../features/tracker/hydration/model/hydration_settings.dart';
import '../../features/tracker/hydration/model/hydration_reminder.dart';
import '../utils/id_utils.dart';
import '../../features/tracker/body_composition/model/body_comp_settings.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  final List<void Function(String?, String?)> _actionListeners = [];

  void addNotificationActionListener(void Function(String?, String?) listener) {
    _actionListeners.add(listener);
  }

  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Initialize Timezones (Crucial for scheduled notifications)
    tz_data.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint("NotificationService: Timezone set to $timeZoneName");
    } catch (e) {
      debugPrint("NotificationService Warning: Timezone initialization failed. $e");
      // Fallback to a valid location if detection fails
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2. Android Settings - Using the standard @mipmap/ic_launcher
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS Settings
    final DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'hydration_category',
          actions: [
            DarwinNotificationAction.plain('log_water', 'LOG WATER'),
          ],
        ),
        DarwinNotificationCategory(
          'meal_category',
          actions: [
            DarwinNotificationAction.plain('log_meal', 'LOG MEAL'),
          ],
        ),
      ],
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // 4. Initialize the plugin
    try {
      await _notificationsPlugin.initialize(
        settings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint("Notification clicked: ${response.payload} | Action: ${response.actionId}");
          for (var listener in _actionListeners) {
            listener(response.payload, response.actionId);
          }
        },
      );

      // Request Permissions for Android 13+ and iOS
      if (Platform.isAndroid) {
        final androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        
        await androidImplementation?.requestNotificationsPermission();
        await androidImplementation?.requestExactAlarmsPermission();
      }

      // Create a high importance channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'rugged_channel',
        'Rugged Reminders',
        description: 'Reminders for your supplements and hydration',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
          
      _isInitialized = true;
      debugPrint("NotificationService: Initialized successfully");
    } catch (e) {
      debugPrint("NotificationService Fatal Error: $e");
    }
  }

  /// Simple instant notification for testing
  Future<void> showInstantNotification({
    int id = 0,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'heavy_duty_channel',
      'System Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
    debugPrint("NotificationService: Instant notification sent: $title");
  }

  /// Schedules reminders following the video's zonedSchedule approach
  Future<void> scheduleSupplementReminders(Supplement supplement) async {
    if (!_isInitialized) await init();

    debugPrint("NotificationService: Starting schedule for ${supplement.name}");
    
    // Default to NOT cancelling low stock notification here to prevent flicker
    await cancelSupplementReminders(supplement.id, cancelLowStock: false);

    if (!supplement.notificationsEnabled || !supplement.isActive) {
      debugPrint("NotificationService: Scheduling aborted (Disabled or Inactive)");
      await cancelLowStockNotification(supplement.id);
      return;
    }

    final int baseId = IdUtils.stringToIntId(supplement.id);
    int totalScheduled = 0;

    for (var reminder in supplement.reminders) {
      // 1. Handle Low Stock Alerts (Check value of inventory)
      if (reminder.type == ReminderType.lowStock) {
        if (reminder.value >= 0 && (supplement.remainingStock ?? 0.0) <= reminder.value) {
          await showLowStockNotification(supplement);
        }
        continue;
      }

      // 2. Handle Intake Reminders (Check date/time or interval)
      if (reminder.type != ReminderType.intake) continue;

      if (reminder.reminderMode == ReminderMode.interval) {
        final int intervalValue = reminder.intervalValue ?? 60;
        final IntervalUnit intervalUnit = reminder.intervalUnit ?? IntervalUnit.minute;

        RepeatInterval? repeatInterval;
        if (intervalUnit == IntervalUnit.minute && intervalValue == 1) {
          repeatInterval = RepeatInterval.everyMinute;
        } else if (intervalUnit == IntervalUnit.hour && intervalValue == 1) {
          repeatInterval = RepeatInterval.hourly;
        } else if (intervalUnit == IntervalUnit.day && intervalValue == 1) {
          repeatInterval = RepeatInterval.daily;
        }

        if (repeatInterval != null) {
          await _notificationsPlugin.periodicallyShow(
            baseId + 1000,
            'Time for your ${supplement.name}',
            'Take ${reminder.value} ${supplement.servingUnit}',
            repeatInterval,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'heavy_duty_channel',
                'Supplement Reminders',
                importance: Importance.max,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: '${supplement.id}|${reminder.value}',
          );
          totalScheduled++;
        } else {
          // Fallback for custom intervals (e.g. every 30 mins, every 4 hours)
          int minutesStep = 0;
          if (intervalUnit == IntervalUnit.minute) minutesStep = intervalValue;
          if (intervalUnit == IntervalUnit.hour) minutesStep = intervalValue * 60;
          
          if (minutesStep > 0) {
            for (int m = 0; m < 1440; m += minutesStep) {
              final int h = m ~/ 60;
              final int min = m % 60;
              final int notificationId = baseId + 2000 + m;
              
              await _notificationsPlugin.zonedSchedule(
                notificationId,
                'Time for your ${supplement.name}',
                'Take ${reminder.value} ${supplement.servingUnit}',
                _nextInstanceDaily(TimeOfDay(hour: h, minute: min)),
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'heavy_duty_channel', 'Supplement Reminders',
                    importance: Importance.max, priority: Priority.high,
                  ),
                  iOS: DarwinNotificationDetails(),
                ),
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: DateTimeComponents.time,
                payload: '${supplement.id}|${reminder.value}',
              );
              totalScheduled++;
            }
          }
        }
      } else {
        // Fixed Schedule
        for (int day in reminder.days) {
          for (int i = 0; i < reminder.times.length; i++) {
            final time = reminder.times[i];
            final int notificationId = baseId + (day * 100) + i;
            await _notificationsPlugin.zonedSchedule(
              notificationId,
              'Time for your ${supplement.name}',
              'Take ${reminder.value} ${supplement.servingUnit}',
              _nextInstance(day, time),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'heavy_duty_channel', 'Supplement Reminders',
                  importance: Importance.max, priority: Priority.high,
                ),
                iOS: DarwinNotificationDetails(),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: '${supplement.id}|${reminder.value}',
            );
            totalScheduled++;
          }
        }
      }
    }
    debugPrint("NotificationService: Finished scheduling. Total notifications: $totalScheduled");
  }

  tz.TZDateTime _nextInstance(int dayOfWeek, TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    // dayOfWeek mapping: 1 (Mon) to 7 (Sun)
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // Ensure we are at least 1 minute in the future to avoid instant triggers/past errors
    if (scheduledDate.isBefore(now.add(const Duration(minutes: 1)))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Keep adding days until we hit the requested day of the week
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceDaily(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (scheduledDate.isBefore(now.add(const Duration(minutes: 1)))) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelSupplementReminders(String id, {bool cancelLowStock = false}) async {
    if (!_isInitialized) await init();
    final int baseId = IdUtils.stringToIntId(id);
    debugPrint("NotificationService: Cancelling reminders for baseId $baseId");

    for (int day = 1; day <= 7; day++) {
      for (int i = 0; i < 50; i++) {
        await _notificationsPlugin.cancel(baseId + (day * 100) + i);
      }
    }
    await _notificationsPlugin.cancel(baseId + 999); // Cancel diagnostic
    await _notificationsPlugin.cancel(baseId + 1000); // Interval standard
    
    // Clear the full range of custom interval minute slots
    for (int m = 0; m <= 1440; m++) {
      await _notificationsPlugin.cancel(baseId + 2000 + m);
    }
    
    if (cancelLowStock) {
      await cancelLowStockNotification(id);
    }
  }

  Future<void> cancelLowStockNotification(String id) async {
    if (!_isInitialized) await init();
    await _notificationsPlugin.cancel(IdUtils.stringToIntId('${id}_low'));
  }

  Future<void> showLowStockNotification(Supplement supplement) async {
    if (!_isInitialized) await init();
    await _notificationsPlugin.show(
      IdUtils.stringToIntId('${supplement.id}_low'),
      'LOW STOCK: ${supplement.name.toUpperCase()}',
      'You are running low! Remaining: ${supplement.remainingStock?.toStringAsFixed(1)} ${supplement.weightUnit}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'heavy_duty_channel',
          'Supplement Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> scheduleStackReminders(SupplementStack stack) async {
    if (!_isInitialized) await init();
    await cancelSupplementReminders(stack.id, cancelLowStock: false);
    
    if (!stack.notificationsEnabled) {
      debugPrint("NotificationService: Stack notifications disabled for ${stack.name}");
      return;
    }

    final int baseId = IdUtils.stringToIntId(stack.id);
    int totalScheduled = 0;

    for (var reminder in stack.reminders) {
      // 1. Handle Low Stock Alerts for each item in the stack (Check inventory)
      if (reminder.type == ReminderType.lowStock) {
        final supplement = stack.items.firstWhere(
          (s) => s.id == reminder.supplementId,
          orElse: () => Supplement(id: '', name: '', servingUnit: '', weightPerServing: 0, weightUnit: ''),
        );
        if (supplement.id.isNotEmpty && (supplement.remainingStock ?? 0.0) <= reminder.value) {
          await showLowStockNotification(supplement);
        }
        continue;
      }

      // 2. Handle Intake Reminders
      if (reminder.type != ReminderType.intake) continue;

      final String valuesPayload = stack.items
          .map((item) => reminder.stackItemValues?[item.id] ?? 1.0)
          .join(',');

      if (reminder.reminderMode == ReminderMode.interval) {
        final int intervalValue = reminder.intervalValue ?? 60;
        final IntervalUnit intervalUnit = reminder.intervalUnit ?? IntervalUnit.minute;

        RepeatInterval? repeatInterval;
        if (intervalUnit == IntervalUnit.minute && intervalValue == 1) {
          repeatInterval = RepeatInterval.everyMinute;
        } else if (intervalUnit == IntervalUnit.hour && intervalValue == 1) {
          repeatInterval = RepeatInterval.hourly;
        } else if (intervalUnit == IntervalUnit.day && intervalValue == 1) {
          repeatInterval = RepeatInterval.daily;
        }

        if (repeatInterval != null) {
          await _notificationsPlugin.periodicallyShow(
            baseId + 1000,
            'STACK: ${stack.name}',
            'Time for your routine',
            repeatInterval,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'heavy_duty_channel', 'Supplement Reminders',
                importance: Importance.max, priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: '${stack.id}|$valuesPayload',
          );
          totalScheduled++;
        } else {
          int minutesStep = 0;
          if (intervalUnit == IntervalUnit.minute) minutesStep = intervalValue;
          if (intervalUnit == IntervalUnit.hour) minutesStep = intervalValue * 60;

          if (minutesStep > 0) {
            for (int m = 0; m < 1440; m += minutesStep) {
              final int h = m ~/ 60;
              final int min = m % 60;
              final int notificationId = baseId + 2000 + m;
              await _notificationsPlugin.zonedSchedule(
                notificationId,
                'STACK: ${stack.name}',
                'Time for your routine',
                _nextInstanceDaily(TimeOfDay(hour: h, minute: min)),
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'heavy_duty_channel', 'Supplement Reminders',
                    importance: Importance.max, priority: Priority.high,
                  ),
                  iOS: DarwinNotificationDetails(),
                ),
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: DateTimeComponents.time,
                payload: '${stack.id}|$valuesPayload',
              );
              totalScheduled++;
            }
          }
        }
      } else {
        // Fixed Schedule
        for (int day in reminder.days) {
          for (int i = 0; i < reminder.times.length; i++) {
            final time = reminder.times[i];
            final int notificationId = baseId + (day * 100) + i;
            await _notificationsPlugin.zonedSchedule(
              notificationId,
              'STACK: ${stack.name}',
              'Time for your routine',
              _nextInstance(day, time),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'heavy_duty_channel', 'Supplement Reminders',
                  importance: Importance.max, priority: Priority.high,
                ),
                iOS: DarwinNotificationDetails(),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: '${stack.id}|$valuesPayload',
            );
            totalScheduled++;
          }
        }
      }
    }
    debugPrint("NotificationService: Finished scheduling stack. Total notifications: $totalScheduled");
  }

  Future<void> scheduleHydrationReminders(HydrationSettings settings) async {
    if (!_isInitialized) await init();
    
    // Use a fixed base ID for hydration reminders to easily cancel them
    const String hydrationBaseIdStr = "hydration_tracker_reminders";
    final int baseId = IdUtils.stringToIntId(hydrationBaseIdStr);
    
    // Cancel all previous hydration reminders
    // We cover a large range to ensure any old custom intervals are cleared
    for (int i = 0; i < 3000; i++) {
      await _notificationsPlugin.cancel(baseId + i);
    }

    if (!settings.remindersEnabled || settings.reminders.isEmpty) {
      debugPrint("NotificationService: Hydration reminders disabled or empty.");
      return;
    }

    int totalScheduled = 0;
    for (var reminder in settings.reminders) {
      if (reminder.mode == HydrationReminderMode.interval) {
        final int intervalValue = reminder.intervalValue ?? 60;
        final HydrationIntervalUnit intervalUnit = reminder.intervalUnit ?? HydrationIntervalUnit.minute;

        RepeatInterval? repeatInterval;
        if (intervalUnit == HydrationIntervalUnit.minute && intervalValue == 1) {
          repeatInterval = RepeatInterval.everyMinute;
        } else if (intervalUnit == HydrationIntervalUnit.hour && intervalValue == 1) {
          repeatInterval = RepeatInterval.hourly;
        }

        if (repeatInterval != null) {
          await _notificationsPlugin.periodicallyShow(
            baseId + 1000,
            'Time to hydrate!',
            'Keep your performance high. Drink some water.',
            repeatInterval,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'heavy_duty_channel',
                'Rugged Reminders',
                importance: Importance.max,
                priority: Priority.high,
                actions: [
                  AndroidNotificationAction('log_water', 'LOG WATER', showsUserInterface: true),
                ],
              ),
              iOS: DarwinNotificationDetails(categoryIdentifier: 'hydration_category'),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );
          totalScheduled++;
        } else {
          // Custom interval logic mirrored from supplement
          int minutesStep = 0;
          if (intervalUnit == HydrationIntervalUnit.minute) minutesStep = intervalValue;
          if (intervalUnit == HydrationIntervalUnit.hour) minutesStep = intervalValue * 60;

          if (minutesStep > 0) {
            for (int m = 0; m < 1440; m += minutesStep) {
              final int h = m ~/ 60;
              final int min = m % 60;
              final int notificationId = baseId + 1100 + m;
              
              await _notificationsPlugin.zonedSchedule(
                notificationId,
                'Time to hydrate!',
                'Keep your performance high. Drink some water.',
                _nextInstanceDaily(TimeOfDay(hour: h, minute: min)),
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'heavy_duty_channel',
                    'Rugged Reminders',
                    importance: Importance.max,
                    priority: Priority.high,
                    actions: [
                      AndroidNotificationAction('log_water', 'LOG WATER', showsUserInterface: true),
                    ],
                  ),
                  iOS: DarwinNotificationDetails(categoryIdentifier: 'hydration_category'),
                ),
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: DateTimeComponents.time,
              );
              totalScheduled++;
            }
          }
        }
      } else {
        // Fixed Schedule logic mirrored from supplement
        for (int day in reminder.days) {
          for (int i = 0; i < reminder.times.length; i++) {
            final time = reminder.times[i];
            final int notificationId = baseId + (day * 100) + i;

            await _notificationsPlugin.zonedSchedule(
              notificationId,
              'Time to hydrate!',
              'Keep your performance high. Drink some water.',
              _nextInstance(day, time),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'heavy_duty_channel',
                  'Rugged Reminders',
                  importance: Importance.max,
                  priority: Priority.high,
                  actions: [
                    AndroidNotificationAction('log_water', 'LOG WATER', showsUserInterface: true),
                  ],
                ),
                iOS: DarwinNotificationDetails(categoryIdentifier: 'hydration_category'),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
            );
            totalScheduled++;
          }
        }
      }
    }
    debugPrint("NotificationService: Finished scheduling hydration. Total scheduled: $totalScheduled");
  }

  Future<void> scheduleMealReminders(SavedMeal meal) async {
    if (!_isInitialized) await init();

    await cancelMealReminders(meal.id);

    if (!meal.notificationsEnabled) {
      return;
    }

    final int baseId = IdUtils.stringToIntId(meal.id);
    int totalScheduled = 0;

    for (var reminder in meal.reminders) {
      if (reminder.reminderMode == CalorieReminderMode.interval) {
        final int intervalValue = reminder.intervalValue ?? 60;
        final CalorieIntervalUnit intervalUnit = reminder.intervalUnit ?? CalorieIntervalUnit.minute;

        RepeatInterval? repeatInterval;
        if (intervalUnit == CalorieIntervalUnit.minute && intervalValue == 1) {
          repeatInterval = RepeatInterval.everyMinute;
        } else if (intervalUnit == CalorieIntervalUnit.hour && intervalValue == 1) {
          repeatInterval = RepeatInterval.hourly;
        } else if (intervalUnit == CalorieIntervalUnit.day && intervalValue == 1) {
          repeatInterval = RepeatInterval.daily;
        }

        if (repeatInterval != null) {
          await _notificationsPlugin.periodicallyShow(
            baseId + 3000,
            'Meal Reminder: ${meal.name}',
            'Time to record your meal.',
            repeatInterval,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'heavy_duty_channel',
                'Calorie Reminders',
                importance: Importance.max,
                priority: Priority.high,
                actions: [
                  AndroidNotificationAction('log_meal', 'LOG MEAL', showsUserInterface: true),
                ],
              ),
              iOS: DarwinNotificationDetails(categoryIdentifier: 'meal_category'),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: meal.id,
          );
          totalScheduled++;
        } else {
          int minutesStep = 0;
          if (intervalUnit == CalorieIntervalUnit.minute) minutesStep = intervalValue;
          if (intervalUnit == CalorieIntervalUnit.hour) minutesStep = intervalValue * 60;
          
          if (minutesStep > 0) {
            for (int m = 0; m < 1440; m += minutesStep) {
              final int h = m ~/ 60;
              final int min = m % 60;
              final int notificationId = baseId + 4000 + m;
              
              await _notificationsPlugin.zonedSchedule(
                notificationId,
                'Meal Reminder: ${meal.name}',
                'Time to record your meal.',
                _nextInstanceDaily(TimeOfDay(hour: h, minute: min)),
                const NotificationDetails(
                  android: AndroidNotificationDetails(
                    'heavy_duty_channel', 'Calorie Reminders',
                    importance: Importance.max, priority: Priority.high,
                    actions: [AndroidNotificationAction('log_meal', 'LOG MEAL', showsUserInterface: true)],
                  ),
                  iOS: DarwinNotificationDetails(categoryIdentifier: 'meal_category'),
                ),
                androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
                matchDateTimeComponents: DateTimeComponents.time,
                payload: meal.id,
              );
              totalScheduled++;
            }
          }
        }
      } else {
        // Fixed Schedule
        for (int day in reminder.days) {
          for (int i = 0; i < reminder.times.length; i++) {
            final time = reminder.times[i];
            final int notificationId = baseId + (day * 100) + i;
            await _notificationsPlugin.zonedSchedule(
              notificationId,
              'Meal Reminder: ${meal.name}',
              'Time to record your meal.',
              _nextInstance(day, time),
              const NotificationDetails(
                android: AndroidNotificationDetails(
                  'heavy_duty_channel', 'Calorie Reminders',
                  importance: Importance.max, priority: Priority.high,
                  actions: [AndroidNotificationAction('log_meal', 'LOG MEAL', showsUserInterface: true)],
                ),
                iOS: DarwinNotificationDetails(categoryIdentifier: 'meal_category'),
              ),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              payload: meal.id,
            );
            totalScheduled++;
          }
        }
      }
    }
    debugPrint("NotificationService: Finished scheduling meal. Total notifications: $totalScheduled");
  }

  Future<void> cancelMealReminders(String id) async {
    if (!_isInitialized) await init();
    final int baseId = IdUtils.stringToIntId(id);
    
    for (int day = 1; day <= 7; day++) {
      for (int i = 0; i < 50; i++) {
        await _notificationsPlugin.cancel(baseId + (day * 100) + i);
      }
    }
    await _notificationsPlugin.cancel(baseId + 3000);
    for (int m = 0; m <= 1440; m++) {
      await _notificationsPlugin.cancel(baseId + 4000 + m);
    }
  }

  Future<void> scheduleBodyCompReminders(BodyCompSettings settings) async {
    if (!_isInitialized) await init();

    // Base IDs for each type
    const String weightBase = "body_comp_weight";
    const String fatBase = "body_comp_fat";
    const String muscleBase = "body_comp_muscle";

    await _cancelBodyCompReminders(weightBase);
    await _cancelBodyCompReminders(fatBase);
    await _cancelBodyCompReminders(muscleBase);

    if (settings.weightRemindersEnabled) {
      await _scheduleReminders(weightBase, "Weight", settings.weightReminders);
    }
    if (settings.fatRemindersEnabled) {
      await _scheduleReminders(fatBase, "Body Fat", settings.fatReminders);
    }
    if (settings.muscleRemindersEnabled) {
      await _scheduleReminders(muscleBase, "Muscle Mass", settings.muscleReminders);
    }
  }

  Future<void> _cancelBodyCompReminders(String base) async {
    final int baseId = IdUtils.stringToIntId(base);
    for (int day = 1; day <= 7; day++) {
      for (int i = 0; i < 20; i++) {
        await _notificationsPlugin.cancel(baseId + (day * 100) + i);
      }
    }
  }

  Future<void> _scheduleReminders(String base, String label, List<BodyCompReminder> reminders) async {
    final int baseId = IdUtils.stringToIntId(base);
    for (var reminder in reminders) {
      for (int day in reminder.days) {
        for (int i = 0; i < reminder.times.length; i++) {
          final time = reminder.times[i];
          final int notificationId = baseId + (day * 100) + i;
          await _notificationsPlugin.zonedSchedule(
            notificationId,
            'Time to track your $label',
            'Stay consistent with your Rugged progress.',
            _nextInstance(day, time),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'heavy_duty_channel', 'Body Comp Reminders',
                importance: Importance.max, priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    }
  }
}
