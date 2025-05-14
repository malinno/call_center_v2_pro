import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'providers/fcm_provider.dart';

class IntroScreen extends StatefulWidget {
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _logger = Logger();

  @override
  void initState() {
    super.initState();
    _logger.d('IntroScreen initState');
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Khởi tạo FCM service
      final fcmProvider = Provider.of<FCMProvider>(context, listen: false);
      await fcmProvider.initialize();
      _logger.d('FCM service initialized');
      
      // Kiểm tra trạng thái đăng nhập và điều hướng
      await _checkLoginAndNavigate();
    } catch (e) {
      _logger.e('Error initializing services: $e');
    }
  }

  Future<void> _checkLoginAndNavigate() async {
    _logger.d('Checking login status');
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _logger.d('isLoggedIn: $isLoggedIn');
    if (isLoggedIn) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      Navigator.of(context).pushReplacementNamed('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('Building IntroScreen');
    return Scaffold(
      backgroundColor: Colors.blue, // Thêm màu nền để dễ nhận biết
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to SOLY',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  _logger.d('Button pressed');
                  Navigator.of(context).pushReplacementNamed('/register');
                },
                child: Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}