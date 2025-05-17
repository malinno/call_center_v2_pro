import 'package:flutter/material.dart';

class CallCenterInfoScreen extends StatefulWidget {
  final String protocol;
  final String extensionNumber;
  final String domain;
  final String password;
  final String outboundProxy;

  const CallCenterInfoScreen({
    Key? key,
    this.protocol = 'Tự động',
    this.extensionNumber = '100',
    this.domain = 'na160',
    this.password = '********',
    this.outboundProxy = 'vh.omicrm.com',
  }) : super(key: key);

  @override
  State<CallCenterInfoScreen> createState() => _CallCenterInfoScreenState();
}

class _CallCenterInfoScreenState extends State<CallCenterInfoScreen> {
  late String _selectedProtocol;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _selectedProtocol = widget.protocol;
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
          'Thông tin tổng đài',
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
            Text('Giao thức kết nối',
                style: TextStyle(fontSize: 15, color: Colors.grey[700])),
            SizedBox(height: 8),
            Row(
              children: [
                _buildRadio(context, 'Tự động'),
                SizedBox(width: 16),
                _buildRadio(context, 'TCP'),
                SizedBox(width: 16),
                _buildRadio(context, 'UDP'),
              ],
            ),
            SizedBox(height: 18),
            _buildTextField('Số nội bộ', widget.extensionNumber),
            SizedBox(height: 8),
            _buildTextField('Domain', widget.domain),
            SizedBox(height: 8),
            _buildTextField('Mật khẩu', widget.password, isPassword: true),
            SizedBox(height: 8),
            _buildTextField('Outbound proxy', widget.outboundProxy),
          ],
        ),
      ),
    );
  }

  Widget _buildRadio(BuildContext context, String label) {
    final bool selected = _selectedProtocol == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProtocol = label;
        });
      },
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? Color(0xFF0099FF) : Colors.grey, width: 2),
              color: selected ? Color(0xFF0099FF) : Colors.white,
            ),
            child: selected
                ? Center(
                    child: Icon(Icons.check, size: 16, color: Colors.white))
                : null,
          ),
          SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 15,
                  color: selected ? Color(0xFF0099FF) : Colors.black)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String value,
      {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[700])),
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Color(0xFFF7F9FB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isPassword && _obscurePassword ? '********' : value,
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
              if (isPassword)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  child: Icon(
                    _obscurePassword
                        ? Icons.remove_red_eye_outlined
                        : Icons.visibility_off_outlined,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
