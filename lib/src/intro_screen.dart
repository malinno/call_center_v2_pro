import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'providers/fcm_provider.dart';
import 'package:sip_ua/sip_ua.dart';
class IntroScreen extends StatefulWidget {
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with SingleTickerProviderStateMixin {
  final _logger = Logger();
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1200),
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _rotateAnim = Tween<double>(begin: -0.06, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
    _initializeServices();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      final fcmProvider = Provider.of<FCMProvider>(context, listen: false);
      await fcmProvider.initialize();
      await _checkLoginAndNavigate();
    } catch (e) {
    }
  }

  Future<void> _checkLoginAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    await Future.delayed(Duration(milliseconds: 1200)); 
    // if (isLoggedIn) {
    //   Navigator.of(context).pushReplacementNamed('/home');
    // } else {
    //   Navigator.of(context).pushReplacementNamed('/register');
    // }
    if (isLoggedIn) {
    // Đọc lại cấu hình SIP
    final server = prefs.getString('ws_uri');
    final user = prefs.getString('auth_user');
    final pass = prefs.getString('password');
    if (server != null && user != null && pass != null) {
      final helper = Provider.of<SIPUAHelper>(context, listen: false);
      final settings = UaSettings();
      settings.webSocketUrl = 'wss://$server:8089/ws';
      settings.uri = 'sip:$user@$server';
      settings.authorizationUser = user;
      settings.password = pass;
      settings.displayName = user;
      settings.userAgent = 'ZSolutionSoftphone';
      settings.transportType = TransportType.WS;
      settings.register = true;
      settings.register_expires = 300;
      helper.start(settings);
    }
    Navigator.of(context).pushReplacementNamed('/home');
  } else {
    Navigator.of(context).pushReplacementNamed('/register');
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: RotationTransition(
                turns: _rotateAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Image.asset(
                      'lib/src/assets/images/soly.png',
                      fit: BoxFit.contain,
                      
                    ),
                    
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}