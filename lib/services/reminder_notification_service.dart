import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class ReminderNotificationService {
  ReminderNotificationService._();

  static final ReminderNotificationService instance =
      ReminderNotificationService._();

  static const int _dailyReminderId = 1001;
  static const String _enabledKey = 'daily_expense_reminder_enabled';
  static const String _hourKey = 'daily_expense_reminder_hour';
  static const String _minuteKey = 'daily_expense_reminder_minute';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    _initialized = true;
  }

  Future<void> ensureDefaultDailyReminder() async {
    if (kIsWeb) return;

    await initialize();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey);

    if (enabled == false) return;

    final hour = prefs.getInt(_hourKey) ?? 20;
    final minute = prefs.getInt(_minuteKey) ?? 0;

    await scheduleDailyExpenseReminder(hour: hour, minute: minute);
  }

  Future<void> scheduleDailyExpenseReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;

    await initialize();
    await _requestPermissions();

    final nextDate = _nextDate(hour, minute);

    const androidDetails = AndroidNotificationDetails(
      'daily_expense_reminders',
      'Recordatorios diarios',
      channelDescription: 'Recordatorios para registrar gastos diarios',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      _dailyReminderId,
      'Registra tus gastos de hoy',
      'Abre la app y anota lo que gastaste en menos de 1 minuto.',x
      nextDate,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily-expense-reminder',
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);
  }

  Future<void> disableDailyExpenseReminder() async {
    if (kIsWeb) return;

    await initialize();
    await _plugin.cancel(_dailyReminderId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  tz.TZDateTime _nextDate(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios =
        _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
