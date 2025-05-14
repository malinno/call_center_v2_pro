import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

class FCMService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Uuid _uuid = Uuid();
  final _logger = Logger();

  Future<void> initialize() async {
    try {
      // Request permission for notifications
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Initialize local notifications
      const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationResponse,
      );

      // Handle incoming messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.d('Got a message whilst in the foreground!');
        _logger.d('Message data: ${message.data}');
        _handleIncomingCall(message);
      });

      // Handle incoming messages when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.d('Message opened app from background state!');
        _logger.d('Message data: ${message.data}');
        _handleIncomingCall(message);
      });

      // Handle initial message when app is launched from terminated state
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _logger.d('App launched from terminated state by notification');
        _logger.d('Message data: ${initialMessage.data}');
        _handleIncomingCall(initialMessage);
      }

      // Configure notification channel for Android
      await _configureNotificationChannel();
    } catch (e) {
      _logger.e('Error initializing FCM: $e');
    }
  }

  Future<void> _configureNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'incoming_calls',
      'Incoming Calls',
      description: 'Notifications for incoming calls',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      _logger.e('Error getting FCM token: $e');
      return null;
    }
  }

  void _handleIncomingCall(RemoteMessage message) {
    try {
      final data = message.data;
      _logger.d('Handling incoming call with data: $data');
      
      if (data['type'] == 'incoming_call') {
        final callId = data['call_id'] ?? _uuid.v4();
        final callerName = data['caller_name'] ?? 'Unknown';
        final callerNumber = data['caller_number'] ?? 'Unknown';

        // Show incoming call notification
        showIncomingCallNotification(
          callId: callId,
          callerName: callerName,
          callerNumber: callerNumber,
        );
      }
    } catch (e) {
      _logger.e('Error handling incoming call: $e');
    }
  }

  Future<void> showIncomingCallNotification({
    required String callId,
    required String callerName,
    required String callerNumber,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'incoming_calls',
        'Incoming Calls',
        channelDescription: 'Notifications for incoming calls',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ringtone'),
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        actions: [
          AndroidNotificationAction('accept', 'Accept'),
          AndroidNotificationAction('decline', 'Decline'),
        ],
        visibility: NotificationVisibility.public,
        timeoutAfter: 60000, // 1 minute timeout
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        callId.hashCode,
        'Incoming Call',
        '$callerName ($callerNumber)',
        notificationDetails,
        payload: jsonEncode({
          'type': 'incoming_call',
          'call_id': callId,
          'caller_name': callerName,
          'caller_number': callerNumber,
        }),
      );
      _logger.d('Incoming call notification shown successfully');
    } catch (e) {
      _logger.e('Error showing incoming call notification: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    try {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _logger.d('Notification response: ${response.actionId}');
        _logger.d('Notification payload: $data');
      }
    } catch (e) {
      _logger.e('Error handling notification response: $e');
    }
  }

  Future<void> endCall(String callId) async {
    try {
      await _localNotifications.cancel(callId.hashCode);
      _logger.d('Call notification cancelled: $callId');
    } catch (e) {
      _logger.e('Error cancelling call notification: $e');
    }
  }
} 