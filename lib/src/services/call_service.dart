import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uuid/uuid.dart';

class CallService {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final Uuid _uuid = Uuid();

  Future<String> showIncomingCall({
    required String callerName,
    required String callerNumber,
    String? callerAvatar,
  }) async {
    final callId = _uuid.v4();

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
        'caller_avatar': callerAvatar,
      }),
    );

    return callId;
  }

  Future<void> endCall(String callId) async {
    await _localNotifications.cancel(callId.hashCode);
  }

  Future<void> endAllCalls() async {
    await _localNotifications.cancelAll();
  }
} 