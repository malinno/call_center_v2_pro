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
      print('Error calling: $e');
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

  @override
  Widget build(BuildContext context) {
    final Color mainBlue = Color(0xFF223A5E);
    final Color lightBlue = Color(0xFF1DA1F2);
    final Color keyTextColor = Color(0xFF223A5E);
    final Color keyBgColor = Colors.white;
    final Color dialBg = Color(0xFFF7F9FB);
    final Color borderColor = Color(0xFFE6EAF0);
    final String selectedNumber = '0996484060'; // demo, bạn có thể lấy từ state
    return Scaffold(
      backgroundColor: dialBg,
      body: Column(
        children: [
          // Header
          Container(
            color: mainBlue,
            padding: const EdgeInsets.only(top: 0, left: 0, right: 0, bottom: 0),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đầu số đang chọn', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(selectedNumber, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              SizedBox(width: 8),
                              Image.asset(
                                'lib/src/assets/images/soly.png',
                                height: 22,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => Icon(Icons.image, color: Colors.white, size: 22),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'zsolution',
                                style: TextStyle(
                                  color: Color(0xFF1DA1F2),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Phần giữa: minh họa + text
          Expanded(
            child: Container(
              color: dialBg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 24),
                  Icon(Icons.sync, size: 80, color: lightBlue.withOpacity(0.2)), // Thay bằng hình minh họa nếu có
                  SizedBox(height: 16),
                  Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          ),
          // Bàn phím số
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 8, left: 0, right: 0, bottom: 0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _numberController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(fontSize: 22, color: keyTextColor, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Nhập số điện thoại',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
                            border: InputBorder.none,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: lightBlue,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.person_add, color: Colors.white),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                // Keypad
                for (int i = 0; i < _keys.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final keyData in _keys[i])
                          GestureDetector(
                            onTap: () => _append(keyData.keys.first),
                            child: Container(
                              width: 70,
                              height: 70,
                              margin: EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: keyBgColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: borderColor, width: 1.2),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(keyData.keys.first, style: TextStyle(color: keyTextColor, fontSize: 28, fontWeight: FontWeight.bold)),
                                  if (keyData.values.first.isNotEmpty)
                                    Text(keyData.values.first, style: TextStyle(color: Colors.grey, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Nút cài đặt
                    IconButton(
                      icon: Icon(Icons.settings, color: keyTextColor, size: 28),
                      onPressed: () {},
                    ),
                    // Nút gọi
                    GestureDetector(
                      onTap: _call,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: lightBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: lightBlue.withOpacity(0.18),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.call, color: Colors.white, size: 32),
                      ),
                    ),
                    // Nút xóa
                    IconButton(
                      icon: Icon(Icons.backspace_outlined, color: keyTextColor, size: 28),
                      onPressed: _backspace,
                      onLongPress: () => setState(() => _numberController.clear()),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ],
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
