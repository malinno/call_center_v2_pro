import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/zsolution_user.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';

class AccountWidget extends StatefulWidget {
  final SIPUAHelper? helper;
  const AccountWidget({Key? key, this.helper}) : super(key: key);

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
      final zsolutionUserJson = prefs.getString('zsolution_user');
      print('Loading zsolution_user from SharedPreferences:');
      print('Raw JSON: $zsolutionUserJson');
      if (zsolutionUserJson != null && zsolutionUserJson.isNotEmpty) {
        try {
          final Map<String, dynamic> jsonData = jsonDecode(zsolutionUserJson);
          print('Parsed JSON data: $jsonData');
          _zsolutionUser = ZSolutionUser.fromJson(jsonData);
          print('Parsed user data:');
          print('Host: ${_zsolutionUser?.host}');
          print('Extension: ${_zsolutionUser?.extension}');
          print('Password: ${_zsolutionUser?.pass}');
          _isZSolutionLogin = true;
        } catch (e) {
          print('Error parsing zsolution_user: $e');
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
    await prefs.remove('zsolution_token');
    await prefs.remove('zsolution_user');
    try {
        if (widget.helper != null) {
          if (widget.helper!.registerState.state == RegistrationStateEnum.REGISTERED) {
            widget.helper!.unregister();
          }
          widget.helper!.stop();
        }
      } catch (e) {
        print('Error during logout: $e');
      }

   Navigator.pushReplacementNamed(context, '/intro');
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
                SizedBox(height: 8),
                Text('Host: ${_zsolutionUser!.host ?? ""}',
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
                SizedBox(height: 8),
                Text('Extension: ${_zsolutionUser!.extension ?? ""}',
                    style: TextStyle(color: Colors.white70, fontSize: 18)),
                SizedBox(height: 8),
                Text('Password: ${_zsolutionUser!.pass ?? ""}',
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