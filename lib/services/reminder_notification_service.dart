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
  static const int _instantTestReminderId = 1002;
  static const String _enabledKey = 'daily_expense_reminder_enabled';
  static const String _hourKey = 'daily_expense_reminder_hour';
  static const String _minuteKey = 'daily_expense_reminder_minute';
  static const int _defaultHour = 20;
  static const int _defaultMinute = 30;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
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

    final hour = prefs.getInt(_hourKey) ?? _defaultHour;
    final minute = prefs.getInt(_minuteKey) ?? _defaultMinute;

    await scheduleDailyExpenseReminder(hour: hour, minute: minute);
  }

  Future<({bool enabled, int hour, int minute})>
  getDailyReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      enabled: prefs.getBool(_enabledKey) ?? true,
      hour: prefs.getInt(_hourKey) ?? _defaultHour,
      minute: prefs.getInt(_minuteKey) ?? _defaultMinute,
    );
  }

  Future<tz.TZDateTime?> scheduleDailyExpenseReminder({
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return null;

    await initialize();
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      throw Exception('notifications-permission-denied');
    }

    final nextDate = _nextDate(hour, minute);

    const androidDetails = AndroidNotificationDetails(
      'daily_expense_reminders',
      'Recordatorios diarios',
      channelDescription: 'Recordatorios para registrar gastos diarios',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.zonedSchedule(
        _dailyReminderId,
        'Registra tus gastos de hoy',
        'Abre la app y anota lo que gastaste en menos de 1 minuto.',
        nextDate,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'daily-expense-reminder',
      );
    } catch (exactError) {
      // Some devices block exact alarms for regular apps; fallback keeps reminder working.
      try {
        await _plugin.zonedSchedule(
          _dailyReminderId,
          'Registra tus gastos de hoy',
          'Abre la app y anota lo que gastaste en menos de 1 minuto.',
          nextDate,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'daily-expense-reminder',
        );
      } catch (inexactError) {
        // Last fallback: schedule a one-shot notification at nextDate.
        try {
          await _plugin.zonedSchedule(
            _dailyReminderId,
            'Registra tus gastos de hoy',
            'Abre la app y anota lo que gastaste en menos de 1 minuto.',
            nextDate,
            details,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            payload: 'daily-expense-reminder',
          );
        } catch (oneShotError) {
          throw Exception(
            'notifications-schedule-failed | exact: $exactError | inexact: $inexactError | oneshot: $oneShotError',
          );
        }
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setInt(_hourKey, hour);
    await prefs.setInt(_minuteKey, minute);

    return nextDate;
  }

  Future<void> showInstantTestNotification() async {
    if (kIsWeb) return;

    await initialize();
    final hasPermission = await _requestPermissions();
    if (!hasPermission) {
      throw Exception('notifications-permission-denied');
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_expense_reminders',
      'Recordatorios diarios',
      channelDescription: 'Recordatorios para registrar gastos diarios',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      _instantTestReminderId,
      'Prueba de notificacion',
      'Si ves este aviso, las notificaciones estan funcionando.',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: 'daily-expense-reminder-test',
    );
  }

  Future<void> disableDailyExpenseReminder() async {
    if (kIsWeb) return;

    await initialize();
    await _plugin.cancel(_dailyReminderId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  tz.TZDateTime _nextDate(int hour, int minute) {
    final nowLocal = DateTime.now();
    var scheduledLocal = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day,
      hour,
      minute,
    );

    if (!scheduledLocal.isAfter(nowLocal)) {
      scheduledLocal = scheduledLocal.add(const Duration(days: 1));
    }

    return tz.TZDateTime.from(scheduledLocal, tz.local);
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<bool> _requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    try {
      await android?.requestExactAlarmsPermission();
    } catch (_) {
      // Optional on many devices/versions.
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final granted = (androidGranted ?? true) && (iosGranted ?? true);
    return granted;
  }
}
