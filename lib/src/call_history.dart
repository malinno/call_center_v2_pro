import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:sip_ua/sip_ua.dart';

// Model cho lịch sử cuộc gọi
class CallHistoryEntry {
  final String phoneNumber;
  final DateTime dateTime;
  final String region;
  final bool missed;

  CallHistoryEntry({
    required this.phoneNumber,
    required this.dateTime,
    required this.region,
    this.missed = false,
  });

  Map<String, dynamic> toJson() => {
    'phoneNumber': phoneNumber,
    'dateTime': dateTime.toIso8601String(),
    'region': region,
    'missed': missed,
  };

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) => CallHistoryEntry(
    phoneNumber: json['phoneNumber'],
    dateTime: DateTime.parse(json['dateTime']),
    region: json['region'],
    missed: json['missed'] ?? false,
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
  State<CallHistoryWidget> createState() => _CallHistoryWidgetState();
}

class _CallHistoryWidgetState extends State<CallHistoryWidget> {
  List<CallHistoryEntry> _history = [];
  int _selectedTab = 0; // 0: Tất cả, 1: Gọi nhỡ

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('call_history') ?? [];
    setState(() {
      _history = list.map((e) => CallHistoryEntry.fromJson(jsonDecode(e))).toList();
    });
  }

  String getWeekdayName(DateTime date) {
    const weekdays = [
      'Thứ hai', 'Thứ ba', 'Thứ tư', 'Thứ năm', 'Thứ sáu', 'Thứ bảy','Chủ nhật'
    ];
    return weekdays[date.weekday % 7];
  }

  void _handleCallBack(String phoneNumber) {
    if (widget.helper != null) {
      widget.helper!.call(phoneNumber, voiceOnly: true);
      Navigator.pushNamed(context, '/callscreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final missedCalls = _history.where((e) => e.missed).toList();
    final tabs = ["Tất cả", "Gọi nhỡ"];
    final lists = [_history, missedCalls];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 36,
              padding: EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: List.generate(2, (i) => GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  child: Container(
                    width: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedTab == i ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tabs[i],
                      style: TextStyle(
                        color: _selectedTab == i ? Colors.black : Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )),
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {},
            child: Text('Sửa', style: TextStyle(color: Colors.blue, fontSize: 16)),
          ),
        ],
      ),
      body: _buildList(lists[_selectedTab]),
    );
  }

  Widget _buildList(List<CallHistoryEntry> list) {
    if (list.isEmpty) {
      return Center(child: Text('Không có dữ liệu', style: TextStyle(color: Colors.black45)));
    }
    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: Color(0xFFF2F2F7)),
      itemBuilder: (context, index) {
        final entry = list[index];
        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 2),
          title: Text(
            entry.phoneNumber,
            style: TextStyle(
              color: entry.missed ? Colors.red : Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 17,
            ),
          ),
          subtitle: Text(
            'Cuộc gọi thoại',
            style: TextStyle(color: Colors.black54, fontSize: 14),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${entry.dateTime.hour.toString().padLeft(2, '0')}:${entry.dateTime.minute.toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.black45, fontSize: 15),
              ),
              SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Color(0xFFE5F3FF),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_outline, color: Color(0xFF007AFF), size: 18),
              ),
            ],
          ),
          onTap: () {},
        );
      },
    );
  }
}