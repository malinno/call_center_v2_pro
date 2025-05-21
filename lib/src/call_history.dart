import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:sip_ua/sip_ua.dart';
import 'package:http/http.dart' as http;
import 'services/zsolution_service.dart';
import 'callscreen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'widgets/add_customer_page.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CallHistoryEntry {
  final String phoneNumber;
  final DateTime dateTime;
  final String region;
  final bool missed;
  final String? srcNumber;
  final String? recordingFile;

  CallHistoryEntry({
    required this.phoneNumber,
    required this.dateTime,
    required this.region,
    this.missed = false,
    this.srcNumber,
    this.recordingFile,
  });

  Map<String, dynamic> toJson() => {
        'phoneNumber': phoneNumber,
        'dateTime': dateTime.toIso8601String(),
        'region': region,
        'missed': missed,
        'srcNumber': srcNumber,
        'recordingFile': recordingFile,
      };

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CallHistoryEntry(
        phoneNumber: json['phoneNumber'],
        dateTime: DateTime.parse(json['dateTime']),
        region: json['region'],
        missed: json['missed'] ?? false,
        srcNumber: json['srcNumber'],
        recordingFile: json['recordingFile'],
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

class _CallHistoryWidgetState extends State<CallHistoryWidget>
    implements SipUaHelperListener {
  List<CallHistoryEntry> _callHistory = [];
  bool _isZSolutionLogin = false;
  bool _isLoading = true;
  String? _error;
  Call? _currentCall;
  bool _isSearching = false;
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCallHistory();
    widget.helper?.addSipUaHelperListener(this);
  }

  @override
  void dispose() {
    widget.helper?.removeSipUaHelperListener(this);
    super.dispose();
  }

  @override
  void callStateChanged(Call call, CallState state) {
    if (state.state == CallStateEnum.CALL_INITIATION) {
      setState(() {
        _currentCall = call;
      });
      // Cập nhật lại màn hình CallScreen nếu đang hiển thị
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => CallScreenWidget(widget.helper, call),
          ),
        );
      }
    }
  }

  Future<void> _loadCallHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final zsolutionUserJson = prefs.getString('zsolution_user');
      _isZSolutionLogin =
          zsolutionUserJson != null && zsolutionUserJson.isNotEmpty;
      if (_isZSolutionLogin) {
        try {
          // Load call history from ZSolution API
          final history = await ZSolutionService.getCallHistory();
          setState(() {
            _callHistory = history
                .map((item) => CallHistoryEntry(
                      phoneNumber: item['dst'] ?? '',
                      dateTime: item['callDate'] != null
                          ? DateTime.tryParse(item['callDate']!) ??
                              DateTime.now()
                          : DateTime.now(),
                      region: getRegionName(item['dst'] ?? ''),
                      missed: _isMissedStatus(item['callStatus'],
                          item['billSec'], item['duration']),
                      srcNumber: item['src'],
                      recordingFile: item['recordingFile'],
                    ))
                .toList();
            _isLoading = false;
          });
          print('App missed list: ${_callHistory.map((e) => {
                'phone': e.phoneNumber,
                'missed': e.missed
              })}');
        } catch (e) {
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
      setState(() {
        _error = 'Không thể tải lịch sử cuộc gọi';
        _isLoading = false;
      });
    }
  }

  // Hàm nhóm lịch sử theo ngày
  Map<String, List<CallHistoryEntry>> groupByDate(
      List<CallHistoryEntry> entries) {
    Map<String, List<CallHistoryEntry>> grouped = {};
    final now = DateTime.now();
    for (var entry in entries) {
      String key;
      final entryDate = DateTime(
          entry.dateTime.year, entry.dateTime.month, entry.dateTime.day);
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(Duration(days: 1));
      if (entryDate == today) {
        key = 'Hôm nay';
      } else if (entryDate == yesterday) {
        key = 'Hôm qua';
      } else {
        key =
            '${entry.dateTime.day.toString().padLeft(2, '0')}/${entry.dateTime.month.toString().padLeft(2, '0')}/${entry.dateTime.year}';
      }
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    // Đảm bảo thứ tự ngày mới nhất lên trên
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Hôm nay') return -1;
        if (b == 'Hôm nay') return 1;
        if (a == 'Hôm qua') return -1;
        if (b == 'Hôm qua') return 1;
        // parse dd/MM/yyyy
        DateTime parseDate(String s) {
          final parts = s.split('/');
          return DateTime(
              int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }

        return parseDate(b).compareTo(parseDate(a));
      });
    Map<String, List<CallHistoryEntry>> sorted = {};
    for (var k in sortedKeys) {
      sorted[k] = grouped[k]!;
    }
    return sorted;
  }

  List<CallHistoryEntry> filterLastMonth(List<CallHistoryEntry> entries) {
    final now = DateTime.now();
    final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);
    return entries
        .where((entry) => entry.dateTime.isAfter(oneMonthAgo))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final lastMonthHistory = filterLastMonth(_callHistory);
    final groupedHistory = groupByDate(lastMonthHistory);
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _isSearching
                        ? Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Color(0xFFE6F6FE),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Color(0xFF00AEEF), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 8),
                                Icon(Icons.search, color: Color(0xFF223A5E)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    autofocus: true,
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Tìm kiếm',
                                    ),
                                    style: TextStyle(fontSize: 16),
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (value) {
                                      _onSearch(value);
                                    },
                                    onChanged: (value) {
                                      setState(() {});
                                    },
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: Icon(Icons.close, color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                      });
                                      _loadCallHistory();
                                    },
                                  ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
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
                      icon: Icon(_isSearching ? Icons.close : Icons.search,
                          color: Colors.black87),
                      onPressed: () {
                        setState(() {
                          _isSearching = !_isSearching;
                          if (!_isSearching) _searchController.clear();
                        });
                      },
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
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) => const FilterSheet(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: LoadingAnimationWidget.inkDrop(
                        color: Color(0xFF223A5E),
                        size: 38,
                      ),
                    )
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
                      : _callHistory.isEmpty
                          ? Center(
                              child: Text(
                                'Không có lịch sử cuộc gọi',
                                style: TextStyle(color: Colors.black54),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              itemCount: groupedHistory.length == 0
                                  ? 0
                                  : groupedHistory.entries
                                      .map((e) => e.value.length + 1)
                                      .reduce((a, b) => a + b),
                              itemBuilder: (context, idx) {
                                int runningIdx = 0;
                                for (final entry in groupedHistory.entries) {
                                  // Section title
                                  if (idx == runningIdx) {
                                    return _buildSectionTitle(entry.key);
                                  }
                                  runningIdx++;
                                  // Items
                                  for (int i = 0; i < entry.value.length; i++) {
                                    if (idx == runningIdx) {
                                      final call = entry.value[i];
                                      String timeStr = '';
                                      final now = DateTime.now();
                                      final today = DateTime(
                                          now.year, now.month, now.day);
                                      final callDate = DateTime(
                                          call.dateTime.year,
                                          call.dateTime.month,
                                          call.dateTime.day);
                                      if (callDate == today) {
                                        final hourMinute =
                                            '${call.dateTime.hour.toString().padLeft(2, '0')}:${call.dateTime.minute.toString().padLeft(2, '0')}';
                                        timeStr = hourMinute;
                                      } else {
                                        timeStr =
                                            '${call.dateTime.hour.toString().padLeft(2, '0')}:${call.dateTime.minute.toString().padLeft(2, '0')}';
                                      }
                                      return GestureDetector(
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.vertical(
                                                      top: Radius.circular(20)),
                                            ),
                                            isScrollControlled: true,
                                            builder: (context) =>
                                                CallDetailSheet(
                                              call: call,
                                              onCallBack: () => _callNumber(
                                                  context, call.phoneNumber),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.07),
                                                blurRadius: 12,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              CircleAvatar(
                                                radius: 28,
                                                backgroundColor:
                                                    Color(0xFFE3F0FA),
                                                child: Icon(Icons.person,
                                                    color: Color(0xFF6B7A8F),
                                                    size: 36),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Không xác định',
                                                      style: TextStyle(
                                                        color:
                                                            Color(0xFF223A5E),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 17,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      call.phoneNumber,
                                                      style: TextStyle(
                                                        color:
                                                            Color(0xFF223A5E),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 15.5,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          call.missed
                                                              ? Icons
                                                                  .call_missed
                                                              : Icons.call_made,
                                                          color: call.missed
                                                              ? Color(
                                                                  0xFFF15B5B)
                                                              : Color(
                                                                  0xFF4BC17B),
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                          call.missed
                                                              ? 'Cuộc gọi đi / Không trả lời'
                                                              : 'Cuộc gọi đi / Trả lời',
                                                          style: TextStyle(
                                                            color: call.missed
                                                                ? Color(
                                                                    0xFFF15B5B)
                                                                : Color(
                                                                    0xFF4BC17B),
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 14.2,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    timeStr,
                                                    style: TextStyle(
                                                      color: Color(0xFFB0B8C1),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    runningIdx++;
                                  }
                                }
                                return SizedBox.shrink();
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
    print('CallHistory - _callNumber called');
    // Nếu có helper thì thực hiện gọi SIP
    if (widget.helper != null) {
      final success = await widget.helper!.call(phoneNumber, voiceOnly: true);
      if (mounted && success) {
        print('CallHistory - Navigating to CallScreen with source: history');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CallScreenWidget(widget.helper, _currentCall,
                source: 'history'),
          ),
        ).then((_) {
          // Khi quay về từ CallScreen, reload lại lịch sử cuộc gọi
          print('CallHistory - Returned from CallScreen, reloading history');
          _loadCallHistory();
        });
      }
    } else {
      // Nếu không có helper, chỉ log ra
      print('Gọi số: $phoneNumber');
    }
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void registrationStateChanged(RegistrationState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}

  void _onSearch(String value) async {
    print('[UI] Bắt đầu tìm kiếm với số: $value');
    if (value.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final history =
          await ZSolutionService.searchCallHistoryByPhone(value.trim());
      print('[UI] Đã nhận kết quả từ API, số bản ghi: ${history.length}');
      setState(() {
        _callHistory = history
            .map((item) => CallHistoryEntry(
                  phoneNumber: item['dst'] ?? '',
                  dateTime: item['callDate'] != null
                      ? DateTime.tryParse(item['callDate']!) ?? DateTime.now()
                      : DateTime.now(),
                  region: getRegionName(item['dst'] ?? ''),
                  missed: _isMissedStatus(
                      item['callStatus'], item['billSec'], item['duration']),
                  srcNumber: item['src'],
                  recordingFile: item['recordingFile'],
                ))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Không thể tìm kiếm lịch sử cuộc gọi';
        _isLoading = false;
      });
    }
  }

  // Thêm hàm helper để xác định missed
  bool _isMissedStatus(dynamic status, dynamic billSec, dynamic duration) {
    final s = status?.toString()?.toUpperCase() ?? '';
    if (s == 'ANSWERED') return false;
    if (s == 'NO ANSWER' || s == 'FAILED') return true;
    // Nếu không có callStatus, fallback theo billSec/duration
    if ((billSec is int && billSec > 0) || (duration is int && duration > 0))
      return false;
    return true;
  }
}

class CallDetailSheet extends StatefulWidget {
  final CallHistoryEntry call;
  final VoidCallback onCallBack;
  const CallDetailSheet(
      {Key? key, required this.call, required this.onCallBack})
      : super(key: key);

  @override
  State<CallDetailSheet> createState() => _CallDetailSheetState();
}

class _CallDetailSheetState extends State<CallDetailSheet> {
  AudioPlayer? _audioPlayer;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    if (widget.call.recordingFile != null &&
        widget.call.recordingFile!.isNotEmpty) {
      _audioPlayer = AudioPlayer();
      _audioPlayer!.onDurationChanged.listen((d) {
        setState(() => _duration = d);
      });
      _audioPlayer!.onPositionChanged.listen((p) {
        if (!_isSeeking) setState(() => _position = p);
      });
      _audioPlayer!.onPlayerStateChanged.listen((state) {
        setState(() => _isPlaying = state == PlayerState.playing);
      });
      _audioPlayer!.onPlayerComplete.listen((event) {
        setState(() {
          _position = Duration.zero;
          _isPlaying = false;
        });
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _play() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.play(DeviceFileSource(widget.call.recordingFile!));
    }
  }

  void _pause() async {
    if (_audioPlayer != null) {
      await _audioPlayer!.pause();
    }
  }

  void _seek(Duration d) async {
    if (_audioPlayer != null) {
      await _audioPlayer!.seek(d);
      await _audioPlayer!.resume();
    }
  }

  void _downloadRecording(BuildContext context) async {
    final url = widget.call.recordingFile;
    if (url == null || url.isEmpty) return;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = url.split('/').last;
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tải file ghi âm thành công!\n${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tải file ghi âm thất bại!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải file ghi âm!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final call = widget.call;
    final dateStr =
        '${call.dateTime.hour.toString().padLeft(2, '0')}:${call.dateTime.minute.toString().padLeft(2, '0')} '
        '${call.dateTime.day.toString().padLeft(2, '0')}/${call.dateTime.month.toString().padLeft(2, '0')}/${call.dateTime.year}';
    final callId = '790e1e10-6dee-4443-b1f5-1e76e...'; // demo
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chi tiết cuộc gọi',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF223A5E))),
                      const SizedBox(height: 2),
                      Text(
                        callId,
                        style:
                            TextStyle(fontSize: 13.5, color: Color(0xFFB0B8C1)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _SquareIconButton(
                      icon: Icons.person_add_alt,
                      bgColor: Color(0xFF4BC17B),
                      iconColor: Colors.white,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AddCustomerPage(initialPhone: call.phoneNumber),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _SquareIconButton(
                      icon: Icons.copy,
                      bgColor: Color(0xFF1A2236),
                      iconColor: Colors.white,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: callId));
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Thành công'),
                            content: Text('Đã sao chép mã cuộc gọi!'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _SquareIconButton(
                      icon: Icons.edit,
                      bgColor: Color(0xFFF5F7FA),
                      iconColor: Color(0xFF223A5E),
                      onTap: () {
                        Navigator.of(context).pop();
                        showModalBottomSheet(
                          context: context,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          isScrollControlled: true,
                          builder: (context) => EditCallDetailSheet(call: call),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Thông tin người gọi
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Color(0xFFE3F0FA),
                  child: Icon(Icons.person, color: Color(0xFF6B7A8F), size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Không xác định',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16.5,
                              color: Color(0xFF223A5E))),
                      const SizedBox(height: 2),
                      Text(call.phoneNumber,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Color(0xFF223A5E))),
                    ],
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                      color: Color(0xFFB0B8C1),
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Trạng thái cuộc gọi
            Row(
              children: [
                Icon(
                  call.missed ? Icons.call_missed : Icons.call_made,
                  color: call.missed ? Color(0xFFF15B5B) : Color(0xFF4BC17B),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  call.missed
                      ? 'Cuộc gọi đi / Không trả lời'
                      : 'Cuộc gọi đi / Trả lời',
                  style: TextStyle(
                    color: call.missed ? Color(0xFFF15B5B) : Color(0xFF4BC17B),
                    fontWeight: FontWeight.w600,
                    fontSize: 15.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // PHẦN GHI ÂM ĐÚNG UI/UX ẢNH USER GỬI
            if (!call.missed &&
                call.recordingFile != null &&
                call.recordingFile!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    // Slider tím mảnh, KHÔNG có số giây bên phải
                    Slider(
                      min: 0,
                      max: _duration.inMilliseconds.toDouble(),
                      value: _position.inMilliseconds
                          .clamp(0, _duration.inMilliseconds)
                          .toDouble(),
                      activeColor: const Color.fromARGB(255, 1, 9, 78),
                      inactiveColor: const Color.fromARGB(255, 209, 206, 214),
                      thumbColor: const Color.fromARGB(255, 1, 9, 78),
                      onChangeStart: (_) => setState(() => _isSeeking = true),
                      onChanged: (value) {
                        setState(() =>
                            _position = Duration(milliseconds: value.toInt()));
                      },
                      onChangeEnd: (value) {
                        setState(() => _isSeeking = false);
                        _seek(Duration(milliseconds: value.toInt()));
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Call
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFF223A5E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(Icons.phone,
                                color: Colors.white, size: 24),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Download
                        Container(
                          height: 44,
                          width: 44,
                          decoration: BoxDecoration(
                            color: Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Icon(Icons.download_rounded,
                                color: Color(0xFF223A5E), size: 24),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Play + thời gian (chiếm hết phần còn lại)
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                IconButton(
                                  icon: Icon(
                                      _isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Color(0xFF223A5E)),
                                  onPressed: () {
                                    if (_isPlaying) {
                                      _pause();
                                    } else {
                                      _play();
                                    }
                                  },
                                  tooltip: _isPlaying ? 'Tạm dừng' : 'Phát',
                                  iconSize: 24,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                                  style: TextStyle(
                                    color: Color(0xFF223A5E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (call.missed)
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF223A5E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.phone, color: Colors.white, size: 22),
                    label: Text('Gọi lại',
                        style: TextStyle(
                            fontSize: 16.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onCallBack();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '$m:$s';
  }
}

class EditCallDetailSheet extends StatefulWidget {
  final CallHistoryEntry call;
  const EditCallDetailSheet({Key? key, required this.call}) : super(key: key);

  @override
  State<EditCallDetailSheet> createState() => _EditCallDetailSheetState();
}

class _EditCallDetailSheetState extends State<EditCallDetailSheet> {
  final TextEditingController _tagController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  @override
  void dispose() {
    _tagController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title + Call ID + 3 icon
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chi tiết cuộc gọi',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF223A5E))),
                      const SizedBox(height: 2),
                      Text(
                        "790e1e10-6dee-4443-b1f5-1e76e...", // demo, có thể lấy từ call nếu có
                        style:
                            TextStyle(fontSize: 13.5, color: Color(0xFFB0B8C1)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _SquareIconButton(
                      icon: Icons.person_add_alt,
                      bgColor: Color(0xFF4BC17B),
                      iconColor: Colors.white,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddCustomerPage(
                                initialPhone: widget.call.phoneNumber),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _SquareIconButton(
                      icon: Icons.copy,
                      bgColor: Color(0xFF1A2236),
                      iconColor: Colors.white,
                      onTap: () {
                        Clipboard.setData(ClipboardData(
                            text: "790e1e10-6dee-4443-b1f5-1e76e..."));
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Thành công'),
                            content: Text('Đã sao chép mã cuộc gọi!'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text('OK'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _SquareIconButton(
                      icon: Icons.edit,
                      bgColor: Color(0xFFF5F7FA),
                      iconColor: Color(0xFF223A5E),
                      onTap: () {
                        // Có thể để trống hoặc show thông báo
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Thông tin người gọi
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Color(0xFFE3F0FA),
                  child: Icon(Icons.person, color: Color(0xFF6B7A8F), size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Không xác định',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16.5,
                              color: Color(0xFF223A5E))),
                      const SizedBox(height: 2),
                      Text(widget.call.phoneNumber,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Color(0xFF223A5E))),
                    ],
                  ),
                ),
                Text(
                  '${widget.call.dateTime.hour.toString().padLeft(2, '0')}:${widget.call.dateTime.minute.toString().padLeft(2, '0')} '
                  '${widget.call.dateTime.day.toString().padLeft(2, '0')}/${widget.call.dateTime.month.toString().padLeft(2, '0')}/${widget.call.dateTime.year}',
                  style: TextStyle(
                      color: Color(0xFFB0B8C1),
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  widget.call.missed ? Icons.call_missed : Icons.call_made,
                  color: widget.call.missed
                      ? Color(0xFFF15B5B)
                      : Color(0xFF4BC17B),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.call.missed
                      ? 'Cuộc gọi đi / Không trả lời'
                      : 'Cuộc gọi đi / Trả lời',
                  style: TextStyle(
                    color: widget.call.missed
                        ? Color(0xFFF15B5B)
                        : Color(0xFF4BC17B),
                    fontWeight: FontWeight.w600,
                    fontSize: 15.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Tag',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _tagController,
                decoration:
                    InputDecoration.collapsed(hintText: 'Chưa có dữ liệu'),
              ),
            ),
            const SizedBox(height: 14),
            Text('Mô tả',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration.collapsed(hintText: 'Nhập mô tả'),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4BC17B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: Text('Cập nhật',
                    style: TextStyle(
                        fontSize: 16.5,
                        color: Colors.white,
                        fontWeight: FontWeight.w600)),
                onPressed: () {
                  // TODO: Xử lý cập nhật dữ liệu ở đây
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Widget icon tròn cho header
class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;
  const _SquareIconButton(
      {required this.icon,
      required this.bgColor,
      required this.iconColor,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}

Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Text(
      title,
      style: TextStyle(
        color: Color(0xFF223A5E),
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  );
}

class FilterSheet extends StatelessWidget {
  const FilterSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: SafeArea(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: Color(0xFF223A5E)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Bộ lọc',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF223A5E),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              Divider(height: 1, thickness: 1, color: Color(0xFFF0F1F3)),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      _FilterTile(
                          title: 'Danh sách đầu số',
                          subtitle: 'Chưa có dữ liệu'),
                      _FilterTile(
                          title: 'Loại cuộc gọi', subtitle: 'Chưa có dữ liệu'),
                      _FilterTile(title: 'Ngày tạo', subtitle: 'Chọn ngày'),
                      _FilterTile(
                          title: 'Trạng thái', subtitle: 'Chưa có dữ liệu'),
                      _FilterTile(
                          title: 'Nhân viên phụ trách',
                          subtitle: 'Chưa có dữ liệu'),
                      _FilterTile(title: 'Tag', subtitle: 'Chưa có dữ liệu'),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF223A5E),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: Text('Áp dụng',
                        style: TextStyle(
                            fontSize: 16.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  final String title;
  final String subtitle;
  const _FilterTile({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: Color(0xFF223A5E))),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 14.5,
                    color: Color(0xFFB0B8C1),
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
