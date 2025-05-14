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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Lịch sử cuộc gọi',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.search, color: Colors.black87),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.tune, color: Colors.black87),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(16),
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
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 0 ? Colors.white : Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTab == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : [],
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedTab = 1;
                          });
                        },
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedTab == 1 ? Colors.white : Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _selectedTab == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ]
                                : [],
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
            ),
            const SizedBox(height: 16),
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
                                style: TextStyle(color: Colors.black54),
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
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              itemCount: _getFilteredHistory().length,
                              separatorBuilder: (context, idx) => SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final call = _getFilteredHistory()[index];
                                String timeStr = '';
                                try {
                                  final now = DateTime.now();
                                  final callDate = call.dateTime;
                                  final hourMinute = '${callDate.hour.toString().padLeft(2, '0')}:${callDate.minute.toString().padLeft(2, '0')}';
                                  timeStr = hourMinute;
                                } catch (_) {}
                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 26,
                                        backgroundColor: Color(0xFFE3F0FA),
                                        child: Icon(Icons.person, color: Color(0xFF6B7A8F), size: 32),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Không xác định',
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              call.phoneNumber,
                                              style: TextStyle(
                                                color: Color(0xFF6B7A8F),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  call.missed ? Icons.call_missed : Icons.call_made,
                                                  color: call.missed ? Color(0xFFF15B5B) : Color(0xFF4BC17B),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  call.missed
                                                      ? 'Cuộc gọi đi / Không trả lời'
                                                      : 'Cuộc gọi đi / Trả lời',
                                                  style: TextStyle(
                                                    color: call.missed ? Color(0xFFF15B5B) : Color(0xFF4BC17B),
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              color: Color(0xFFB0B8C1),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
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