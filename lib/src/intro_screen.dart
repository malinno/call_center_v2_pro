import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';

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
    Future.delayed(const Duration(seconds: 2), () {
      _checkLoginAndNavigate();
    });
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
      body: Container(
        color: Colors.white,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              _logger.d('Building animation with scale: $scale');
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Image.asset(
              'lib/src/assets/Soly.png',
              width: 100,
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                _logger.e('Error loading image: $error');
                return const Icon(Icons.error);
              },
            ),
          ),
        ),
      ),
    );
  }
}