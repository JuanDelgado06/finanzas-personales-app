import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'fcm_foreground_channel',
        'Notificaciones push',
        description: 'Canal para mostrar push de Firebase en primer plano',
        importance: Importance.high,
      );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    await _requestPermissions();
    await _initLocalNotifications();
    await _configureMessageHandlers();

    final token = await _messaging.getToken();
    debugPrint('FCM token: $token');

    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM token refreshed: $newToken');
    });

    try {
      await _messaging.subscribeToTopic('finanzas-recordatorios');
    } catch (_) {
      // Topic subscription can fail on some emulators without Play Services.
    }

    _initialized = true;
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_androidChannel);
  }

  Future<void> _configureMessageHandlers() async {
    FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('FCM opened app from notification: ${message.messageId}');
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM initial message: ${initialMessage.messageId}');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'fcm_foreground_channel',
      'Notificaciones push',
      channelDescription: 'Canal para mostrar push de Firebase en primer plano',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Finanzas Personales',
      notification.body ?? 'Tienes una notificacion nueva',
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data.toString(),
    );
  }
}
