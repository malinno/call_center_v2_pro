import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'models/zsolution_user.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool isDisconnected = false;
  String? disconnectedUntilText;
  DateTime? reconnectTime;
  late BuildContext rootContext;

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _checkAutoReconnect();
  }

  Future<void> _loadAccount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
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
      // Đọc trạng thái ngắt kết nối từ SharedPreferences
      isDisconnected = prefs.getBool('isDisconnected') ?? false;
      disconnectedUntilText = prefs.getString('disconnectedUntilText');
      final reconnectMillis = prefs.getInt('reconnectTimeMillis');
      if (reconnectMillis != null) {
        reconnectTime = DateTime.fromMillisecondsSinceEpoch(reconnectMillis);
      } else {
        reconnectTime = null;
      }
    });
    _checkAutoReconnect();
  }

  void _checkAutoReconnect() {
    if (isDisconnected && reconnectTime != null) {
      final now = DateTime.now();
      if (now.isAfter(reconnectTime!)) {
        // Đã hết thời gian, tự động bật lại kết nối
        _autoReconnect();
      } else {
        // Đặt timer để tự động bật lại khi đến thời điểm
        final duration = reconnectTime!.difference(now);
        Future.delayed(duration, () {
          if (mounted) _autoReconnect();
        });
      }
    }
  }

  void _autoReconnect() async {
    setState(() {
      isDisconnected = false;
      disconnectedUntilText = null;
      reconnectTime = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDisconnected', false);
    await prefs.remove('disconnectedUntilText');
    await prefs.remove('reconnectTimeMillis');
    // Đăng ký lại SIP
    if (widget.helper != null && _zsolutionUser != null) {
      final settings = UaSettings();
      settings.webSocketUrl = 'wss://${_zsolutionUser!.host}:8089/ws';
      settings.uri = 'sip:${_zsolutionUser!.extension}@${_zsolutionUser!.host}';
      settings.authorizationUser = _zsolutionUser!.extension;
      settings.password = _zsolutionUser!.pass;
      settings.displayName = _zsolutionUser!.extension;
      settings.userAgent = 'ZSolutionSoftphone';
      settings.transportType = TransportType.WS;
      settings.register = true;
      settings.register_expires = 300;
      try {
        await widget.helper?.start(settings);
      } catch (e) {
        print('Error starting SIP: $e');
      }
    }
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
          if (widget.helper!.registerState.state ==
              RegistrationStateEnum.REGISTERED) {
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

  void _showDisconnectOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Trong 1 giờ'),
              onTap: () {
                _setDisconnected(Duration(hours: 1));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Trong 6 giờ'),
              onTap: () {
                _setDisconnected(Duration(hours: 6));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Trong 12 giờ'),
              onTap: () {
                _setDisconnected(Duration(hours: 12));
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text('Tuỳ chỉnh'),
              onTap: () {
                Navigator.pop(context);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _showCustomDateTimeDialog(rootContext);
                });
              },
            ),
            ListTile(
              title: Text('Cho đến khi mở lại'),
              onTap: () {
                _setDisconnected(null); // null = cho đến khi mở lại
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  void _setDisconnected(Duration? duration) async {
    setState(() {
      isDisconnected = true;
      if (duration != null) {
        reconnectTime = DateTime.now().add(duration);
        disconnectedUntilText =
            'Tổng đài sẽ được tự động kết nối lại vào lúc \'${_formatTime(reconnectTime!)}\'';
      } else {
        reconnectTime = null;
        disconnectedUntilText =
            'Tổng đài sẽ được tự động kết nối lại khi bạn mở lại';
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDisconnected', true);
    await prefs.setString('disconnectedUntilText', disconnectedUntilText ?? '');
    if (reconnectTime != null) {
      await prefs.setInt(
          'reconnectTimeMillis', reconnectTime!.millisecondsSinceEpoch);
    } else {
      await prefs.remove('reconnectTimeMillis');
    }
    // Hủy đăng ký SIP
    if (widget.helper != null) {
      try {
        if (widget.helper!.registerState.state ==
            RegistrationStateEnum.REGISTERED) {
          widget.helper!.unregister();
        }
        widget.helper!.stop();
      } catch (e) {
        print('Error stopping SIP: $e');
      }
    }
    _checkAutoReconnect();
  }

  String _formatTime(DateTime time) {
    // Định dạng lại giờ phút ngày tháng theo ý bạn
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} ${time.day}/${time.month}/${time.year}';
  }

  // Thêm hàm tiện ích lấy số ngày trong tháng
  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  void _showCustomDateTimeDialog(BuildContext context) {
    DateTime now = DateTime.now();
    DateTime selectedDate = now;
    int selectedHour = now.hour;
    int selectedMinute = now.minute;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: StatefulBuilder(
                      builder: (context, setModalState) {
                        // Header tháng/năm và mũi tên
                        void changeMonth(int delta) {
                          int newYear = selectedDate.year;
                          int newMonth = selectedDate.month + delta;
                          int minMonth = now.month;
                          int minYear = now.year;
                          // Không cho lùi về trước tháng hiện tại
                          if (newYear < minYear ||
                              (newYear == minYear && newMonth < minMonth)) {
                            return;
                          }
                          while (newMonth < 1) {
                            newMonth += 12;
                            newYear -= 1;
                          }
                          while (newMonth > 12) {
                            newMonth -= 12;
                            newYear += 1;
                          }
                          int lastDay = _daysInMonth(newYear, newMonth);
                          int newDay = selectedDate.day > lastDay
                              ? lastDay
                              : selectedDate.day;
                          setModalState(() {
                            selectedDate = DateTime(newYear, newMonth, newDay);
                          });
                        }

                        // Tạo danh sách ngày trong tháng
                        int daysInMonth =
                            _daysInMonth(selectedDate.year, selectedDate.month);
                        int firstWeekday =
                            DateTime(selectedDate.year, selectedDate.month, 1)
                                .weekday;
                        // Flutter: 1=Monday, 7=Sunday. Ta muốn CN đầu tiên, nên chuyển về 0=Sunday
                        int startOffset = (firstWeekday % 7);
                        List<Widget> dayWidgets = [];
                        // Thêm các ô trống đầu tháng
                        for (int i = 0; i < startOffset; i++) {
                          dayWidgets.add(Container());
                        }
                        // Thêm các ngày trong tháng
                        for (int day = 1; day <= daysInMonth; day++) {
                          DateTime thisDay = DateTime(
                              selectedDate.year, selectedDate.month, day);
                          bool isSelected = selectedDate.day == day &&
                              selectedDate.month == thisDay.month &&
                              selectedDate.year == thisDay.year;
                          bool isToday = now.day == day &&
                              now.month == selectedDate.month &&
                              now.year == selectedDate.year;
                          bool isPast = thisDay
                              .isBefore(DateTime(now.year, now.month, now.day));
                          dayWidgets.add(
                            GestureDetector(
                              onTap: isPast
                                  ? null
                                  : () {
                                      setModalState(() {
                                        selectedDate = DateTime(
                                            selectedDate.year,
                                            selectedDate.month,
                                            day,
                                            selectedHour,
                                            selectedMinute);
                                      });
                                    },
                              child: Container(
                                margin: EdgeInsets.all(2),
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(0xFF223A5E)
                                      : isToday
                                          ? Color(0xFFB0B8C1)
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  day.toString(),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : isPast
                                            ? Color(0xFFB0B8C1)
                                            : Color(0xFF223A5E),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header tháng/năm và mũi tên
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12, top: 16, bottom: 16),
                                  child: Opacity(
                                    opacity: (selectedDate.year > now.year ||
                                            selectedDate.month > now.month)
                                        ? 1.0
                                        : 0.3,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: (selectedDate.year > now.year ||
                                              selectedDate.month > now.month)
                                          ? () => changeMonth(-1)
                                          : null,
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Color(0xFFF2F3F7),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(Icons.arrow_back_ios_new,
                                            color: Color(0xFF223A5E), size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    'Tháng ${selectedDate.month} / ${selectedDate.year}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Color(0xFF223A5E),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                      right: 12, top: 16, bottom: 16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => changeMonth(1),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF2F3F7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.arrow_forward_ios,
                                          color: Color(0xFF223A5E), size: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Tên các thứ trong tuần
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (var d in [
                                    'CN',
                                    'T2',
                                    'T3',
                                    'T4',
                                    'T5',
                                    'T6',
                                    'T7'
                                  ])
                                    Expanded(
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: TextStyle(
                                            color: Color(0xFF223A5E),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Lưới ngày
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: GridView.count(
                                crossAxisCount: 7,
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                children: dayWidgets,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('Giờ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF223A5E))),
                            SizedBox(
                              height: 80,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Spinner giờ
                                  SizedBox(
                                    width: 60,
                                    child: CupertinoPicker(
                                      scrollController:
                                          FixedExtentScrollController(
                                              initialItem: selectedHour),
                                      itemExtent: 32,
                                      onSelectedItemChanged: (val) {
                                        setModalState(() {
                                          selectedHour = val;
                                        });
                                      },
                                      children: List.generate(
                                          24,
                                          (i) => Center(
                                              child: Text(
                                                  i.toString().padLeft(2, '0'),
                                                  style: TextStyle(
                                                      fontSize: 18)))),
                                    ),
                                  ),
                                  Text(':',
                                      style: TextStyle(
                                          fontSize: 22,
                                          color: Color(0xFF223A5E))),
                                  // Spinner phút
                                  SizedBox(
                                    width: 60,
                                    child: CupertinoPicker(
                                      scrollController:
                                          FixedExtentScrollController(
                                              initialItem: selectedMinute),
                                      itemExtent: 32,
                                      onSelectedItemChanged: (val) {
                                        setModalState(() {
                                          selectedMinute = val;
                                        });
                                      },
                                      children: List.generate(
                                          60,
                                          (i) => Center(
                                              child: Text(
                                                  i.toString().padLeft(2, '0'),
                                                  style: TextStyle(
                                                      fontSize: 18)))),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: selectedDate.isAfter(now)
                                        ? Color(0xFF223A5E)
                                        : Color(0xFFB0B8C1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  onPressed: selectedDate.isAfter(now)
                                      ? () {
                                          DateTime picked = DateTime(
                                            selectedDate.year,
                                            selectedDate.month,
                                            selectedDate.day,
                                            selectedHour,
                                            selectedMinute,
                                          );
                                          if (picked.isAfter(now)) {
                                            Duration duration =
                                                picked.difference(now);
                                            Navigator.pop(context);
                                            _setDisconnected(duration);
                                          }
                                        }
                                      : null,
                                  child: Text('Áp dụng',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFFF7F9FB))),
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    rootContext = context;
    final userName = _isZSolutionLogin && _zsolutionUser != null
        ? _zsolutionUser!.userName
        : _username ?? '';
    final email = _isZSolutionLogin && _zsolutionUser != null
        ? _zsolutionUser!.email
        : '';
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
                          child: Icon(Icons.person,
                              color: Color(0xFF6B7A8F), size: 36),
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
                        GestureDetector(
                          onTap: isDisconnected
                              ? () async {
                                  setState(() {
                                    isDisconnected = false;
                                    disconnectedUntilText = null;
                                  });
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setBool('isDisconnected', false);
                                  await prefs.remove('disconnectedUntilText');
                                  await prefs.remove('reconnectTimeMillis');
                                  // Đăng ký lại SIP
                                  if (widget.helper != null &&
                                      _zsolutionUser != null) {
                                    final settings = UaSettings();
                                    settings.webSocketUrl =
                                        'wss://${_zsolutionUser!.host}:8089/ws';
                                    settings.uri =
                                        'sip:${_zsolutionUser!.extension}@${_zsolutionUser!.host}';
                                    settings.authorizationUser =
                                        _zsolutionUser!.extension;
                                    settings.password = _zsolutionUser!.pass;
                                    settings.displayName =
                                        _zsolutionUser!.extension;
                                    settings.userAgent = 'ZSolutionSoftphone';
                                    settings.transportType = TransportType.WS;
                                    settings.register = true;
                                    settings.register_expires = 300;
                                    try {
                                      await widget.helper?.start(settings);
                                    } catch (e) {
                                      print('Error starting SIP: $e');
                                    }
                                  }
                                }
                              : null,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDisconnected
                                  ? Color(0xFFF2F3F7)
                                  : Color(0xFF4BC17B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Trực tuyến',
                              style: TextStyle(
                                color: isDisconnected
                                    ? Color(0xFFB0B8C1)
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showDisconnectOptions(context),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDisconnected
                                  ? Color(0xFFF15B5B)
                                  : Color(0xFFF2F3F7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Ngắt kết nối tổng đài',
                              style: TextStyle(
                                color: isDisconnected
                                    ? Colors.white
                                    : Color(0xFF6B7A8F),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isDisconnected && disconnectedUntilText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          disconnectedUntilText!,
                          style: TextStyle(
                            color: Color(0xFF2196F3),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            // Danh sách chức năng
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                children: [
                  _buildMenuItem(
                      Icons.person, 'Thông tin cá nhân', 'Thông tin cá nhân'),
                  _buildMenuItem(
                      Icons.support_agent, 'Tổng đài', 'Kết nối tổng đài',
                      iconColor: Color(0xFF4BC17B),
                      statusColor: Color(0xFF4BC17B)),
                  _buildMenuItem(Icons.lock, 'Đổi mật khẩu',
                      'Cập nhật lại mật khẩu hiện tại',
                      iconColor: Color(0xFFB0B8C1)),
                  _buildMenuItem(
                      Icons.settings, 'Cấu hình', 'Cấu hình thông báo',
                      iconColor: Color(0xFF6B7A8F)),
                  _buildMenuItem(Icons.phone_android, 'Quyền thiết bị',
                      'Vui lòng cung cấp đủ các quyền cần thiết',
                      iconColor: Color(0xFF6B7A8F)),
                  _buildMenuItem(Icons.support, 'Yêu cầu hỗ trợ',
                      'Tạo phiếu yêu cầu hỗ trợ qua Biểu mẫu',
                      iconColor: Color(0xFF6B7A8F)),
                  _buildMenuItem(Icons.privacy_tip, 'Chính sách bảo mật', '',
                      iconColor: Color(0xFF6B7A8F)),
                  SizedBox(height: 16),
                  // Nút đăng xuất
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          child: Icon(Icons.logout, color: Color(0xFFF15B5B)),
                        ),
                        title: Text('Đăng xuất',
                            style: TextStyle(
                              color: Color(0xFFF15B5B),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            )),
                        onTap: _logout,
                        trailing: null,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Phiên bản 1.0.1',
                      style: TextStyle(
                          color: Color(0xFFB0B8C1),
                          fontWeight: FontWeight.w500),
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

  Widget _buildMenuItem(IconData icon, String title, String subtitle,
      {Color iconColor = const Color(0xFF6B7A8F), Color? statusColor}) {
    // Custom cho mục Tổng đài
    if (title == 'Tổng đài') {
      final bool disconnected = isDisconnected;
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
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Color(0xFFF2F3F7),
                  child: Icon(icon, color: iconColor),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color:
                          disconnected ? Color(0xFFF15B5B) : Color(0xFF4BC17B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            title: Text(title,
                style: TextStyle(
                    color: Color(0xFF222B45), fontWeight: FontWeight.w600)),
            subtitle: Text(
              disconnected ? 'Ngắt kết nối tổng đài' : 'Kết nối tổng đài',
              style: TextStyle(
                color: disconnected ? Color(0xFFF15B5B) : Color(0xFF4BC17B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                color: Color(0xFFB0B8C1), size: 18),
            onTap: () {
              Navigator.pushNamed(context, '/call_center_info');
            },
          ),
        ),
      );
    }
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
          title: Text(title,
              style: TextStyle(
                  color: Color(0xFF222B45), fontWeight: FontWeight.w600)),
          subtitle: subtitle.isNotEmpty
              ? Text(subtitle,
                  style: TextStyle(color: Color(0xFFB0B8C1), fontSize: 13))
              : null,
          trailing:
              Icon(Icons.arrow_forward_ios, color: Color(0xFFB0B8C1), size: 18),
          onTap: () async {
            if (title == 'Tổng đài') {
              Navigator.pushNamed(context, '/call_center_info');
            } else if (title == 'Đổi mật khẩu') {
              Navigator.pushNamed(context, '/change_password');
            } else if (title == 'Quyền thiết bị') {
              Navigator.pushNamed(context, '/device_permission');
            } else if (title == 'Cấu hình') {
              Navigator.pushNamed(context, '/notification_settings');
            } else if (title == 'Chính sách bảo mật') {
              final url =
                  Uri.parse('https://zsolution.vn/tin-tuc/chinh-sach-bao-mat');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                // Có thể thử mở bằng launchUrl(url); (không truyền mode)
                await launchUrl(url);
              }
            } else if (title == 'Thông tin cá nhân') {
              Navigator.pushNamed(context, '/personal_info');
            }
          },
        ),
      ),
    );
  }
}
