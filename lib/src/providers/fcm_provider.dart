import 'package:flutter/foundation.dart';
import '../services/fcm_service.dart';

class FCMProvider with ChangeNotifier {
  final FCMService _fcmService = FCMService();
  String? _fcmToken;
  bool _isInitialized = false;

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _fcmService.initialize();
      _fcmToken = await _fcmService.getToken();
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> endCall(String callId) async {
    await _fcmService.endCall(callId);
  }
} 