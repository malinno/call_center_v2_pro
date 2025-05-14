import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/zsolution_user.dart';
import 'services/zsolution_service.dart';
import 'dart:convert';
import 'dart:ui';
import 'register.dart';
import 'main_tabs.dart';
import 'utils/notification_helper.dart';

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
  bool get isStarted => widget.helper.registerState.state == RegistrationStateEnum.REGISTERED;
  bool get isRegistered => widget.helper.registerState.state == RegistrationStateEnum.REGISTERED;

  @override
  void initState() {
    super.initState();
    _loadSavedAccount();
    widget.helper.addSipUaHelperListener(this);
  }

  @override
  void dispose() {
    widget.helper.removeSipUaHelperListener(this);
    super.dispose();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    print('ZSolution - Registration State Changed: ${state.state}');
    if (!mounted) return;

    if (state.state == RegistrationStateEnum.REGISTERED) {
      print('ZSolution - Đăng ký SIP thành công!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đăng ký SIP thành công!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Chuyển sang màn hình chính
      print('ZSolution - Đang chuyển sang màn hình chính...');
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainTabs(widget.helper),
            ),
          );
        }
      });
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      print('ZSolution - Đăng ký SIP thất bại: ${state.cause}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi đăng ký SIP: ${state.cause}'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (state.state == RegistrationStateEnum.UNREGISTERED) {
      print('ZSolution - Đăng ký SIP bị hủy');
      // Không hiển thị thông báo khi unregister để tránh gây nhầm lẫn
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    print('ZSolution - Transport State Changed: ${state.state}');
    if (state.state == TransportStateEnum.CONNECTED) {
      print('ZSolution - Transport connected, attempting to register...');
      // Đợi một chút để đảm bảo kết nối ổn định
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          try {
            if (widget.helper.registerState.state != RegistrationStateEnum.REGISTERED) {
              widget.helper.register();
            }
          } catch (e) {
            print('ZSolution - Registration failed: $e');
          }
        }
      });
    } else if (state.state == TransportStateEnum.DISCONNECTED) {
      print('ZSolution - Transport disconnected, attempting to reconnect...');
      // Thử kết nối lại sau 1 giây
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          try {
            print('ZSolution - Connection lost, waiting for transport to reconnect...');
          } catch (e) {
            print('ZSolution - Reconnection failed: $e');
          }
        }
      });
    }
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

    try { 
      final user = await ZSolutionService.login(email, password);
      // Lưu thông tin user
      final prefs = await SharedPreferences.getInstance();
      final userJson = user.toJson();
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
        settings.register = true;
        settings.register_expires = 300;
        try {
          // Dừng kết nối cũ nếu tồn tại
          if (widget.helper.registerState.state == RegistrationStateEnum.REGISTERED) {
            
            widget.helper.unregister();
          }
          
          if (widget.helper.registerState.state != RegistrationStateEnum.NONE) {
            
            widget.helper.stop();
          }

          // Đợi một chút để đảm bảo kết nối cũ đã dừng
          await Future.delayed(Duration(seconds: 1));

         
          await widget.helper.start(settings);
          
          // Đóng dialog loading
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          
          // Hiển thị thông báo thành công
          NotificationHelper.showSuccess(context, 'Đăng nhập thành công');

        } catch (e) {
         
          if (Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          NotificationHelper.showError(context, 'Lỗi kết nối SIP: ${e.toString()}');
        }
      }
    } catch (e) {
     
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      NotificationHelper.showError(context, 'Đăng nhập thất bại: ${e.toString()}');
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
              color: Colors.white,
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Image.asset(
                            'lib/src/assets/images/soly.png',
                            height: 100,
                            fit: BoxFit.contain,
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
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: _loading ? null : _login,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFf8d605),
                                          borderRadius: BorderRadius.all(Radius.circular(16)),
                                        ),
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
                                const SizedBox(height: 18),
                                Row(
                                  children: const [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text('Hoặc đăng nhập với', style: TextStyle(color: Colors.black45)),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => RegisterWidget(widget.helper),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Đăng nhập với Server',
                                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
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