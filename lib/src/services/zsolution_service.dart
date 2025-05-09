import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/zsolution_config.dart';
import '../models/zsolution_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ZSolutionService {
  static String? _token;
  static String? _serverId;

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
      print('Getting server ID with token: $_token'); // Debug log
      final response = await http.get(
        Uri.parse('https://gateway.api.staging.zsolution.vn/softphone/Phones/company/servers'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      print('Server response status: ${response.statusCode}'); // Debug log
      print('Server response body: ${response.body}'); // Debug log

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Parsed server data: $data'); // Debug log

        if (data != null) {
          if (data['code'] == 200 && data['data'] != null) {
            final servers = data['data'] as List;
            if (servers.isNotEmpty) {
              final server = servers[0];
              if (server['serverId'] != null) {
                _serverId = server['serverId'].toString();
                print('Found server ID: $_serverId'); // Debug log
                return _serverId!;
              }
            }
          } else {
            print('API returned error: ${data['message']}'); // Debug log
            throw Exception(data['message'] ?? 'Không thể lấy thông tin server');
          }
        }
      }
      throw Exception('Không thể lấy thông tin server: ${response.statusCode}');
    } catch (e) {
      print('Error getting server ID: $e');
      throw Exception('Không thể lấy thông tin server: $e');
    }
  }

  static Future<ZSolutionUser> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ZSolutionConfig.loginUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('Login API Response: $jsonResponse'); // Debug print
        if (jsonResponse['code'] == 200) {
          _token = jsonResponse['data']['token'];
          // Get user data from the correct nested structure
          final userData = jsonResponse['data']['user'];
          print('User data to parse: $userData'); // Debug print
          return ZSolutionUser.fromJson(userData);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Đăng nhập thất bại');
        }
      } else {
        throw Exception('Đăng nhập thất bại: ${response.body}');
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
      // Lấy server ID
      final serverId = await _getServerId();
      
      // Tính ngày bắt đầu (7 ngày trước)
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: 7));
      final startDateStr = startDate.toIso8601String();

      final response = await http.post(
        Uri.parse('https://gateway.api.staging.zsolution.vn/softphone/CallHistory/search'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: jsonEncode({
          'pageIndex': 0,
          'pageSize': 50,
          'serverId': serverId,
          'startDate': startDateStr,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Call history response: $data'); // Debug log
        
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
      print('Error fetching call history: $e');
      throw Exception('Failed to load call history: $e');
    }
  }
} 