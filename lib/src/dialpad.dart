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

    if (state.state == RegistrationStateEnum.UNREGISTERED || 
        state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      print('DialPad - Not registered, waiting for transport to reconnect...');
      _isRegistering = true;
      // Không thử đăng ký lại ngay lập tức, đợi transport kết nối lại
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    print('DialPad - Transport State Changed: ${state.state}');
    if (state.state == TransportStateEnum.CONNECTED && !_isRegistered && !_isRegistering) {
      print('DialPad - Transport connected, attempting to register...');
      _isRegistering = true;
      // Đợi một chút để đảm bảo kết nối ổn định
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          try {
            widget.helper.register();
          } catch (e) {
            print('DialPad - Registration failed: $e');
            _isRegistering = false;
          }
        }
      });
    } else if (state.state == TransportStateEnum.DISCONNECTED) {
      print('DialPad - Transport disconnected, attempting to reconnect...');
      // Thử kết nối lại sau 1 giây
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          try {
            // Không thử đăng ký lại khi đã ngắt kết nối
            print('DialPad - Connection lost, waiting for transport to reconnect...');
          } catch (e) {
            print('DialPad - Reconnection failed: $e');
          }
        }
      });
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

    if (!_isRegistered) {
      print('DialPad - Not registered, attempting to register before call...');
      _isRegistering = true;
      try {
        widget.helper.register();
        // Đợi đăng ký thành công
        await Future.delayed(Duration(seconds: 2));
        if (!_isRegistered) {
          throw Exception('Không thể đăng ký SIP');
        }
      } catch (e) {
        print('DialPad - Registration failed: $e');
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
      Navigator.pushNamed(context, '/callscreen', arguments: call);
    } catch (e) {
      print('DialPad - Call failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể thực hiện cuộc gọi. Vui lòng thử lại.')),
      );
    }
  }

  void _append(String digit) {
    if (!_isRegistered && !_isRegistering) {
      print('DialPad - Not registered, attempting to register before append...');
      _isRegistering = true;
      // Đợi một chút trước khi thử đăng ký lại
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          widget.helper.register();
        }
      });
    }
    _numberController.text += digit;
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
  void callStateChanged(Call call, CallState state) async {
    if (state.state == CallStateEnum.CALL_INITIATION) {
      await saveCallHistory(call.remote_identity ?? '');
      await Navigator.pushNamed(context, '/callscreen', arguments: call);
      setState(() => _numberController.clear());
    }
    if (state.state == CallStateEnum.FAILED) {
      await saveCallHistory(call.remote_identity ?? '', missed: true);
    }
  }
  @override void onNewMessage(SIPMessageRequest msg) {}
  @override void onNewNotify(Notify ntf) {}
  @override void onNewReinvite(ReInvite event) {}
}
