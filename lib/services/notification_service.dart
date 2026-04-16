import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // ✅ INIT FUNCTION
  static Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 🔔 Request permission
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('Permission: ${settings.authorizationStatus}');

    // 🔑 Get token
    String? token = await messaging.getToken();
    print('FCM Token: $token');

    // 💾 Save token
    await _saveTokenToFirestore(token);

    // 🔄 Token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('Token refreshed: $newToken');
      await _saveTokenToFirestore(newToken);
    });

    // 📱 Local notification init
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // 📩 Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotification(message.notification!, message.data);
      }
    });

    // 📩 Background handler
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);
  }

  // 💾 Save token to Firestore
  static Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'fcmToken': token}, SetOptions(merge: true));

    print('Token saved for user ${user.uid}');
  }

  // 📩 Background handler
  static Future<void> _backgroundHandler(RemoteMessage message) async {
    print('Background message: ${message.messageId}');
  }

  // 🔔 Show local notification
  static Future<void> _showNotification(
      RemoteNotification notification, Map<String, dynamic> data) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    final NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    String payload = '';
    if (data.containsKey('lat') && data.containsKey('lng')) {
      payload = 'maps:${data['lat']},${data['lng']}';
    }

    await _flutterLocalNotificationsPlugin.show(
      0,
      notification.title,
      notification.body,
      platformDetails,
      payload: payload,
    );
  }

  // 📍 Handle notification tap
  static void _onDidReceiveNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.startsWith('maps:')) {
      final coords = payload.substring(5).split(',');
      if (coords.length == 2) {
        final lat = double.tryParse(coords[0]);
        final lng = double.tryParse(coords[1]);
        if (lat != null && lng != null) {
          final url =
              'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
          launch(url);
        }
      }
    }
  }

  // ✅ Emergency send helper (used by EmergencyScreen)
  static Future<void> sendEmergencyNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformDetails =
        NotificationDetails(android: androidDetails);

    await _flutterLocalNotificationsPlugin.show(
      1,
      'SOS Alert',
      'Emergency SOS has been triggered.',
      platformDetails,
      payload: 'sos',
    );
  }

  // ✅ Get token (used in login)
  static Future<String?> getFCMToken() async {
    return await FirebaseMessaging.instance.getToken();
  }
}
