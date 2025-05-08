import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/zsolution_user.dart';

class AccountWidget extends StatefulWidget {
  const AccountWidget({Key? key}) : super(key: key);

  @override
  State<AccountWidget> createState() => _AccountWidgetState();
}

class _AccountWidgetState extends State<AccountWidget> {
  String? _username;
  String? _server;
  ZSolutionUser? _zsolutionUser;
  bool _isZSolutionLogin = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _loadAccount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load ZSolution user data if exists
      final zsolutionUserJson = prefs.getString('zsolution_user');
      if (zsolutionUserJson != null && zsolutionUserJson.isNotEmpty) {
        try {
          final Map<String, dynamic> jsonData = jsonDecode(zsolutionUserJson);
          _zsolutionUser = ZSolutionUser.fromJson(jsonData);
          _isZSolutionLogin = true;
        } catch (e) {
          _isZSolutionLogin = false;
        }
      } else {
        _username = prefs.getString('auth_user') ?? '';
        _server = prefs.getString('ws_uri') ?? '';
        _isZSolutionLogin = false;
      }
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('auth_user');
    await prefs.remove('ws_uri');
    await prefs.remove('password');
    await prefs.remove('zsolution_token');
    await prefs.remove('zsolution_user');
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/register', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_circle, color: Colors.white, size: 80),
              SizedBox(height: 24),
              Text(
                'Tài khoản',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 24),
              if (_isZSolutionLogin && _zsolutionUser != null) ...[
                Text('Username: ${_zsolutionUser!.userName}', 
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
                SizedBox(height: 8),
                Text('Role: ${_zsolutionUser!.roleName}', 
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
              ] else ...[
                Text('Username: $_username', 
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
                SizedBox(height: 8),
                Text('Server: $_server', 
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
              ],
              SizedBox(height: 32),
              ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text('Đăng xuất', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}