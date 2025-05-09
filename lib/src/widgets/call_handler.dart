import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import 'call_screen.dart';

class CallHandler extends StatefulWidget {
  final Widget child;

  const CallHandler({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<CallHandler> createState() => _CallHandlerState();
}

class _CallHandlerState extends State<CallHandler> {
  @override
  void initState() {
    super.initState();
    _setupCallkitListener();
  }

  void _setupCallkitListener() {
    FlutterCallkitIncoming.onEvent.listen((event) {
      switch (event!.event) {
        case Event.actionCallIncoming:
          // Cuộc gọi đến
          break;
        case Event.actionCallStart:
          // Bắt đầu cuộc gọi đi
          _showCallScreen(false);
          break;
        case Event.actionCallAccept:
          // Người dùng chấp nhận cuộc gọi
          _showCallScreen(true);
          break;
        case Event.actionCallDecline:
          // Người dùng từ chối cuộc gọi
          context.read<CallProvider>().endCall();
          break;
        case Event.actionCallEnded:
          // Cuộc gọi kết thúc
          context.read<CallProvider>().endCall();
          break;
        case Event.actionCallTimeout:
          // Cuộc gọi hết thời gian chờ
          context.read<CallProvider>().endCall();
          break;
        case Event.actionCallCallback:
          // Chỉ Android - nhấp vào hành động "Gọi lại" từ thông báo cuộc gọi nhỡ
          break;
        case Event.actionCallToggleHold:
          // Chỉ iOS - tạm dừng cuộc gọi
          break;
        case Event.actionCallToggleMute:
          // Chỉ iOS - tắt/bật mic
          break;
        case Event.actionCallToggleDmtf:
          // Chỉ iOS - bàn phím DTMF
          break;
        case Event.actionCallToggleGroup:
          // Chỉ iOS - chuyển đổi nhóm cuộc gọi
          break;
        case Event.actionCallToggleAudioSession:
          // Chỉ iOS - chuyển đổi phiên âm thanh
          break;
        case Event.actionDidUpdateDevicePushTokenVoip:
          // Chỉ iOS - cập nhật token push VoIP
          break;
        case Event.actionCallCustom:
          // Hành động tùy chỉnh
          break;
      }
    });
  }

  void _showCallScreen(bool isIncoming) {
    final callProvider = context.read<CallProvider>();
    if (callProvider.currentCallerName != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CallScreen(
            callerName: callProvider.currentCallerName!,
            callerId: callProvider.currentCallerId!,
            avatar: callProvider.currentCallerAvatar,
            isIncoming: isIncoming,
            onCallEnded: (bool ended) {
              if (ended) {
                callProvider.endCall();
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
} 