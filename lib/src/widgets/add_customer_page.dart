import 'package:flutter/material.dart';

class AddCustomerPage extends StatefulWidget {
  final String? initialPhone;
  const AddCustomerPage({Key? key, this.initialPhone}) : super(key: key);

  @override
  State<AddCustomerPage> createState() => _AddCustomerPageState();
}

class _AddCustomerPageState extends State<AddCustomerPage> {
  int _gender = 0; // 0: Nam, 1: Nữ, 2: Khác
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneController.text = widget.initialPhone!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF223A5E)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Thêm khách hàng', style: TextStyle(color: Color(0xFF223A5E), fontWeight: FontWeight.bold, fontSize: 20)),
        centerTitle: true,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Giới tính', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF223A5E))),
            const SizedBox(height: 8),
            Row(
              children: [
                _RadioGender(
                  value: 0,
                  groupValue: _gender,
                  label: 'Nam',
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(width: 12),
                _RadioGender(
                  value: 1,
                  groupValue: _gender,
                  label: 'Nữ',
                  onChanged: (v) => setState(() => _gender = v!),
                ),
                const SizedBox(width: 12),
                _RadioGender(
                  value: 2,
                  groupValue: _gender,
                  label: 'Khác',
                  onChanged: (v) => setState(() => _gender = v!),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _InputBox(
              controller: _nameController,
              label: 'Tên đầy đủ',
              hint: 'Tối đa 256 ký tự',
              icon: null,
              required: false,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InputBox(
                    controller: _phoneController,
                    label: 'Số điện thoại',
                    hint: '',
                    icon: null,
                    required: true,
                  ),
                ),
                const SizedBox(width: 8),
                _DashedIconButton(
                  icon: Icons.add,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _InputBox(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'email@example.com',
                    icon: null,
                    required: false,
                  ),
                ),
                const SizedBox(width: 8),
                _DashedIconButton(
                  icon: Icons.add,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Nhân viên phụ trách', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: Color(0xFF223A5E))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFFE3F0FA),
                    child: Icon(Icons.person, color: Color(0xFF6B7A8F), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('(Tôi) CÔNG TY CỔ PHẦN Z SOLUTION', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF223A5E))),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF223A5E)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text('Ghi chú', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: Color(0xFF223A5E))),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _noteController,
                maxLines: 4,
                style: TextStyle(fontSize: 15, color: Color(0xFF223A5E)),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Nhập mô tả',
                  hintStyle: TextStyle(color: Color(0xFFB0B8C1)),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4BC17B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                onPressed: () {},
                child: Text('Lưu lại', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _RadioGender extends StatelessWidget {
  final int value;
  final int groupValue;
  final String label;
  final ValueChanged<int?> onChanged;
  const _RadioGender({required this.value, required this.groupValue, required this.label, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Radio<int>(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          activeColor: Color(0xFF1DA1F2),
        ),
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF223A5E))),
      ],
    );
  }
}

class _InputBox extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? icon;
  final bool required;
  const _InputBox({required this.controller, required this.label, required this.hint, this.icon, this.required = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: Color(0xFF223A5E))),
            if (required) ...[
              const SizedBox(width: 2),
              Text('*', style: TextStyle(color: Color(0xFFF15B5B), fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: controller,
            style: TextStyle(fontSize: 15, color: Color(0xFF223A5E)),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: Color(0xFFB0B8C1)),
              suffixIcon: icon != null ? Icon(icon, color: Color(0xFFB0B8C1)) : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _DashedIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: Color(0xFFB0B8C1), style: BorderStyle.solid, width: 1),
          borderRadius: BorderRadius.circular(8),
          color: Colors.transparent,
        ),
        child: Center(
          child: Icon(icon, color: Color(0xFF223A5E), size: 22),
        ),
      ),
    );
  }
} 