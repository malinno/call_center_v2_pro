import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/zsolution_config.dart';
import '../models/zsolution_user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class ZSolutionService {
  static String? _token;
  static String? _serverId;
  static BuildContext? _context;

  static void setContext(BuildContext context) {
    _context = context;
  }

  static Future<void> _handleUnauthorized() async {
    // Xóa token và thông tin user
    _token = null;
    _serverId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('zsolution_token');
    await prefs.remove('zsolution_user');
    await prefs.remove('zsolution_email');
    await prefs.remove('zsolution_password');
    await prefs.remove('zsolution_remember_me');

    // Nếu có context, chuyển về màn hình đăng nhập
    if (_context != null) {
      Navigator.of(_context!).pushNamedAndRemoveUntil(
        '/zsolution',
        (route) => false,
      );
    }
  }

  static Future<http.Response> _makeRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();

      // Kiểm tra status 401
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> _loadToken() async {
    if (_token == null) {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('zsolution_token');
    }
  }

  static Future<String> _getServerId() async {
    if (_serverId != null) return _serverId!;

    await _loadToken();
    if (_token == null) {
      throw Exception('Chưa đăng nhập');
    }

    try {
      final response = await _makeRequest(() => http.get(
            Uri.parse(ZSolutionConfig.companyServersUrl),
            headers: {
              ...ZSolutionConfig.defaultHeaders,
              'Authorization': 'Bearer $_token',
            },
          ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null) {
          if (data['code'] == 200 && data['data'] != null) {
            final servers = data['data'] as List;
            if (servers.isNotEmpty) {
              final server = servers[0];
              if (server['serverId'] != null) {
                _serverId = server['serverId'].toString();
                return _serverId!;
              }
            }
          } else {
            throw Exception(
                data['message'] ?? 'Không thể lấy thông tin server');
          }
        }
      }
      throw Exception('Không thể lấy thông tin server: ${response.statusCode}');
    } catch (e) {
      throw Exception('Không thể lấy thông tin server: $e');
    }
  }

  static Future<ZSolutionUser> login(String email, String password) async {
    try {
      final response = await _makeRequest(() => http.post(
            Uri.parse(ZSolutionConfig.loginUrl),
            headers: ZSolutionConfig.defaultHeaders,
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          ));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['code'] == 200 && jsonResponse['data'] != null) {
          _token = jsonResponse['data']['token'];
          if (_token != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('zsolution_token', _token!);
          }
          final userData = jsonResponse['data']['user'];
          if (userData == null) {
            throw Exception('Không tìm thấy thông tin người dùng');
          }

          final user = ZSolutionUser.fromJson(userData);
          if (user.host == null || user.host!.isEmpty) {
            throw Exception('Không tìm thấy thông tin host');
          }
          if (user.extension == null || user.extension!.isEmpty) {
            throw Exception('Không tìm thấy thông tin extension');
          }
          if (user.pass == null || user.pass!.isEmpty) {
            throw Exception('Không tìm thấy thông tin mật khẩu SIP');
          }

          return user;
        } else {
          final errorMessage = jsonResponse['message'] ?? 'Đăng nhập thất bại';
          throw Exception(errorMessage);
        }
      } else {
        throw Exception(
            'Đăng nhập thất bại: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Lỗi kết nối: $e');
    }
  }

  static Future<List<Map<String, String>>> getCallHistory() async {
    await _loadToken();
    if (_token == null) {
      throw Exception('Chưa đăng nhập');
    }

    try {
      final serverId = await _getServerId();

      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final startDateStr = startDate.toIso8601String();

      final response = await _makeRequest(() => http.post(
            Uri.parse(ZSolutionConfig.callHistorySearchUrl),
            headers: {
              ...ZSolutionConfig.defaultHeaders,
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({
              'pageIndex': 0,
              'pageSize': ZSolutionConfig.defaultPageSize,
              'serverId': serverId,
              'startDate': startDateStr,
            }),
          ));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['data'] != null) {
          final List<dynamic> historyData = data['data'];
          return historyData.map((item) {
            if (item is Map<String, dynamic>) {
              return {
                'src': item['src']?.toString() ?? '',
                'dst': item['dst']?.toString() ?? '',
                'callDate': item['callDate']?.toString() ?? '',
              };
            }
            return {'src': '', 'dst': '', 'callDate': ''};
          }).toList();
        }
      }
      throw Exception('Failed to load call history: ${response.body}');
    } catch (e) {
      throw Exception('Failed to load call history: $e');
    }
  }

  static Future<List<Map<String, String>>> searchCallHistoryByPhone(
      String phoneNumber) async {
    print(
        '[ZSolutionService] searchCallHistoryByPhone gọi với số: $phoneNumber');
    await _loadToken();
    if (_token == null) {
      throw Exception('Chưa đăng nhập');
    }

    try {
      final serverId = await _getServerId();
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final startDateStr = startDate.toIso8601String();

      print('[ZSolutionService] Đang gửi request tìm kiếm...');
      final response = await _makeRequest(() => http.post(
            Uri.parse(ZSolutionConfig.callHistorySearchUrl),
            headers: {
              ...ZSolutionConfig.defaultHeaders,
              'Authorization': 'Bearer $_token',
            },
            body: jsonEncode({
              'pageIndex': 0,
              'pageSize': ZSolutionConfig.defaultPageSize,
              'serverId': serverId,
              'startDate': startDateStr,
              'phoneNumber': phoneNumber,
            }),
          ));

      print(
          '[ZSolutionService] Kết quả response: ${response.statusCode} - ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['data'] != null) {
          final List<dynamic> historyData = data['data'];
          return historyData.map((item) {
            if (item is Map<String, dynamic>) {
              return {
                'src': item['src']?.toString() ?? '',
                'dst': item['dst']?.toString() ?? '',
                'callDate': item['callDate']?.toString() ?? '',
              };
            }
            return {'src': '', 'dst': '', 'callDate': ''};
          }).toList();
        }
      }
      throw Exception('Failed to load call history: ${response.body}');
    } catch (e) {
      throw Exception('Failed to load call history: $e');
    }
  }
   static Future<void> updateProfile({
    required int id,
    required String userName,
    required String email,
    required String phone,
  }) async {
    await _loadToken();
    if (_token == null) {
      throw Exception('Chưa đăng nhập');
    }
    final url = '${ZSolutionConfig.baseUrl}/softphone/Users/update-profile';
    final response = await _makeRequest(() => http.put(
      Uri.parse(url),
      headers: {
        ...ZSolutionConfig.defaultHeaders,
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'id': id,
        'userName': userName,
        'email': email,
        'phone': phone,
      }),
    ));
    print("Cập nhật thông tin: ${response.body}");
    if (response.statusCode != 200) {
      throw Exception('Cập nhật thông tin thất bại: ${response.body}');
    }
    final jsonResponse = jsonDecode(response.body);
    if (jsonResponse['code'] != 200) {
      throw Exception(jsonResponse['message'] ?? 'Cập nhật thông tin thất bại');
    }
  }
}
