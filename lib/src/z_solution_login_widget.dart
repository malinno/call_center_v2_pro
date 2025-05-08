import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/zsolution_user.dart';
import 'services/zsolution_service.dart';
import 'dart:convert';
import 'dart:ui';
import 'register.dart';

class ZSolutionLoginWidget extends StatefulWidget {
  final SIPUAHelper? helper;
  const ZSolutionLoginWidget({Key? key, this.helper}) : super(key: key);

  @override
  State<ZSolutionLoginWidget> createState() => _ZSolutionLoginWidgetState();
}

class _ZSolutionLoginWidgetState extends State<ZSolutionLoginWidget> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập đầy đủ email và mật khẩu')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final user = await ZSolutionService.login(email, password);
      // Lưu thông tin user
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('zsolution_user', jsonEncode(user.toJson()));
      await prefs.setString('zsolution_token', user.token);

      // Cấu hình lại SIPUAHelper
      if (widget.helper != null) {
        final settings = UaSettings();
        settings.webSocketUrl = 'wss://${user.host}:8089/ws';
        settings.uri = 'sip:${user.extension}@${user.host}';
        settings.authorizationUser = user.extension;
        settings.password = user.pass;
        settings.displayName = user.extension;
        settings.userAgent = 'ZSolutionSoftphone';

        print('Cấu hình SIP với:');
        print('webSocketUrl: ${settings.webSocketUrl}');
        print('uri: ${settings.uri}');
        print('authorizationUser: ${settings.authorizationUser}');
        print('password: ${settings.password}');

        try {
          widget.helper!.stop();
        } catch (e) {
          print('Warning: stop() failed, có thể chưa từng start');
        }
        widget.helper!.start(settings);
      }

      // Chuyển về màn hình chính
      Navigator.pushReplacementNamed(context, '/home');
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
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Top illustration with white blur background
          Container(
            height: 420,
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
                          Column(
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('Email', style: TextStyle(color: Colors.white70)),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  prefixIcon: Icon(Icons.email, color: Colors.white54),
                                  hintText: 'Email',
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
                              TextField(
                                controller: _passwordController,
                                obscureText: true,
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
                                    onPressed: _loading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _loading
                                        ? CircularProgressIndicator(color: Colors.white)
                                        : Text(
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
                                        builder: (context) => RegisterWidget(widget.helper),
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
}