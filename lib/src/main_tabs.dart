import 'package:flutter/material.dart';
import 'package:sip_ua/sip_ua.dart';
import 'dialpad.dart';
import 'call_history.dart';
import 'contact.dart';
import 'note.dart';
import 'multi_channel.dart';
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
    
  }

  @override
  void dispose() {
    widget.helper.removeSipUaHelperListener(this);
    super.dispose();
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    setState(() {
      _isRegistered = state.state == RegistrationStateEnum.REGISTERED;
    });
    if (state.state == RegistrationStateEnum.REGISTRATION_FAILED ||
        state.state == RegistrationStateEnum.UNREGISTERED) {
      widget.helper.register();
    }
  }

  @override
  void transportStateChanged(TransportState state) {
    if (state.state == TransportStateEnum.CONNECTED) {
      widget.helper.register();
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {}

  @override
  void onNewNotify(Notify ntf) {}

  @override
  void onNewReinvite(ReInvite event) {}

  final List<_TabItem> _tabs = const [
    _TabItem(icon: Icons.smart_toy, label: 'Lịch sử'),
    _TabItem(icon: Icons.person, label: 'Danh bạ'),
    _TabItem(icon: Icons.sticky_note_2, label: 'Phiếu ghi'),
    _TabItem(icon: Icons.account_circle, label: 'Tài khoản'),
  ];

  bool get _isKeyboardOpen => MediaQuery.of(context).viewInsets.bottom > 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      CallHistoryWidget(helper: widget.helper),
      ContactWidget(),
      NoteWidget(),
      AccountWidget(helper: widget.helper),
    ];

    return WillPopScope(
      
      onWillPop: () async => false,
      child: Scaffold(
        extendBody:true,
        body: screens[_currentIndex],
        backgroundColor: Colors.white,
       
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _isKeyboardOpen
            ? null
            : FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DialPadWidget(helper: widget.helper),
                    ),
                  );
                },
                child: const Icon(Icons.call, color: Colors.white, size: 32),
                shape: CircleBorder(),
                backgroundColor: Color(0xFF1DA1F2),
                elevation: 10,
              ),
        bottomNavigationBar: BottomAppBar(
          
          elevation: 18,
          color: Colors.white,
           shape:const CircularNotchedRectangle(),
           notchMargin: 5,
          child: SizedBox(
            height: 76,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length + 1, (index) {
                if (index == 2) {
                  // Chỗ trống cho FAB
                  return SizedBox(width: 40);
                }
                int tabIdx = index > 2 ? index - 1 : index;
                final selected = _currentIndex == tabIdx;
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _currentIndex = tabIdx);
                      if (!_isRegistered) widget.helper.register();
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _tabs[tabIdx].icon,
                          color: selected ? Color(0xFF223A5E) : Color(0xFFB0B8C1),
                          size: 28,
                        ),
                        SizedBox(height: 4),
                        Text(
                          _tabs[tabIdx].label,
                          style: TextStyle(
                            color: selected ? Color(0xFF223A5E) : Color(0xFFB0B8C1),
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem({required this.icon, required this.label});
}

class BigCircularNotchedRectangle extends NotchedShape {
  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !guest.overlaps(host)) {
      return Path()..addRect(host);
    }
    final notchRadius = guest.width / 2.0 + 8;
    final notchCenter = guest.center.dx;
    final notchBottom = guest.top + guest.height / 2.2;
    final path = Path();
    path.moveTo(host.left, host.top);
    path.lineTo(notchCenter - notchRadius, host.top);
    path.arcToPoint(
      Offset(notchCenter + notchRadius, host.top),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );
    path.lineTo(host.right, host.top);
    path.lineTo(host.right, host.bottom);
    path.lineTo(host.left, host.bottom);
    path.close();
    return path;
  }
}