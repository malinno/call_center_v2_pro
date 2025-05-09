import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/zsolution_user.dart';
import 'services/zsolution_service.dart';
import 'dart:convert';
import 'dart:ui';
import 'register.dart';

class ZSolutionLoginWidget extends StatefulWidget {
  final SIPUAHelper helper;
  const ZSolutionLoginWidget({Key? key, required this.helper}) : super(key: key);

  @override
  State<ZSolutionLoginWidget> createState() => _ZSolutionLoginWidgetState();
}

class _ZSolutionLoginWidgetState extends State<ZSolutionLoginWidget> implements SipUaHelperListener {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();
  bool _rememberMe = false;
  bool get isStarted => widget.helper!.isConnected();
  bool get isRegistered => widget.helper!.registerState.state == RegistrationStateEnum.REGISTERED;

  @override
  void initState() {
    super.initState();
    _loadSavedAccount();
    widget.helper?.addSipUaHelperListener(this);
  }

  @override
  void dispose() {
    widget.helper.stop();
    widget.helper.removeSipUaHelperListener(this);
    super.dispose();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    print('SIP Registration State Changed: ${state.state}');
    if (state.state == RegistrationStateEnum.REGISTERED) {
     ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đăng ký SIP thành công!')),
    );
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi đăng ký SIP: ${state.cause}')),
    );
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    print('SIP Transport State Changed: ${state.state}');
  }

  @override
  void callStateChanged(Call call, CallState state) {
    print('SIP Call State Changed: ${state.state}');
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}

  Future<void> _loadSavedAccount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('zsolution_email') ?? '';
      _passwordController.text = prefs.getString('zsolution_password') ?? '';
      _rememberMe = prefs.getBool('zsolution_remember_me') ?? false;
    });
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _loading = true);
    try {
      final user = await ZSolutionService.login(email, password);
      // Debug prints to check user data
      print('Login successful - User data:');
      print('Host: ${user.host}');
      print('Extension: ${user.extension}');
      print('Password: ${user.pass}');
      print('Token: ${user.token}');

      // Lưu thông tin user
      final prefs = await SharedPreferences.getInstance();
      final userJson = user.toJson();
      print('Saving user data to SharedPreferences:');
      print('User JSON: $userJson');
      await prefs.setString('zsolution_user', jsonEncode(userJson));
      if (user.token != null) {
        await prefs.setString('zsolution_token', user.token!);
      }
      if (_rememberMe) {
        await prefs.setString('zsolution_email', email);
        await prefs.setString('zsolution_password', password);
        await prefs.setBool('zsolution_remember_me', true);
      } else {
        await prefs.remove('zsolution_email');
        await prefs.remove('zsolution_password');
        await prefs.remove('zsolution_remember_me');
      }

      // Cấu hình lại SIPUAHelper
    if (widget.helper != null) {
    final settings = UaSettings();
    settings.webSocketUrl = 'wss://${user.host}:8089/ws';
    settings.uri = 'sip:${user.extension}@${user.host}';
    settings.authorizationUser = user.extension;
    settings.password = user.pass;
    settings.displayName = user.extension;
    settings.userAgent = 'ZSolutionSoftphone';
    settings.transportType = TransportType.WS;

    print('Cấu hình SIP với:');
    print('webSocketUrl: ${settings.webSocketUrl}');
    print('uri: ${settings.uri}');
    print('authorizationUser: ${settings.authorizationUser}');
    print('password: ${settings.password}');

    try {
      // Dừng kết nối cũ nếu tồn tại
      if (isRegistered) {
        print('Đang hủy đăng ký SIP cũ...');
        await widget.helper!.unregister();
      }
      
      if (isStarted) {
        print('Đang dừng kết nối SIP cũ...');
        widget.helper!.stop();
      }

      print('Khởi tạo kết nối SIP mới...');
      await widget.helper!.start(settings);
      
      // Thêm delay để đảm bảo quá trình đăng ký
      await Future.delayed(Duration(seconds: 1));

    } catch (e) {
      print('Lỗi cấu hình SIP: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi kết nối SIP: ${e.toString()}')),
      );
    }
  }

    //   // Chuyển về màn hình chính
    //   Navigator.pushReplacementNamed(context, '/home');
    Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => MainTabs(helper: widget.helper),
  ),
);
    } catch (e) {
      // Hiển thị lỗi rõ ràng
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng nhập thất bại: ${e.toString()}')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: Stack(
        children: [
          // Header gradient background
          Container(
            height: 280,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF6A5AE0), Color(0xFF6A5AE0), Color(0xFFB16CEA)],
                begin: Alignment.topCenter,
                end: Alignment.center,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterWidget(widget.helper),
                          ),
                        );
                      },
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'ZSolution',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            fontFamily: 'Poppins',
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.5),
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Login Card
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                child: Transform.translate(
                  offset: const Offset(0, 50),
                  child: SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 650),
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Column(
                                    children: const [
                                      Text(
                                        'Đăng nhập ZSolution',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2B133D),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Nhập thông tin của bạn dưới đây',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                TextFormField(
                                  controller: _emailController,
                                  validator: (value) => value == null || value.isEmpty ? 'Email là bắt buộc' : null,
                                  decoration: InputDecoration(
                                    labelText: 'Nhập email của bạn',
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF6F7FB),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  validator: (value) => value == null || value.isEmpty ? 'Mật khẩu là bắt buộc' : null,
                                  decoration: InputDecoration(
                                    labelText: 'Nhập mật khẩu của bạn',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF6F7FB),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() {
                                            _rememberMe = value ?? false;
                                          });
                                        },
                                      ),
                                      const Text('Lưu tài khoản'),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Ink(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF6A5AE0), Color(0xFFB16CEA)],
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                        ),
                                        borderRadius: BorderRadius.all(Radius.circular(16)),
                                      ),
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: _loading
                                            ? CircularProgressIndicator(color: Colors.white)
                                            : const Text(
                                                'Đăng Nhập',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}