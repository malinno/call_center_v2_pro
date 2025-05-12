import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:uuid/uuid.dart';

class FirebaseCallService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final Uuid _uuid = Uuid();
  String? _currentUuid;

  Future<void> initialize() async {
    // Khởi tạo Firebase
    await Firebase.initializeApp();

    // Lấy device token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token'); // In token để test

    // Cấu hình thông báo cục bộ
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Yêu cầu quyền thông báo
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Yêu cầu quyền hiển thị thông báo đầy màn hình
    await FlutterCallkitIncoming.requestFullIntentPermission();

    // Xử lý thông báo khi ứng dụng đang chạy
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _currentUuid = _uuid.v4();
      _handleIncomingCall(message);
    });

    // Xử lý thông báo khi ứng dụng ở background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _handleIncomingCall(RemoteMessage message) async {
    final callData = message.data;
    if (callData['type'] == 'incoming_call') {
      final params = CallKitParams(
        id: _currentUuid ?? _uuid.v4(),
        nameCaller: callData['caller_name'] ?? 'Unknown',
        appName: 'Your App Name',
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
  }

  Future<dynamic> getCurrentCall() async {
    var calls = await FlutterCallkitIncoming.activeCalls();
    if (calls is List) {
      if (calls.isNotEmpty) {
        print('DATA: $calls');
        _currentUuid = calls[0]['id'];
        return calls[0];
      } else {
        _currentUuid = "";
        return null;
      }
    }
  }
}

// Xử lý thông báo khi ứng dụng ở background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  final uuid = Uuid().v4();
  final callData = message.data;
  if (callData['type'] == 'incoming_call') {
    final params = CallKitParams(
      id: uuid,
      nameCaller: callData['caller_name'] ?? 'Unknown',
      appName: 'Your App Name',
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
} 