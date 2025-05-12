import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'dialpad.dart';
import 'register.dart';
import 'call_history.dart';
import 'account.dart'; 

class MainTabs extends StatefulWidget {
  final SIPUAHelper helper;
  const MainTabs(this.helper, {Key? key}) : super(key: key);

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> implements SipUaHelperListener {
  int _currentIndex = 0; 
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    widget.helper.addSipUaHelperListener(this);
    _isRegistered = widget.helper.registerState.state == RegistrationStateEnum.REGISTERED;
    print('MainTabs initState - Current registration state: ${widget.helper.registerState.state}');
  }

  @override
  void dispose() {
    print('MainTabs dispose - Current registration state: ${widget.helper.registerState.state}');
    widget.helper.removeSipUaHelperListener(this);
    super.dispose();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    print('MainTabs - Registration State Changed: ${state.state}');
    setState(() {
      _isRegistered = state.state == RegistrationStateEnum.REGISTERED;
    });
    
    if (state.state == RegistrationStateEnum.REGISTRATION_FAILED) {
      print('MainTabs - Registration failed, attempting to re-register...');
      // Thử đăng ký lại
      widget.helper.register();
    } else if (state.state == RegistrationStateEnum.UNREGISTERED) {
      print('MainTabs - Unregistered, attempting to re-register...');
      // Thử đăng ký lại
      widget.helper.register();
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    print('MainTabs - Transport State Changed: ${state.state}');
    if (state.state == TransportStateEnum.CONNECTED) {
      print('MainTabs - Transport connected, attempting to register...');
      widget.helper.register();
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    // Không xử lý gì ở đây, để DialPadWidget xử lý
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}

  @override
  Widget build(BuildContext context) {
    final screens = [
      DialPadWidget(helper: widget.helper),     
      CallHistoryWidget(),              
      AccountWidget(),
    ];

    return WillPopScope(
      onWillPop: () async {
        // Ngăn không cho back về màn hình đăng nhập
        return false;
      },
      child: Scaffold(
        body: screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.black,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.white70,
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            // Kiểm tra và đăng ký lại nếu cần
            if (!_isRegistered) {
              print('MainTabs - Tab changed, attempting to re-register...');
              widget.helper.register();
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dialpad),
              label: 'Bàn phím',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Lịch sử cuộc gọi',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }
}