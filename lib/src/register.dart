import 'package:call_center_pro/src/user_state/sip_user.dart';
import 'package:call_center_pro/src/user_state/sip_user_cubit.dart';
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
import 'utils/notification_helper.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class RegisterWidget extends StatefulWidget {
  final SIPUAHelper helper;

  const RegisterWidget(this.helper, {Key? key}) : super(key: key);

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
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late SharedPreferences _preferences;
  late RegistrationState _registerState;
  late UaSettings _sipSettings;

  // Luôn dùng WebSocket
  final TransportType _transport = TransportType.WS;
  final Map<String, String> _wsExtraHeaders = {
    'X-WebSocket-Protocol': 'sip',
    'X-WebSocket-Extensions': 'permessage-deflate',
    'X-WebSocket-Version': '13',
    'X-WebSocket-Allow-Self-Signed': 'true'
  };

  late SipUserCubit currentUser;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _registerState = widget.helper.registerState;
    widget.helper.addSipUaHelperListener(this);
    _loadSettings();
  }

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _zsolutionEmailController.dispose();
    _zsolutionPasswordController.dispose();
    widget.helper.removeSipUaHelperListener(this);
    super.dispose();
  }

  @override
  void deactivate() {
    widget.helper.removeSipUaHelperListener(this);
    _saveSettings();
    super.deactivate();
  }

  Future<void> _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _serverController.text = _preferences.getString('ws_uri') ?? '';
      _usernameController.text = _preferences.getString('auth_user') ?? '';
      _passwordController.text = _preferences.getString('password') ?? '';
      _rememberMe = _preferences.getBool('remember_me') ?? false;
    });
  }

  void _saveSettings() {
    _preferences.setString('ws_uri', _serverController.text);
    _preferences.setString('auth_user', _usernameController.text);
    _preferences.setString('password', _passwordController.text);
    _preferences.setBool('remember_me', _rememberMe);
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    print('Registration State Changed: ${state.state}');
    if (!mounted) return;

    setState(() => _registerState = state);
    
    if (state.state == RegistrationStateEnum.REGISTERED) {
      if (_rememberMe) {
        _saveSettings();
      } else {
        _preferences.remove('ws_uri');
        _preferences.remove('auth_user');
        _preferences.remove('password');
        _preferences.remove('remember_me');
      }
      _preferences.setBool('is_logged_in', true);
      
      // Đóng dialog loading nếu đang mở
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Hiển thị thông báo thành công
      NotificationHelper.showSuccess(context, 'Đăng nhập thành công');
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/home',
            arguments: widget.helper,
          );
        }
      });
    } else if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      // Đóng dialog loading nếu đang mở
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      NotificationHelper.showError(context, 'Đăng nhập thất bại: ${state.cause}');
    } else if (state.state == RegistrationStateEnum.UNREGISTERED) {
      // Đóng dialog loading nếu đang mở
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      NotificationHelper.showWarning(context, 'Đăng nhập bị hủy');
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

  @override
  void transportStateChanged(TransportState state) {
   
    if (state.state == TransportStateEnum.CONNECTED) {
    
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          try {
            if (_sipSettings != null) {
              widget.helper.register();
            }
          } catch (e) {
            print('Error during SIP registration: $e');
            if (mounted) {
              NotificationHelper.showError(context, 'Lỗi đăng ký SIP');
            }
          }
        }
      });
    } else if (state.state == TransportStateEnum.DISCONNECTED) {
      Future.delayed(Duration(seconds: 1), () {
        if (mounted) {
          try {
            if (_sipSettings != null) {
              widget.helper.start(_sipSettings);
            }
          } catch (e) {
            if (mounted) {
              NotificationHelper.showError(context, 'Lỗi khởi động SIP');
            }
          }
        }
      });
    }
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
            LoadingAnimationWidget.inkDrop(
              color: Color(0xFF223A5E),
              size: 38,
            ),
            SizedBox(width: 20),
            Text('Đang đăng nhập...'),
          ],
        ),
      ),
    );

    try {
      // Dừng kết nối cũ nếu tồn tại
      if (widget.helper.registerState.state == RegistrationStateEnum.REGISTERED) {
       
        widget.helper.unregister();
      }
      
      // Kiểm tra trạng thái kết nối thông qua registerState
      if (widget.helper.registerState.state != RegistrationStateEnum.NONE) {
     
        widget.helper.stop();
      }

      // Đợi một chút để đảm bảo kết nối cũ đã dừng
      Future.delayed(Duration(seconds: 1)).then((_) {
      
        _sipSettings = UaSettings();
        _sipSettings.webSocketUrl = wsUrl;
        _sipSettings.uri = 'sip:$sipUri';
        _sipSettings.authorizationUser = user;
        _sipSettings.password = pass;
        _sipSettings.displayName = user;
        _sipSettings.userAgent = 'ZSolutionSoftphone';
        _sipSettings.transportType = _transport;
        _sipSettings.register = true; 
        _sipSettings.register_expires = 300; 
        try {
          widget.helper.start(_sipSettings).then((_) {
           
          }).catchError((e) {
            if (mounted) {
              Navigator.of(context).pop(); // Đóng dialog loading
              NotificationHelper.showError(context, 'Lỗi kết nối');
            }
          });
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop(); // Đóng dialog loading
            NotificationHelper.showError(context, 'Lỗi kết nối');
          }
        }
      });
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Đóng dialog loading
        NotificationHelper.showError(context, 'Lỗi đăng đăng nhập');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    currentUser = context.watch<SipUserCubit>();
    return Scaffold(
      backgroundColor: Colors.white,
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
              child: Center(
                child: Container(
                  // padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset(
                    'lib/src/assets/images/soly.png',
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          // Login Card
          Align(
            alignment: Alignment.bottomCenter,
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: const [
                                Text(
                                  'Chào mừng bạn đến với ZSolution',
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
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _serverController,
                                  validator: (value) => value == null || value.isEmpty ? 'Server là bắt buộc' : null,
                                  decoration: InputDecoration(
                                    labelText: 'Nhập server',
                                    prefixIcon: const Icon(Icons.cloud_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF6F7FB),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _usernameController,
                                  validator: (value) => value == null || value.isEmpty ? 'Tên tài khoản là bắt buộc' : null,
                                  decoration: InputDecoration(
                                    labelText: 'Nhập tên tài khoản',
                                    prefixIcon: const Icon(Icons.person_outline),
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
                                  obscureText: _obscurePassword,
                                  validator: (value) => value == null || value.isEmpty ? 'Mật khẩu là bắt buộc ' : null,
                                  decoration: InputDecoration(
                                    labelText: 'Nhập mật khẩu của bạn',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
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
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        if (_formKey.currentState!.validate()) {
                                          _register();
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFf8d605),
                                          borderRadius: BorderRadius.all(Radius.circular(16)),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text(
                                          'Đăng Nhập',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            inherit: false,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                               
                                const SizedBox(height: 8),
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
                                      final zSolutionHelper = Provider.of<SIPUAHelper>(
                                      context,
                                      listen: false,
                                    );
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ZSolutionLoginWidget(
                                            helper: zSolutionHelper,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text(
                                      'Đăng nhập với ZSolution',
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
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
