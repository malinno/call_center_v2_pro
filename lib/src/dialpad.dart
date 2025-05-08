import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'call_history.dart';

class DialPadWidget extends StatefulWidget {
  final SIPUAHelper? helper;
  DialPadWidget(this.helper, {Key? key}) : super(key: key);

  @override
  _DialPadWidgetState createState() => _DialPadWidgetState();
}

class _DialPadWidgetState extends State<DialPadWidget> implements SipUaHelperListener {
  late TextEditingController _textController;
  late SharedPreferences _preferences;

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
    _textController = TextEditingController();
    widget.helper?.addSipUaHelperListener(this);
    _loadDest();
  }

  Future<void> _loadDest() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() => _textController.clear());
  }

  @override
  void dispose() {
    widget.helper?.removeSipUaHelperListener(this);
    _textController.dispose();
    super.dispose();
  }

  void _append(String num) {
    setState(() {
      _textController.text += num;
    });
  }

  void _backspace() {
    final text = _textController.text;
    if (text.isNotEmpty) {
      setState(() {
        _textController.text = text.substring(0, text.length - 1);
      });
    }
  }

  Future<void> _call({required bool video}) async {
    String dest = _textController.text;
    print('Gọi tới: $dest');
    if (dest.isEmpty) return;
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      await Permission.microphone.request();
      await Permission.camera.request();
    }
    widget.helper?.call(dest, voiceOnly: !video);
    _preferences.setString('dest', dest);
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
            SizedBox(height: 40),
            Text(
              _textController.text,
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
                  onTap: () => _call(video: false),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    child: Icon(Icons.call, color: Colors.white, size: 36),
                  ),
                ),
                SizedBox(width: 70,
                  child: _textController.text.isNotEmpty
                    ? Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: _backspace,
                          onLongPress: () => setState(() => _textController.clear()),
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

  @override void registrationStateChanged(RegistrationState state) {}
  @override void transportStateChanged(TransportState state) {}
  @override
  void callStateChanged(Call call, CallState state) async {
    if (state.state == CallStateEnum.CALL_INITIATION) {
      await saveCallHistory(call.remote_identity ?? '');
      await Navigator.pushNamed(context, '/callscreen', arguments: call);
      setState(() => _textController.clear());
    }
    if (state.state == CallStateEnum.FAILED) {
      await saveCallHistory(call.remote_identity ?? '', missed: true);
    }
  }
  @override void onNewMessage(SIPMessageRequest msg) {}
  @override void onNewNotify(Notify ntf) {}
  @override void onNewReinvite(ReInvite event) {}
}
