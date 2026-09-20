import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../firebase_options.dart';

const String kReminderTopic = 'finanzas-recordatorios';
const String kDailyReminderType = 'daily_reminder';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Con un payload `notification`, el sistema ya muestra la notificación
  // mientras la app está en segundo plano; aquí solo dejamos rastro.
  debugPrint(
    'FCM background message: ${message.messageId} data=${message.data}',
  );
}

class FirebaseMessagingService {
  FirebaseMessagingService._();

  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  /// Permite mostrar un aviso in-app cuando llega un mensaje en primer plano
  /// (en Android el sistema NO muestra notificaciones con la app abierta).
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool _handlersConfigured = false;
  String? _subscribedUid;

  /// Se llama en `main()`: registra los manejadores (foreground, tap desde
  /// segundo plano y app cerrada). No pide permisos ni suscribe: eso ocurre en
  /// [onUserSignedIn], una vez que hay sesión.
  Future<void> initialize() async {
    if (_handlersConfigured) return;
    _handlersConfigured = true;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      _log('foreground', message);
      _showInAppBanner(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _log('opened-from-background', message);
    });

    // App cerrada: la notificación que la abrió.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _log('opened-from-terminated', initialMessage);

    _messaging.onTokenRefresh.listen((t) => debugPrint('FCM token refreshed: $t'));
  }

  /// Pide permiso, imprime el token FCM y suscribe al topic. Una sola vez por
  /// usuario y ejecución; seguro llamarlo repetidamente.
  Future<void> onUserSignedIn(String uid) async {
    if (_subscribedUid == uid) return;
    _subscribedUid = uid;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM permiso: ${settings.authorizationStatus}');
      debugPrint('FCM token: ${await _messaging.getToken()}');
      await _messaging.subscribeToTopic(kReminderTopic);
      debugPrint('FCM suscrito al topic "$kReminderTopic"');
    } catch (e) {
      _subscribedUid = null; // permitir reintento en el próximo arranque
      debugPrint('FCM error al suscribir: $e');
    }
  }

  /// Prueba manual de notificaciones: pide permiso, suscribe al topic y
  /// devuelve un informe con el estado y el token FCM (para enviar un mensaje
  /// de prueba desde Firebase Console).
  Future<String> diagnose() async {
    final out = StringBuffer();
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      out.writeln('Permiso: ${settings.authorizationStatus.name}');
      await _messaging.subscribeToTopic(kReminderTopic);
      out.writeln('Suscrito al topic: $kReminderTopic');
      final token = await _messaging.getToken();
      out.writeln('\nToken FCM:\n$token');
      debugPrint('FCM token: $token');
    } catch (e) {
      out.writeln('Error: $e');
    }
    return out.toString();
  }

  /// Reinicia el estado al cerrar sesión para re-suscribir al siguiente login.
  void onUserSignedOut() => _subscribedUid = null;

  void _log(String origin, RemoteMessage message) {
    debugPrint(
      'FCM [$origin] id=${message.messageId} type=${message.data['type']} '
      'title=${message.notification?.title} data=${message.data}',
    );
  }

  void _showInAppBanner(RemoteMessage message) {
    final n = message.notification;
    final text = [n?.title, n?.body].whereType<String>().join(' — ');
    if (text.isEmpty && message.data['type'] != kDailyReminderType) return;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(text.isEmpty ? 'Recordatorio: registra tus gastos de hoy' : text),
      ),
    );
  }
}
