import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'call_history.dart';

class DialPadWidget extends StatefulWidget {
  final SIPUAHelper helper;
  const DialPadWidget({Key? key, required this.helper}) : super(key: key);
  @override
  _DialPadWidgetState createState() => _DialPadWidgetState();
}

class _DialPadWidgetState extends State<DialPadWidget> implements SipUaHelperListener {
  final TextEditingController _numberController = TextEditingController();
  bool _isRegistered = false;
  bool _isRegistering = false;

  // Key definitions
  final List<List<Map<String, String>>> _keys = const [
    [ {'1': ''}, {'2': 'ABC'}, {'3': 'DEF'} ],
    [ {'4': 'GHI'}, {'5': 'JKL'}, {'6': 'MNO'} ],
    [ {'7': 'PQRS'}, {'8': 'TUV'}, {'9': 'WXYZ'} ],
    [ {'*': ''}, {'0': '+'}, {'#': ''} ],
  ];

  @override
  void initState() {
    super.initState();
    widget.helper.addSipUaHelperListener(this);
    _isRegistered = widget.helper.registerState.state == RegistrationStateEnum.REGISTERED;
    print('DialPad initState - Current registration state: ${widget.helper.registerState.state}');
  }

  @override
  void dispose() {
    _numberController.dispose();
    widget.helper.removeSipUaHelperListener(this);
    super.dispose();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    print('DialPad - Registration State Changed: ${state.state}');
    setState(() {
      _isRegistered = state.state == RegistrationStateEnum.REGISTERED;
      _isRegistering = false;
    });
  }

  @override
  void transportStateChanged(TransportState state) {
    print('DialPad - Transport State Changed: ${state.state}');
  }

  @override
  void callStateChanged(Call call, CallState state) async {
    if (state.state == CallStateEnum.CALL_INITIATION) {
      await saveCallHistory(call.remote_identity ?? '');
      if (mounted) {
        await Navigator.pushNamed(
          context,
          '/callscreen',
          arguments: call,
        );
        setState(() => _numberController.clear());
      }
    }
    if (state.state == CallStateEnum.FAILED) {
      await saveCallHistory(call.remote_identity ?? '', missed: true);
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _call() async {
    final number = _numberController.text;
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập số điện thoại')),
      );
      return;
    }

    // Xin quyền microphone
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cần cấp quyền truy cập microphone để thực hiện cuộc gọi')),
      );
      return;
    }

    // Kiểm tra trạng thái đăng ký SIP
    if (widget.helper.registerState.state != RegistrationStateEnum.REGISTERED) {
      try {
        // Đăng ký SIP
        widget.helper.register();
        // Đợi đăng ký thành công
        await Future.delayed(Duration(seconds: 2));
        if (widget.helper.registerState.state != RegistrationStateEnum.REGISTERED) {
          throw Exception('Không thể đăng ký SIP');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể kết nối SIP. Vui lòng thử lại.')),
        );
        return;
      }
    }

    try {
      final call = await widget.helper.call(
        number,
        voiceOnly: true,
        headers: [
          'X-Feature-Level: 1',
          'X-Feature-Code: basic',
        ],
      );
      if (mounted) {
        await Navigator.pushNamed(
          context, 
          '/callscreen',
          arguments: call,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể thực hiện cuộc gọi: ${e.toString()}')),
        );
      }
    }
  }

  void _append(String digit) {
    setState(() {
      _numberController.text += digit;
    });
  }

  void _backspace() {
    final text = _numberController.text;
    if (text.isNotEmpty) {
      setState(() {
        _numberController.text = text.substring(0, text.length - 1);
      });
    }
  }

  Widget _buildButton(Map<String, String> keyData) {
    final num = keyData.keys.first;
    final letters = keyData.values.first;
    return GestureDetector(
      onTap: () => _append(num),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(num, style: TextStyle(color: Colors.white, fontSize: 32)),
            if (letters.isNotEmpty)
              Text(letters, style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildKeypad() {
    return _keys.map((row) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map(_buildButton).toList(),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(height: 10),
            Text(
              'SIP: ${widget.helper.registerState.state.toString()}',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            SizedBox(height: 40),
            Text(
              _numberController.text,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 36, letterSpacing: 2),
            ),
            SizedBox(height: 20),
            ..._buildKeypad(),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 70),
                GestureDetector(
                  onTap: _call,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: Icon(Icons.call, color: Colors.white, size: 36),
                  ),
                ),
                SizedBox(width: 70,
                  child: _numberController.text.isNotEmpty
                    ? Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _backspace,
                          onLongPress: () => setState(() => _numberController.clear()),
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.backspace_outlined,
                              color: Colors.white70,
                              size: 26,
                            ),
                          ),
                        ),
                      )
                    : null,
                ),
              ],
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
