import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactWidget extends StatefulWidget {
  @override
  _ContactWidgetState createState() => _ContactWidgetState();
}

class _ContactWidgetState extends State<ContactWidget> {
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  bool _loading = true;
  String _search = '';
  int _tabIndex = 0;
  final List<String> _tabs = ['OMI', 'Nhân viên', 'Thiết bị'];
  final TextEditingController _searchController = TextEditingController();
  bool _hasPermission = false;
  bool _isRequestingPermission = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _search = _searchController.text.trim().toLowerCase();
      if (_tabIndex == 2) { // Tab Thiết bị
        _filteredContacts = _contacts.where((c) {
          final name = c.displayName.toLowerCase();
          final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
          return name.contains(_search) || phone.contains(_search);
        }).toList();
      }
    });
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    if (_tabIndex == 2) { // Tab Thiết bị
      await _fetchContacts();
    } else {
      // Giả lập dữ liệu cho tab OMI và Nhân viên
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _fetchContacts() async {
    if (_isRequestingPermission) return;
    setState(() => _isRequestingPermission = true);

    try {
      // Kiểm tra quyền trước
      var status = await Permission.contacts.status;
      
      if (status.isDenied) {
        // Nếu chưa có quyền, yêu cầu quyền
        status = await Permission.contacts.request();
      }

      if (status.isGranted) {
        // Nếu có quyền, lấy danh bạ
        final contacts = await FlutterContacts.getContacts(withProperties: true);
        setState(() {
          _contacts = contacts;
          _filteredContacts = contacts;
          _loading = false;
          _hasPermission = true;
          _isRequestingPermission = false;
        });
      } else {
        // Nếu không được cấp quyền
        setState(() {
          _loading = false;
          _hasPermission = false;
          _isRequestingPermission = false;
        });
        
        // Hiển thị dialog hướng dẫn người dùng cấp quyền trong Settings
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Cần quyền truy cập danh bạ'),
              content: Text('Để hiển thị danh bạ, vui lòng cấp quyền trong Cài đặt.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Đóng'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await openAppSettings();
                  },
                  child: Text('Mở Cài đặt'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching contacts: $e');
      setState(() {
        _loading = false;
        _hasPermission = false;
        _isRequestingPermission = false;
      });
    }
  }

  Widget _buildContactList() {
    if (_tabIndex == 2) { // Tab Thiết bị
      if (_loading) {
        return Center(child: CircularProgressIndicator());
      }
      if (!_hasPermission) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contacts, size: 48, color: Color(0xFFB0B8C1)),
              SizedBox(height: 16),
              Text('Ứng dụng cần quyền truy cập danh bạ để hiển thị liên hệ.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF223A5E), fontWeight: FontWeight.w500)),
              SizedBox(height: 18),
              ElevatedButton(
                onPressed: _isRequestingPermission ? null : _fetchContacts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1DA1F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: Text('Cấp quyền truy cập', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        );
      }
      if (_filteredContacts.isEmpty) {
        return Center(child: Text('Không có dữ liệu', style: TextStyle(color: Colors.black54)));
      }
    }

    // Hiển thị danh sách cho tất cả các tab
    return ListView.builder(
      padding: EdgeInsets.only(top: 4),
      itemCount: _tabIndex == 2 ? _filteredContacts.length : 10, // Giả lập 10 items cho OMI và Nhân viên
      itemBuilder: (context, index) {
        if (_tabIndex == 2) {
          final contact = _filteredContacts[index];
          final name = contact.displayName;
          final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
          final avatarColor = _avatarColorFromName(name);
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: avatarColor,
                child: Icon(Icons.person, color: Color(0xFF6B7A8F)),
              ),
              title: Text(name, style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(phone, style: TextStyle(color: Color(0xFF223A5E))),
              trailing: IconButton(
                icon: Icon(Icons.call, color: Color(0xFF1DA1F2)),
                onPressed: () {
                  // TODO: Gọi số điện thoại
                },
              ),
            ),
          );
        } else {
          // Giả lập UI cho tab OMI và Nhân viên
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Color(0xFFE3F0FA),
                child: Icon(Icons.person, color: Color(0xFF6B7A8F)),
              ),
              title: Text('Item ${index + 1}', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Description ${index + 1}', style: TextStyle(color: Color(0xFF223A5E))),
              trailing: IconButton(
                icon: Icon(Icons.call, color: Color(0xFF1DA1F2)),
                onPressed: () {
                  // TODO: Gọi số điện thoại
                },
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                              border: Border.all(color: Color(0xFF00AEEF), width: 1.5),
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
                                    },
                                  ),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Danh bạ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF223A5E))),
                              SizedBox(height: 2),
                              Text(
                                '${_tabIndex == 2 ? _contacts.length : 10} khách hàng',
                                style: TextStyle(fontSize: 13.5, color: Color(0xFFB0B8C1)),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 44,
                    width: 44,
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
                      icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.black87),
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
                    height: 44,
                    width: 44,
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
                      icon: Icon(Icons.tune, color: _tabIndex == 0 ? Colors.black87 : Color(0xFFB0B8C1)),
                      onPressed: _tabIndex == 0 ? () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          builder: (context) => const OmiFilterSheet(),
                        );
                      } : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: List.generate(_tabs.length, (i) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _tabIndex = i;
                        _loadInitialData();
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: i == _tabIndex ? Color(0xFF223A5E) : Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: i == _tabIndex ? Color(0xFF223A5E) : Color(0xFFF5F7FA), width: 1.5),
                      ),
                      child: Text(
                        _tabs[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: i == _tabIndex ? Colors.white : Color(0xFFB0B8C1),
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                  ),
                )),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildContactList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _avatarColorFromName(String name) {
    final colors = [
      Color(0xFFE3F0FA),
      Color(0xFFD2F6E7),
      Color(0xFFFFE5E5),
      Color(0xFFF5F7FA),
      Color(0xFFFFF6E5),
    ];
    return colors[name.hashCode % colors.length];
  }
}

class OmiFilterSheet extends StatelessWidget {
  const OmiFilterSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: Color(0xFF223A5E)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Bộ lọc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF223A5E))),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: Color(0xFF223A5E)),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    _FilterTile(title: 'Bộ lọc của tôi', subtitle: 'Chưa có dữ liệu'),
                    _FilterTile(title: 'Tag', subtitle: 'Chưa có dữ liệu'),
                    _FilterTile(title: 'Nhóm', subtitle: 'Chưa có dữ liệu'),
                    _FilterTile(title: 'Ngành', subtitle: 'Chưa có dữ liệu'),
                    _FilterTile(title: 'Nhân viên phụ trách', subtitle: 'Chưa có dữ liệu', bold: true),
                    _FilterTile(title: 'Ngày tạo', subtitle: 'Ngày bắt đầu'),
                    _FilterTile(title: 'Giới tính', subtitle: 'Chưa có dữ liệu'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF223A5E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text('Áp dụng', style: TextStyle(fontSize: 16.5, color: Colors.white, fontWeight: FontWeight.w600)),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool bold;
  const _FilterTile({required this.title, required this.subtitle, this.bold = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: 15.5, color: Color(0xFF223A5E))),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 14, color: Color(0xFFB0B8C1))),
        ],
      ),
    );
  }
} 