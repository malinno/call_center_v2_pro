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
    try {
      // Hiển thị loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      // Xóa dữ liệu đăng nhập nhưng giữ lại thông tin form
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_logged_in');
      await prefs.remove('zsolution_token');
      await prefs.remove('zsolution_user');
      await prefs.remove('zsolution_email');
      await prefs.remove('zsolution_password');
      await prefs.remove('zsolution_remember_me');

      // Hủy đăng ký SIP nếu đang đăng ký
      if (widget.helper != null) {
        try {
          if (widget.helper!.registerState.state == RegistrationStateEnum.REGISTERED) {
            widget.helper!.unregister();
          }
          widget.helper!.stop();
        } catch (e) {
          print('Error stopping SIP: $e');
        }
      }

      // Đóng dialog loading
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Chuyển về màn hình intro
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/intro',
          (route) => false, // Xóa tất cả các route trước đó
        );
      }
    } catch (e) {
      print('Error during logout: $e');
      // Đóng dialog loading nếu có
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      // Hiển thị thông báo lỗi
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đăng xuất: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _isZSolutionLogin && _zsolutionUser != null ? _zsolutionUser!.userName : _username ?? '';
    final email = _isZSolutionLogin && _zsolutionUser != null ? _zsolutionUser!.email : '';
    final isOnline = true; // Tùy trạng thái thực tế, demo luôn online
    return Scaffold(
      backgroundColor: Color(0xFFF7F9FB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'Tài khoản',
                        style: TextStyle(
                          color: Color(0xFF222B45),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Card thông tin tài khoản
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFFE3F0FA),
                          child: Icon(Icons.person, color: Color(0xFF6B7A8F), size: 36),
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName ?? '',
                                style: TextStyle(
                                  color: Color(0xFF222B45),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              if ((email ?? '').isNotEmpty)
                                Text(
                                  email ?? '',
                                  style: TextStyle(
                                    color: Color(0xFF6B7A8F),
                                    fontSize: 15,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFF4BC17B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Trực tuyến', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Color(0xFFF2F3F7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Ngắt kết nối tổng đài', style: TextStyle(color: Color(0xFF6B7A8F), fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            // Danh sách chức năng
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                children: [
                  _buildMenuItem(Icons.person, 'Thông tin cá nhân', 'Thông tin cá nhân'),
                  _buildMenuItem(Icons.support_agent, 'Tổng đài', 'Kết nối tổng đài', iconColor: Color(0xFF4BC17B), statusColor: Color(0xFF4BC17B)),
                  _buildMenuItem(Icons.lock, 'Đổi mật khẩu', 'Cập nhật lại mật khẩu hiện tại', iconColor: Color(0xFFB0B8C1)),
                  _buildMenuItem(Icons.settings, 'Cấu hình', 'Cấu hình thông báo', iconColor: Color(0xFF6B7A8F)),
                  _buildMenuItem(Icons.phone_android, 'Quyền thiết bị', 'Vui lòng cung cấp đủ các quyền cần thiết', iconColor: Color(0xFF6B7A8F)),
                  _buildMenuItem(Icons.support, 'Yêu cầu hỗ trợ', 'Tạo phiếu yêu cầu hỗ trợ qua Biểu mẫu', iconColor: Color(0xFF6B7A8F)),
                  _buildMenuItem(Icons.privacy_tip, 'Chính sách bảo mật', '', iconColor: Color(0xFF6B7A8F)),
                  SizedBox(height: 16),
                  // Nút đăng xuất
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _logout,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout, color: Color(0xFFF15B5B), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Đăng xuất',
                                  style: TextStyle(
                                    color: Color(0xFFF15B5B),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Phiên bản 1.0.1',
                      style: TextStyle(color: Color(0xFFB0B8C1), fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, {Color iconColor = const Color(0xFF6B7A8F), Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Color(0xFFF2F3F7),
            child: Icon(icon, color: iconColor),
          ),
          title: Text(title, style: TextStyle(color: Color(0xFF222B45), fontWeight: FontWeight.w600)),
          subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: Color(0xFFB0B8C1), fontSize: 13)) : null,
          trailing: Icon(Icons.arrow_forward_ios, color: Color(0xFFB0B8C1), size: 18),
          onTap: () {},
        ),
      ),
    );
  }
}