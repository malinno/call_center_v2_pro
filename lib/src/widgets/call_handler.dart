import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';

class CallHandler extends StatefulWidget {
  final Widget child;

  const CallHandler({Key? key, required this.child}) : super(key: key);

  @override
  State<CallHandler> createState() => _CallHandlerState();
}

class _CallHandlerState extends State<CallHandler> {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        
        if (data['type'] == 'incoming_call') {
          switch (response.actionId) {
            case 'accept':
              callProvider.acceptCall(data['call_id']);
              break;
            case 'decline':
              callProvider.declineCall(data['call_id']);
              break;
          }
        }
      } catch (e) {
        print('Error processing notification response: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
} 