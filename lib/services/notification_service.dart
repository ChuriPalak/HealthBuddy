import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:googleapis/fcm/v1.dart' as fcm;
import 'package:flutter/services.dart' show rootBundle;

class NotificationService {
  static const String _serviceAccountPath =
      'healthbuddy-1fc61-firebase-adminsdk-fbsvc-acdc2b196c.json';

  static final FlutterLocalNotificationsPlugin
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> sendEmergencyNotification(
      List<String> tokens, String title, String body) async {
    print('Sending emergency notification to tokens: $tokens');

    final jsonString = await rootBundle.loadString(_serviceAccountPath);
    final json = jsonDecode(jsonString);
    final credentials = auth.ServiceAccountCredentials.fromJson(json);
    final client = await auth.clientViaServiceAccount(
        credentials, ['https://www.googleapis.com/auth/firebase.messaging']);
    final fcmApi = fcm.FirebaseCloudMessagingApi(client);
    final projectId = json['project_id'];

    for (final token in tokens) {
      final message = fcm.Message(
        token: token,
        notification: fcm.Notification(
          title: title,
          body: body,
        ),
        data: {
          'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          'emergency_id': '12345',
        },
      );

      try {
        final response = await fcmApi.projects.messages.send(
            fcm.SendMessageRequest(message: message), 'projects/$projectId');
        print('Notification sent to $token: ${response.toJson()}');
      } catch (e) {
        print('Failed to send notification to $token: $e');
      }
    }

    client.close();
  }

  static Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission for iOS
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Get the FCM token
    String? token = await messaging.getToken();
    print('FCM Token: $token');

    // Save token to Firestore (if logged in)
    await _saveTokenToFirestore(token);

    // Listen for token refresh and save that too
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('FCM token refreshed: $newToken');
      await _saveTokenToFirestore(newToken);
    });

    // Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showNotification(message.notification!);
      }
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<void> _saveTokenToFirestore(String? token) async {
    if (token == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
      print('Saved FCM token to Firestore for user ${user.uid}');
    } catch (e) {
      print('Failed to save FCM token to Firestore: $e');
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print('Handling a background message: ${message.messageId}');
  }

  static Future<void> _showNotification(RemoteNotification notification) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Notifications',
      channelDescription: 'Channel for emergency alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      notification.title,
      notification.body,
      platformChannelSpecifics,
    );
  }

  static Future<String?> getFCMToken() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    return await messaging.getToken();
  }
}
