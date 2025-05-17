import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'config/zsolution_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validate
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage('Vui lòng nhập đầy đủ thông tin', isError: true);
      return;
    }
    if (newPassword != confirmPassword) {
      _showMessage('Mật khẩu mới và xác nhận mật khẩu phải giống nhau',
          isError: true);
      return;
    }
    if (newPassword.length < 6) {
      _showMessage('Mật khẩu mới phải có ít nhất 6 ký tự', isError: true);
      return;
    }

    setState(() => _loading = true);
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
            Text('Đang đổi mật khẩu...'),
          ],
        ),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('zsolution_token') ?? '';
      print('Token: $token');
      final response = await http.post(
        Uri.parse(ZSolutionConfig.changePasswordUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );
      print('Request body: ${jsonEncode({
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          })}');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() => _loading = false);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['code'] == 200) {
        _showMessage('Đổi mật khẩu thành công! Vui lòng đăng nhập lại.',
            isError: false);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('zsolution_token');
        await prefs.remove('zsolution_user');
        await prefs.remove('zsolution_email');
        await prefs.remove('zsolution_password');
        await prefs.remove('zsolution_remember_me');
        // Chuyển về màn hình đăng nhập (tùy route app bạn)
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/zsolution', (route) => false);
        });
        return;
      } else {
        final errorMsg = _parseError(response.body) ??
            'Mật khẩu hiện tại không đúng hoặc có lỗi xảy ra.';
        _showMessage(errorMsg, isError: true);
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      setState(() => _loading = false);
      _showMessage('Có lỗi xảy ra. Vui lòng thử lại!', isError: true);
    }
  }

  String? _parseError(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Đổi mật khẩu',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPasswordField(
              label: 'Mật khẩu hiện tại',
              controller: _currentPasswordController,
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            SizedBox(height: 14),
            _buildPasswordField(
              label: 'Mật khẩu mới',
              controller: _newPasswordController,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            SizedBox(height: 14),
            _buildPasswordField(
              label: 'Xác nhận mật khẩu',
              controller: _confirmPasswordController,
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1A2746),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text('Cập nhật',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF7F9FB),
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          hintText: 'Nhập mật khẩu',
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure
                  ? Icons.remove_red_eye_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
