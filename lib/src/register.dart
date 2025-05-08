import 'package:dart_sip_ua_example/src/user_state/sip_user.dart';
import 'package:dart_sip_ua_example/src/user_state/sip_user_cubit.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:another_flushbar/flushbar.dart';
import 'services/zsolution_service.dart';
import 'models/zsolution_user.dart';
import 'dart:convert';
import 'z_solution_login_widget.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

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
  final TextEditingController _zsolutionEmailController = TextEditingController();
  final TextEditingController _zsolutionPasswordController = TextEditingController();
  bool _showZSolutionForm = false;

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
    _zsolutionEmailController.dispose();
    _zsolutionPasswordController.dispose();
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Top illustration with white blur background
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              // Không gradient, chỉ nền trắng mờ
            ),
            child: Image.asset(
              'lib/src/assets/logo.png',
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
            ),
          ),
          // Form card with gradient background
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                margin: const EdgeInsets.only(top: 140),
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2B133D), Color(0xFF1C0528)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(40),
                          topRight: Radius.circular(40),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Xin chào!',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chào bạn đến với soly',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Server', style: TextStyle(color: Colors.white70)),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _serverController,
                                  validator: (value) => value == null || value.isEmpty ? 'Server không được để trống' : null,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.cloud, color: Colors.white54),
                                    hintText: 'Server',
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    hintStyle: TextStyle(color: Colors.white38),
                                  ),
                                  style: TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Username', style: TextStyle(color: Colors.white70)),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _usernameController,
                                  validator: (value) => value == null || value.isEmpty ? 'Username không được để trống' : null,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.person, color: Colors.white54),
                                    hintText: 'Username',
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    hintStyle: TextStyle(color: Colors.white38),
                                  ),
                                  style: TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 20),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Password', style: TextStyle(color: Colors.white70)),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  validator: (value) => value == null || value.isEmpty ? 'Password không được để trống' : null,
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(Icons.vpn_key, color: Colors.white54),
                                    hintText: 'Password',
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.08),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      borderSide: BorderSide.none,
                                    ),
                                    hintStyle: TextStyle(color: Colors.white38),
                                  ),
                                  style: TextStyle(color: Colors.white),
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFFB621FE), Color(0xFF1FD1F9)],
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (_formKey.currentState!.validate()) {
                                          _register();
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        'Đăng nhập',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.white24)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text('Đăng nhập với', style: TextStyle(color: Colors.white54)),
                                    ),
                                    Expanded(child: Divider(color: Colors.white24)),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ZSolutionLoginWidget(
                                            helper: widget._helper,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.2),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Image.asset('lib/src/assets/Soly.png'),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
