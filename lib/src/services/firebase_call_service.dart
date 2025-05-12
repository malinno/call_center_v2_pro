import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';
import 'firebase_service.dart';

class FirebaseCallService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final Uuid _uuid = Uuid();
  String? _currentUuid;

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await FlutterCallkitIncoming.requestFullIntentPermission();

    FirebaseMessaging.onMessage.listen(_handleIncomingCall);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> _handleIncomingCall(RemoteMessage message) async {
    final callData = message.data;
    if (callData['type'] == 'incoming_call') {
      _currentUuid = _uuid.v4();
      await _showIncomingCall(callData);
    }
  }

  Future<void> _showIncomingCall(Map<String, dynamic> callData) async {
    final params = CallKitParams(
      id: _currentUuid ?? _uuid.v4(),
      nameCaller: callData['caller_name'] ?? 'Unknown',
      appName: 'SOLY',
      avatar: callData['caller_avatar'],
      handle: callData['caller_number'],
      type: 0,
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      extra: <String, dynamic>{'userId': callData['caller_id']},
      headers: <String, dynamic>{'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
      ),
      ios: const IOSParams(
        handleType: '',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
    _setupCallkitListeners(callData);
  }

  void _setupCallkitListeners(Map<String, dynamic> callData) {
    FlutterCallkitIncoming.onEvent.listen((event) async {
      switch (event!.event) {
        case Event.actionCallAccept:
          _openCallScreen(callData);
          break;
        case Event.actionCallDecline:
        case Event.actionCallEnded:
        case Event.actionCallTimeout:
          if (_currentUuid != null) {
            await FlutterCallkitIncoming.endCall(_currentUuid!);
          }
          break;
      }
    });
  }

  void _openCallScreen(Map<String, dynamic> callData) {
    // TODO: Implement navigation to call screen
  }

  Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    final callData = message.data;
    if (callData['type'] == 'incoming_call') {
      _openCallScreen(callData);
    }
  }

  Future<dynamic> getCurrentCall() async {
    var calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List && calls.isNotEmpty) {
      _currentUuid = calls[0]['id'];
      return calls[0];
    }
    _currentUuid = null;
    return null;
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Sử dụng FirebaseService để khởi tạo Firebase
    await FirebaseService.instance.initialize();

    final callData = message.data;
    if (callData['type'] == 'incoming_call') {
      final uuid = Uuid().v4();
      final params = CallKitParams(
        id: uuid,
        nameCaller: callData['caller_name'] ?? 'Unknown',
        appName: 'SOLY',
        avatar: callData['caller_avatar'],
        handle: callData['caller_number'],
        type: 0,
        duration: 30000,
        textAccept: 'Accept',
        textDecline: 'Decline',
        extra: <String, dynamic>{'userId': callData['caller_id']},
        headers: <String, dynamic>{'platform': 'flutter'},
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: true,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#0955fa',
          actionColor: '#4CAF50',
          textColor: '#ffffff',
        ),
        ios: const IOSParams(
          handleType: '',
          supportsVideo: true,
          maximumCallGroups: 2,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'default',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: true,
          supportsHolding: true,
          supportsGrouping: false,
          supportsUngrouping: false,
          ringtonePath: 'system_ringtone_default',
        ),
      );
      await FlutterCallkitIncoming.showCallkitIncoming(params);
    }
  } catch (e) {
    // Handle error silently
  }
} 