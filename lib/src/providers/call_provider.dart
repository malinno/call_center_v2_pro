import 'package:flutter/foundation.dart';
import '../services/call_service.dart';

class CallProvider with ChangeNotifier {
  final CallService _callService = CallService();
  String? _currentCallId;
  String? _currentCallerName;
  String? _currentCallerNumber;
  String? _currentCallerAvatar;

  String? get currentCallId => _currentCallId;
  String? get currentCallerName => _currentCallerName;
  String? get currentCallerNumber => _currentCallerNumber;
  String? get currentCallerAvatar => _currentCallerAvatar;

  Future<void> showIncomingCall({
    required String callerName,
    required String callerNumber,
    String? callerAvatar,
  }) async {
    _currentCallId = await _callService.showIncomingCall(
      callerName: callerName,
      callerNumber: callerNumber,
      callerAvatar: callerAvatar,
    );
    _currentCallerName = callerName;
    _currentCallerNumber = callerNumber;
    _currentCallerAvatar = callerAvatar;
    notifyListeners();
  }

  Future<void> acceptCall(String callId) async {
    if (_currentCallId == callId) {
      // Xử lý logic khi chấp nhận cuộc gọi
      notifyListeners();
    }
  }

  Future<void> declineCall(String callId) async {
    if (_currentCallId == callId) {
      await _callService.endCall(callId);
      _resetCallState();
    }
  }

  Future<void> endCall() async {
    if (_currentCallId != null) {
      await _callService.endCall(_currentCallId!);
      _resetCallState();
    }
  }

  void _resetCallState() {
    _currentCallId = null;
    _currentCallerName = null;
    _currentCallerNumber = null;
    _currentCallerAvatar = null;
    notifyListeners();
  }
} 