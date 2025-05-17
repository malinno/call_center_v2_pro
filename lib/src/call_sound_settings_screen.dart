import 'package:flutter/material.dart';

class CallSoundSettingsScreen extends StatefulWidget {
  const CallSoundSettingsScreen({Key? key}) : super(key: key);

  @override
  State<CallSoundSettingsScreen> createState() =>
      _CallSoundSettingsScreenState();
}

class _CallSoundSettingsScreenState extends State<CallSoundSettingsScreen> {
  String startSound = 'Mặc định';
  String endSound = 'Mặc định';

  final List<String> soundOptions = [
    'Không áp dụng',
    'Mặc định',
    'Âm báo 1',
    'Âm báo 2',
    'Âm báo 3',
  ];

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
          'Âm báo cuộc gọi',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownSection(
              label: 'Âm báo khi bắt đầu cuộc gọi',
              value: startSound,
              onChanged: (v) => setState(() => startSound = v!),
            ),
            SizedBox(height: 16),
            _buildDropdownSection(
              label: 'Âm báo khi kết thúc cuộc gọi',
              value: endSound,
              onChanged: (v) => setState(() => endSound = v!),
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Lưu lại cấu hình âm báo
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4BC17B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Lưu lại',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSection({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFFF7F9FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: value,
            items: soundOptions
                .map((option) => DropdownMenuItem(
                      value: option,
                      child: Row(
                        children: [
                          Icon(Icons.play_circle_fill,
                              color: Color(0xFF223A5E)),
                          SizedBox(width: 8),
                          Text(option, style: TextStyle(fontSize: 15)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            icon: Icon(Icons.arrow_drop_down, color: Colors.black),
            dropdownColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
