import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'call_history.dart';

class DialPadWidget extends StatefulWidget {
  final SIPUAHelper helper;
  const DialPadWidget({Key? key, required this.helper}) : super(key: key);
  @override
  _DialPadWidgetState createState() => _DialPadWidgetState();
}

class _DialPadWidgetState extends State<DialPadWidget> implements SipUaHelperListener {
  final TextEditingController _numberController = TextEditingController();
  bool _isRegistered = false;
  bool _isRegistering = false;
  int _selectedOption = 0; // 0: Ưu tiên gọi nội mạng, 1: Random đầu số gọi ra
  List<bool> _optionChecked = [false, false]; // 2 tuỳ chọn, cho phép chọn nhiều
  int _selectedPrefix = 0; // index của đầu số được chọn
  final List<String> _prefixList = ['0996484060', '0387120550'];
  List<bool> _carrierChecked = [false, false, false]; // Viettel, Vinaphone, Mobifone

  // Key definitions
  final List<List<Map<String, String>>> _keys = const [
    [ {'1': ''}, {'2': 'ABC'}, {'3': 'DEF'} ],
    [ {'4': 'GHI'}, {'5': 'JKL'}, {'6': 'MNO'} ],
    [ {'7': 'PQRS'}, {'8': 'TUV'}, {'9': 'WXYZ'} ],
    [ {'*': ''}, {'0': '+'}, {'#': ''} ],
  ];

  @override
  void initState() {
    super.initState();
    widget.helper.addSipUaHelperListener(this);
    _isRegistered = widget.helper.registerState.state == RegistrationStateEnum.REGISTERED;
    print('DialPad initState - Current registration state: ${widget.helper.registerState.state}');
  }

  @override
  void dispose() {
    _numberController.dispose();
    widget.helper.removeSipUaHelperListener(this);
    super.dispose();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    print('DialPad - Registration State Changed: ${state.state}');
    setState(() {
      _isRegistered = state.state == RegistrationStateEnum.REGISTERED;
      _isRegistering = false;
    });
  }

  @override
  void transportStateChanged(TransportState state) {
    print('DialPad - Transport State Changed: ${state.state}');
  }

  @override
  void callStateChanged(Call call, CallState state) async {
    if (state.state == CallStateEnum.CALL_INITIATION) {
      await saveCallHistory(call.remote_identity ?? '');
      if (mounted) {
        await Navigator.pushNamed(
          context,
          '/callscreen',
          arguments: call,
        );
        setState(() => _numberController.clear());
      }
    }
    if (state.state == CallStateEnum.FAILED) {
      await saveCallHistory(call.remote_identity ?? '', missed: true);
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _call() async {
    final number = _numberController.text;
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập số điện thoại')),
      );
      return;
    }

    // Xin quyền microphone
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cần cấp quyền truy cập microphone để thực hiện cuộc gọi')),
      );
      return;
    }

    // Kiểm tra trạng thái đăng ký SIP
    if (widget.helper.registerState.state != RegistrationStateEnum.REGISTERED) {
      try {
        // Đăng ký SIP
        widget.helper.register();
        // Đợi đăng ký thành công
        await Future.delayed(Duration(seconds: 2));
        if (widget.helper.registerState.state != RegistrationStateEnum.REGISTERED) {
          throw Exception('Không thể đăng ký SIP');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể kết nối SIP. Vui lòng thử lại.')),
        );
        return;
      }
    }

    try {
      final call = await widget.helper.call(
        number,
        voiceOnly: true,
        headers: [
          'X-Feature-Level: 1',
          'X-Feature-Code: basic',
        ],
      );
      if (mounted) {
        await Navigator.pushNamed(
          context, 
          '/callscreen',
          arguments: call,
        );
      }
    } catch (e) {
      print('Error calling: $e');
    }
  }

  void _append(String digit) {
    setState(() {
      _numberController.text += digit;
    });
  }

  void _backspace() {
    final text = _numberController.text;
    if (text.isNotEmpty) {
      setState(() {
        _numberController.text = text.substring(0, text.length - 1);
      });
    }
  }

  void _showOptionsSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(
                      'Tuỳ chọn',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45)),
                    ),
                  ),
                  CheckboxListTile(
                    value: _optionChecked[0],
                    onChanged: (val) {
                      setModalState(() => _optionChecked[0] = val!);
                    },
                    shape: CircleBorder(),
                    title: Text('Ưu tiên gọi nội mạng', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text('Hệ thống ưu tiên chọn đầu số theo nhà mạng', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    activeColor: Color(0xFF1DA1F2),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    value: _optionChecked[1],
                    onChanged: (val) {
                      setModalState(() => _optionChecked[1] = val!);
                    },
                    shape: CircleBorder(),
                    title: Text('Random đầu số gọi ra', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    subtitle: Text('Hệ thống chọn ngẫu nhiên đầu số khi gọi đi', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    activeColor: Color(0xFF1DA1F2),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditPrefixSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(top: 16, left: 0, right: 0, bottom: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Danh sách đầu số', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45))),
                          SizedBox(height: 2),
                          Text('${_prefixList.length} giá trị', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFF6F8FC),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.search, color: Color(0xFF222B45)),
                        onPressed: () {},
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              ...List.generate(_prefixList.length, (i) {
                final isSelected = _selectedPrefix == i;
                return Column(
                  children: [
                    RadioListTile<int>(
                      value: i,
                      groupValue: _selectedPrefix,
                      onChanged: (val) {
                        setState(() => _selectedPrefix = val!);
                        Navigator.pop(context);
                      },
                      activeColor: Color(0xFF1DA1F2),
                      title: Row(
                        children: [
                          Text(
                            _prefixList[i],
                            style: TextStyle(
                              color: isSelected ? Color(0xFF1DA1F2) : Color(0xFF222B45),
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(width: 8),
                          Image.asset(
                            'lib/src/assets/images/soly.png',
                            height: 16,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, s) => Icon(Icons.image, color: Colors.grey, size: 16),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(left: 0, top: 2),
                        child: Text('zsolution', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    if (i < _prefixList.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(height: 1, color: Color(0xFFE6EAF0)),
                      ),
                  ],
                );
              }),
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showCarrierSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Text(
                      'Chọn nhà mạng ưu tiên',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF222B45)),
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildCarrierIcon(0, 'Viettel', 'lib/src/assets/images/viettel.png', setModalState),
                      _buildCarrierIcon(1, 'Vinaphone', 'lib/src/assets/images/vinaphone.png', setModalState),
                      _buildCarrierIcon(2, 'Mobifone', 'lib/src/assets/images/mobifone.png', setModalState),
                    ],
                  ),
                  SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCarrierIcon(int idx, String label, String asset, void Function(void Function()) setModalState) {
    final bool checked = _carrierChecked[idx];
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _carrierChecked[idx] = !_carrierChecked[idx];
        });
        setState(() {}); // cập nhật badge ngoài
      },
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: checked ? Color(0xFF1DA1F2).withOpacity(0.12) : Color(0xFFF6F8FC),
              shape: BoxShape.circle,
              border: Border.all(color: checked ? Color(0xFF1DA1F2) : Colors.transparent, width: 2),
            ),
            child: Center(
              child: Image.asset(
                asset,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => Icon(Icons.sim_card, color: Colors.grey, size: 32),
              ),
            ),
          ),
          SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 13, color: checked ? Color(0xFF1DA1F2) : Color(0xFF222B45), fontWeight: checked ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color mainBlue = Color(0xFF223A5E);
    final Color lightBlue = Color(0xFF1DA1F2);
    final Color keyTextColor = Color(0xFF223A5E);
    final Color keyBgColor = Colors.white;
    final Color dialBg = Color(0xFFF7F9FB);
    final Color borderColor = Color(0xFFE6EAF0);
    final String selectedNumber = '0996484060'; // demo, bạn có thể lấy từ state
    return Scaffold(
      backgroundColor: dialBg,
      body: Column(
        children: [
          // Header
          Container(
            color: mainBlue,
            padding: const EdgeInsets.only(top: 0, left: 0, right: 0, bottom: 0),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false, arguments: widget.helper);
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Đầu số đang chọn', style: TextStyle(color: Colors.white70, fontSize: 14)),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_optionChecked[0] && _carrierChecked.contains(true))
                                ...[
                                  if (_carrierChecked[0])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Image.asset(
                                        'lib/src/assets/images/viettel.png',
                                        height: 22,
                                        fit: BoxFit.contain,
                                        errorBuilder: (c, e, s) => Icon(Icons.image, color: Colors.white, size: 22),
                                      ),
                                    ),
                                  if (_carrierChecked[1])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Image.asset(
                                        'lib/src/assets/images/vinaphone.png',
                                        height: 22,
                                        fit: BoxFit.contain,
                                        errorBuilder: (c, e, s) => Icon(Icons.image, color: Colors.white, size: 22),
                                      ),
                                    ),
                                  if (_carrierChecked[2])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Image.asset(
                                        'lib/src/assets/images/mobifone.png',
                                        height: 22,
                                        fit: BoxFit.contain,
                                        errorBuilder: (c, e, s) => Icon(Icons.image, color: Colors.white, size: 22),
                                      ),
                                    ),
                                ]
                              else
                                Text(selectedNumber, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              SizedBox(width: 8),
                              Image.asset(
                                'lib/src/assets/images/soly.png',
                                height: 22,
                                fit: BoxFit.contain,
                                errorBuilder: (c, e, s) => Icon(Icons.image, color: Colors.white, size: 22),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'zsolution',
                                style: TextStyle(
                                  color: Color(0xFF1DA1F2),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // GestureDetector(
                    //   onTap: () {
                    //     showMenu(
                    //       context: context,
                    //       position: RelativeRect.fromLTRB(
                    //         MediaQuery.of(context).size.width,
                    //         kToolbarHeight + 30,
                    //         20,
                    //         0,
                    //       ),
                    //       items: [
                    //         PopupMenuItem(
                    //           value: 'edit',
                    //           child: Text('Chỉnh sửa đầu số'),
                    //         ),
                    //         PopupMenuItem(
                    //           value: 'quick',
                    //           child: Text('Quay số nhanh'),
                    //         ),
                    //       ],
                    //     ).then((value) {
                    //       if (value == 'edit') {
                    //         // TODO: Xử lý chỉnh sửa đầu số
                    //       } else if (value == 'quick') {
                    //         // TODO: Xử lý quay số nhanh
                    //       }
                    //     });
                    //   },
                    //   child: Container(
                    //     margin: EdgeInsets.only(right: 8),
                    //     decoration: BoxDecoration(
                    //       color: Color(0xFF223A5E),
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     width: 44,
                    //     height: 44,
                    //     child: Icon(Icons.edit, color: Colors.white),
                    //   ),
                    // ),
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(Icons.settings, color: keyTextColor, size: 28),
                          onPressed: () {
                            _showOptionsSheet();
                            if (_optionChecked[0]) {
                              Future.delayed(Duration(milliseconds: 350), () {
                                _showCarrierSheet();
                              });
                            }
                          },
                        ),
                        if (_optionChecked.where((e) => e).length > 0)
                          Positioned(
                            right: 6,
                            top: 8,
                            child: Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Center(
                                child: Text(
                                  '${_optionChecked.where((e) => e).length}',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Phần giữa: minh họa + text
          Expanded(
            child: Container(
              color: dialBg,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 24),
                  Icon(Icons.sync, size: 80, color: lightBlue.withOpacity(0.2)), // Thay bằng hình minh họa nếu có
                  SizedBox(height: 16),
                  Text('Chưa có dữ liệu', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            ),
          ),
          // Bàn phím số
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(top: 8, left: 0, right: 0, bottom: 0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _numberController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(fontSize: 22, color: keyTextColor, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Nhập số điện thoại',
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 18),
                            border: InputBorder.none,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFF4CD964), // xanh lá
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(Icons.person_add, color: Colors.white),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                // Keypad
                for (int i = 0; i < _keys.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final keyData in _keys[i])
                          GestureDetector(
                            onTap: () => _append(keyData.keys.first),
                            child: Container(
                              width: 100,
                              height: 56,
                              margin: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(0xFFF6F8FC), // màu nền xám nhạt
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                keyData.keys.first,
                                style: TextStyle(
                                  color: Color(0xFF222B45), // màu đậm
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Nút cài đặt
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(Icons.settings, color: keyTextColor, size: 28),
                          onPressed: () {
                            _showOptionsSheet();
                            // Nếu đã chọn ưu tiên gọi nội mạng thì show chọn nhà mạng
                            if (_optionChecked[0]) {
                              Future.delayed(Duration(milliseconds: 350), () {
                                _showCarrierSheet();
                              });
                            }
                          },
                        ),
                        if (_carrierChecked.where((e) => e).length > 0)
                          Positioned(
                            right: 6,
                            top: 8,
                            child: Container(
                              padding: EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Center(
                                child: Text(
                                  '${_carrierChecked.where((e) => e).length}',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Nút gọi
                    GestureDetector(
                      onTap: _call,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: lightBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: lightBlue.withOpacity(0.18),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.call, color: Colors.white, size: 32),
                      ),
                    ),
                    // Nút xóa
                    IconButton(
                      icon: Icon(Icons.backspace_outlined, color: keyTextColor, size: 28),
                      onPressed: _backspace,
                      onLongPress: () => setState(() => _numberController.clear()),
                    ),
                  ],
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}
  @override
  void onNewNotify(Notify ntf) {}
  @override
  void onNewReinvite(ReInvite event) {}
}
