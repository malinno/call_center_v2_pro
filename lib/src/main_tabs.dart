import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'dialpad.dart';
import 'register.dart';
import 'call_history.dart';
import 'account.dart'; 

class MainTabs extends StatefulWidget {
  final SIPUAHelper? helper;
  const MainTabs(this.helper, {Key? key}) : super(key: key);

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _currentIndex = 0; 

  @override
  Widget build(BuildContext context) {
    final screens = [
      DialPadWidget(helper: widget.helper),     
      CallHistoryWidget(),              
      AccountWidget(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.white70,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
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
    );
  }
}