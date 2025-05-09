import 'package:flutter/material.dart';
import '../services/call_service.dart';

class CallProvider extends ChangeNotifier {
  final CallService _callService = CallService();
  bool _isInCall = false;
  String? _currentCallerName;
  String? _currentCallerId;
  String? _currentCallerAvatar;

  bool get isInCall => _isInCall;
  String? get currentCallerName => _currentCallerName;
  String? get currentCallerId => _currentCallerId;
  String? get currentCallerAvatar => _currentCallerAvatar;

  Future<void> showIncomingCall({
    required String callerName,
    required String callerId,
    String? avatar,
  }) async {
    _currentCallerName = callerName;
    _currentCallerId = callerId;
    _currentCallerAvatar = avatar;
    _isInCall = true;
    notifyListeners();

    await _callService.showIncomingCall(
      callerName: callerName,
      callerId: callerId,
      avatar: avatar,
    );
  }

  Future<void> endCall() async {
    await _callService.endCall();
    _resetCallState();
  }

  Future<void> endAllCalls() async {
    await _callService.endAllCalls();
    _resetCallState();
  }

  void _resetCallState() {
    _isInCall = false;
    _currentCallerName = null;
    _currentCallerId = null;
    _currentCallerAvatar = null;
    notifyListeners();
  }
} 