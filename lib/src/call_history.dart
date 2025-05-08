import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:sip_ua/sip_ua.dart';
import 'package:http/http.dart' as http;
import 'services/zsolution_service.dart';
import 'callscreen.dart';

// Model cho lịch sử cuộc gọi
class CallHistoryEntry {
  final String phoneNumber;
  final DateTime dateTime;
  final String region;
  final bool missed;
  final String? srcNumber; // Thêm trường cho số gọi đi

  CallHistoryEntry({
    required this.phoneNumber,
    required this.dateTime,
    required this.region,
    this.missed = false,
    this.srcNumber,
  });

  Map<String, dynamic> toJson() => {
    'phoneNumber': phoneNumber,
    'dateTime': dateTime.toIso8601String(),
    'region': region,
    'missed': missed,
    'srcNumber': srcNumber,
  };

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) => CallHistoryEntry(
    phoneNumber: json['phoneNumber'],
    dateTime: DateTime.parse(json['dateTime']),
    region: json['region'],
    missed: json['missed'] ?? false,
    srcNumber: json['srcNumber'],
  );
}

// Hàm lưu lịch sử cuộc gọi
Future<void> saveCallHistory(String phoneNumber, {bool missed = false}) async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final region = getRegionName(phoneNumber);
  final entry = CallHistoryEntry(
    phoneNumber: phoneNumber,
    dateTime: now,
    region: region,
    missed: missed,
  );
  List<String> history = prefs.getStringList('call_history') ?? [];
  history.insert(0, jsonEncode(entry.toJson()));
  if (history.length > 50) {
    history = history.sublist(0, 50);
  }
  await prefs.setStringList('call_history', history);
}

// Hàm xác định vùng dựa vào số điện thoại
String getRegionName(String phoneNumber) {
  if (phoneNumber.startsWith('84') || phoneNumber.startsWith('+84')) {
    return 'Việt Nam';
  }
  // Thêm các vùng khác nếu muốn
  return 'Không xác định';
}

class CallHistoryWidget extends StatefulWidget {
  final SIPUAHelper? helper;
  CallHistoryWidget({this.helper, Key? key}) : super(key: key);

  @override
  _CallHistoryWidgetState createState() => _CallHistoryWidgetState();
}

class _CallHistoryWidgetState extends State<CallHistoryWidget> {
  List<CallHistoryEntry> _callHistory = [];
  bool _isZSolutionLogin = false;
  bool _isLoading = true;
  String? _error;
  int _selectedTab = 0; // 0: Tất cả, 1: Gọi nhỡ

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
  }

  Future<void> _loadCallHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final zsolutionUserJson = prefs.getString('zsolution_user');
      _isZSolutionLogin = zsolutionUserJson != null && zsolutionUserJson.isNotEmpty;

      if (_isZSolutionLogin) {
        try {
          // Load call history from ZSolution API
          final history = await ZSolutionService.getCallHistory();
          setState(() {
            _callHistory = history.map((item) => CallHistoryEntry(
              phoneNumber: item['dst'] ?? '',
              dateTime: item['callDate'] != null ? DateTime.tryParse(item['callDate']!) ?? DateTime.now() : DateTime.now(),
              region: getRegionName(item['dst'] ?? ''),
              missed: false,
              srcNumber: item['src'],
            )).toList();
            _isLoading = false;
          });
        } catch (e) {
          print('Error loading ZSolution call history: $e');
          setState(() {
            _error = 'Không thể tải lịch sử cuộc gọi từ ZSolution';
            _isLoading = false;
          });
        }
      } else {
        // Load call history from local storage
        final historyJson = prefs.getStringList('call_history') ?? [];
        setState(() {
          _callHistory = historyJson
              .map((json) {
                try {
                  return CallHistoryEntry.fromJson(jsonDecode(json));
                } catch (e) {
                  print('Error parsing call history entry: $e');
                  return null;
                }
              })
              .where((entry) => entry != null)
              .cast<CallHistoryEntry>()
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in _loadCallHistory: $e');
      setState(() {
        _error = 'Không thể tải lịch sử cuộc gọi';
        _isLoading = false;
      });
    }
  }

  List<CallHistoryEntry> _getFilteredHistory() {
    if (_selectedTab == 0) {
      return _callHistory;
    } else {
      return _callHistory.where((call) => call.missed).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lịch sử cuộc gọi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadCallHistory,
                  ),
                ],
              ),
            ),
            // Custom iOS-style tabs
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 0;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.grey.shade200 : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Tất cả',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTab = 1;
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.grey.shade200 : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Gọi nhỡ',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error!,
                                style: TextStyle(color: Colors.white70),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadCallHistory,
                                child: Text('Thử lại'),
                              ),
                            ],
                          ),
                        )
                      : _getFilteredHistory().isEmpty
                          ? Center(
                              child: Text(
                                _selectedTab == 0 
                                    ? 'Không có lịch sử cuộc gọi'
                                    : 'Không có cuộc gọi nhỡ',
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _getFilteredHistory().length,
                              itemBuilder: (context, index) {
                                final call = _getFilteredHistory()[index];
                                String timeStr = '';
                                try {
                                  final now = DateTime.now();
                                  final callDate = call.dateTime;
                                  final isToday = now.year == callDate.year && now.month == callDate.month && now.day == callDate.day;
                                  final yesterday = now.subtract(Duration(days: 1));
                                  final isYesterday = yesterday.year == callDate.year && yesterday.month == callDate.month && yesterday.day == callDate.day;
                                  final hourMinute = '${callDate.hour.toString().padLeft(2, '0')}:${callDate.minute.toString().padLeft(2, '0')}';
                                  if (isToday) {
                                    timeStr = '$hourMinute Hôm nay';
                                  } else if (isYesterday) {
                                    timeStr = '$hourMinute Hôm qua';
                                  } else {
                                    timeStr = '$hourMinute ${callDate.day.toString().padLeft(2, '0')}/${callDate.month.toString().padLeft(2, '0')}/${callDate.year}';
                                  }
                                } catch (_) {}
                                return ListTile(
                                  leading: Icon(
                                    call.missed ? Icons.call_missed : Icons.call_received,
                                    color: call.missed ? Colors.red : Colors.green,
                                  ),
                                  title: Text(
                                    call.phoneNumber,
                                    style: TextStyle(
                                      color: call.missed ? Colors.red : Colors.white,
                                      fontWeight: call.missed ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _isZSolutionLogin
                                        ? 'Số gọi đi: ${call.srcNumber ?? ''}'
                                        : '${call.dateTime.toString()} - ${call.region}',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          // Gọi số điện thoại
                                          _callNumber(context, call.phoneNumber);
                                        },
                                        child: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.blue.shade200),
                                          ),
                                          child: Icon(Icons.call, color: Colors.blue, size: 18),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // Thêm hàm gọi số
  void _callNumber(BuildContext context, String phoneNumber) async {
    // Nếu có helper thì thực hiện gọi SIP
    if (widget.helper != null) {
      widget.helper!.call(phoneNumber);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreenWidget(widget.helper, null),
        ),
      );
    } else {
      // Nếu không có helper, chỉ log ra
      print('Gọi số: $phoneNumber');
    }
  }
}