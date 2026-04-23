import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openMap(double lat, double lng) async {
  final Uri googleMapsUrl = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
  );

  if (await canLaunchUrl(googleMapsUrl)) {
    await launchUrl(
      googleMapsUrl,
      mode: LaunchMode.externalApplication,
    );
  } else {
    throw 'Could not open maps';
  }
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // 🔥 BACKGROUND HANDLER (IMPORTANT)
  @pragma('vm:entry-point')
  static Future<void> backgroundHandler(RemoteMessage message) async {
    print("🔴 Background message: ${message.messageId}");
  }

  // ✅ INIT
  static Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // 🔔 Permission
    await messaging.requestPermission();

    // 🔑 Token
    String? token = await messaging.getToken();
    print("FCM Token: $token");

    await _saveTokenToFirestore(token);

    FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenToFirestore);

    // 📱 Local notification init
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onTap,
    );

    // ✅ FOREGROUND
    FirebaseMessaging.onMessage.listen((message) {
      if (message.notification != null) {
        _showNotification(message);
      }
    });

    // ✅ CLICK WHEN APP IN BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message);
    });

    // ✅ CLICK WHEN APP TERMINATED
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }

  // 💾 Save token
  static Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }

  // 🔔 SHOW NOTIFICATION
  static Future<void> _showNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    final details = NotificationDetails(android: androidDetails);

    String payload = '';

    if (message.data.containsKey('lat')) {
      payload = 'maps:${message.data['lat']},${message.data['lng']}';
    }

    await _flutterLocalNotificationsPlugin.show(
      0,
      message.notification?.title,
      message.notification?.body,
      details,
      payload: payload,
    );
  }

  // 📍 HANDLE TAP
  static void _onTap(NotificationResponse response) {
    if (response.payload != null) {
      _handlePayload(response.payload!);
    }
  }

  static void _handleMessage(RemoteMessage message) {
    if (message.data.containsKey('lat')) {
      final lat = double.tryParse(message.data['lat']);
      final lng = double.tryParse(message.data['lng']);
      if (lat != null && lng != null) {
        openMap(lat, lng);
      }
    }
  }

  static void _handlePayload(String payload) {
    if (payload.startsWith('maps:')) {
      final coords = payload.substring(5).split(',');
      if (coords.length == 2) {
        final lat = double.tryParse(coords[0]);
        final lng = double.tryParse(coords[1]);
        if (lat != null && lng != null) {
          openMap(lat, lng);
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
