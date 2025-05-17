import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';

class DevicePermissionScreen extends StatelessWidget {
  const DevicePermissionScreen({Key? key}) : super(key: key);

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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vui lòng cung cấp đủ các quyền cần thiết',
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  AppSettings.openAppSettings();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1A2746),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Kiểm tra',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFF7F9FB),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
