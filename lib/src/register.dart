import 'package:dart_sip_ua_example/src/user_state/sip_user.dart';
import 'package:dart_sip_ua_example/src/user_state/sip_user_cubit.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:another_flushbar/flushbar.dart';

class RegisterWidget extends StatefulWidget {
  final SIPUAHelper? _helper;

  RegisterWidget(this._helper, {Key? key}) : super(key: key);

  @override
  State<RegisterWidget> createState() => _RegisterWidgetState();
}

class _RegisterWidgetState extends State<RegisterWidget>
    implements SipUaHelperListener {
  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late SharedPreferences _preferences;
  late RegistrationState _registerState;

  // Luôn dùng WebSocket
  final TransportType _transport = TransportType.WS;
  final Map<String, String> _wsExtraHeaders = {
    'X-WebSocket-Protocol': 'sip',
    'X-WebSocket-Extensions': 'permessage-deflate',
    'X-WebSocket-Version': '13',
    'X-WebSocket-Allow-Self-Signed': 'true'
  };

  late SipUserCubit currentUser;
  SIPUAHelper? get helper => widget._helper;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _registerState = helper!.registerState;
    helper!.addSipUaHelperListener(this);
    _loadSettings();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    helper!.removeSipUaHelperListener(this);
    _saveSettings();
    super.deactivate();
  }

  Future<void> _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _serverController.text = _preferences.getString('ws_uri') ?? '';
      _usernameController.text = _preferences.getString('auth_user') ?? '';
      _passwordController.text = _preferences.getString('password') ?? '';
    });
  }

  void _saveSettings() {
    _preferences.setString('ws_uri', _serverController.text);
    _preferences.setString('auth_user', _usernameController.text);
    _preferences.setString('password', _passwordController.text);
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    if (mounted) setState(() => _registerState = state);
    Navigator.of(context, rootNavigator: true).pop();
    if (state.state == RegistrationStateEnum.REGISTERED) {
      _preferences.setBool('is_logged_in', true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Đăng ký thành công')));
      Navigator.pushReplacementNamed(context, '/home');
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      Fluttertoast.showToast(
        msg: "Đăng ký thất bại. Vui lòng kiểm tra lại",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  void _showAlert(String field) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('$field không được để trống'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Ok'),
          )
        ],
      ),
    );
  }

  void _register() {
    final server = _serverController.text.trim();
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;
    if (server.isEmpty) return _showAlert('Server');
    if (user.isEmpty) return _showAlert('Username');
    if (pass.isEmpty) return _showAlert('Password');

    const port = '8089';
    final wsUrl = 'wss://$server:$port/ws';
    final sipUri = '$user@$server';

    _saveSettings();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Đang đăng nhập...'),
          ],
        ),
      ),
    );

    currentUser.register(SipUser(
      selectedTransport: _transport,
      wsUrl: wsUrl,
      wsExtraHeaders: _wsExtraHeaders,
      sipUri: sipUri,
      port: port,
      displayName: user,
      authUser: user,
      password: pass,
    ));
  }

  @override
  Widget build(BuildContext context) {
    currentUser = context.watch<SipUserCubit>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9D50BB), Color(0xFF6E48AA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 40),
                    Icon(Icons.check_circle, size: 80, color: Colors.white),
                    SizedBox(height: 16),
                    Text('SOLY',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2)),
                    SizedBox(height: 40),
                    TextFormField(
                      controller: _serverController,
                      validator: (value) => value == null || value.isEmpty ? 'Server không được để trống' : null,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.cloud, color: Colors.white70),
                        hintText: 'Server',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      validator: (value) => value == null || value.isEmpty ? 'Username không được để trống' : null,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person, color: Colors.white70),
                        hintText: 'Username',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      validator: (value) => value == null || value.isEmpty ? 'Password không được để trống' : null,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock, color: Colors.white70),
                        hintText: 'Password',
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        hintStyle: TextStyle(color: Colors.white70),
                      ),
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _register();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Text('Đăng Nhập',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void callStateChanged(Call call, CallState state) {}
  @override
  void transportStateChanged(TransportState state) {}
  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
