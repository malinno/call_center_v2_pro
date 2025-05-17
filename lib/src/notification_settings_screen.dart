import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool customer = true;
  bool note = true;
  bool multiChannel = true;
  bool callSound = false;

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
          'Thông báo',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        children: [
          _buildSwitchTile(
            title: 'Khách hàng',
            value: customer,
            onChanged: (v) => setState(() => customer = v),
            description:
                'Các thông báo liên quan đến khách hàng sẽ không được hiển thị trên thanh thông báo của thiết bị khi bạn tắt cấu hình này',
          ),
          Divider(height: 1, thickness: 1, color: Color(0xFFF2F3F7)),
          _buildSwitchTile(
            title: 'Phiếu ghi',
            value: note,
            onChanged: (v) => setState(() => note = v),
            description:
                'Các thông báo liên quan đến phiếu ghi sẽ không được hiển thị trên thanh thông báo của thiết bị khi bạn tắt cấu hình này',
          ),
          Divider(height: 1, thickness: 1, color: Color(0xFFF2F3F7)),
          _buildSwitchTile(
            title: 'Âm báo cuộc gọi',
            value: callSound,
            onChanged: (v) => setState(() => callSound = v),
            description: 'Âm thanh thông báo khi bắt đầu và kết thúc cuộc gọi',
            trailing: Icon(Icons.arrow_forward_ios,
                color: Color(0xFFB0B8C1), size: 18),
            onTap: () {
              Navigator.pushNamed(context, '/call_sound_settings');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String description,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: Color(0xFF2196F3),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Color(0xFF222B45),
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 2, right: 8),
              child: Text(
                description,
                style: TextStyle(
                  color: Color(0xFFB0B8C1),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
