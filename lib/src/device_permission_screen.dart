import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';

class DevicePermissionScreen extends StatefulWidget {
  const DevicePermissionScreen({Key? key}) : super(key: key);

  @override
  State<DevicePermissionScreen> createState() => _DevicePermissionScreenState();
}

class _DevicePermissionScreenState extends State<DevicePermissionScreen> {
  Map<Permission, PermissionStatus> _permissionStatuses = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isLoading = true);
    
    final permissions = [
      Permission.microphone,
      Permission.contacts,
      Permission.camera,
      Permission.notification,
    ];

    Map<Permission, PermissionStatus> statuses = {};
    for (var permission in permissions) {
      statuses[permission] = await permission.status;
    }

    setState(() {
      _permissionStatuses = statuses;
      _isLoading = false;
    });
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    setState(() {
      _permissionStatuses[permission] = status;
    });
  }

  String _getPermissionName(Permission permission) {
    if (permission == Permission.microphone) {
      return 'Microphone';
    } else if (permission == Permission.contacts) {
      return 'Danh bạ';
    } else if (permission == Permission.camera) {
      return 'Camera';
    } else if (permission == Permission.notification) {
      return 'Thông báo';
    }
    return permission.toString();
  }

  String _getPermissionDescription(Permission permission) {
    if (permission == Permission.microphone) {
      return 'Cần quyền truy cập microphone để thực hiện cuộc gọi';
    } else if (permission == Permission.contacts) {
      return 'Cần quyền truy cập danh bạ để hiển thị và gọi điện thoại';
    } else if (permission == Permission.camera) {
      return 'Cần quyền truy cập camera để thực hiện cuộc gọi video';
    } else if (permission == Permission.notification) {
      return 'Cần quyền thông báo để nhận thông báo cuộc gọi đến';
    }
    return '';
  }

  Widget _buildPermissionItem(Permission permission) {
    final status = _permissionStatuses[permission];
    final isGranted = status?.isGranted ?? false;
    final isPermanentlyDenied = status?.isPermanentlyDenied ?? false;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(_getPermissionName(permission)),
        subtitle: Text(_getPermissionDescription(permission)),
        trailing: isGranted
            ? Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                icon: Icon(Icons.settings, color: Colors.blue),
                onPressed: () {
                  if (isPermanentlyDenied) {
                    AppSettings.openAppSettings();
                  } else {
                    _requestPermission(permission);
                  }
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quyền thiết bị',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Vui lòng cấp các quyền cần thiết để ứng dụng hoạt động tốt nhất',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                  ..._permissionStatuses.keys.map(_buildPermissionItem).toList(),
                  SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: _checkPermissions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1A2746),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: Text(
                        'Kiểm tra lại',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
