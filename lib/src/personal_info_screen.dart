import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/zsolution_user.dart';
import 'services/zsolution_service.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({Key? key}) : super(key: key);

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();

  List<Map<String, dynamic>> phones = [];
  List<Map<String, dynamic>> emails = [];
  final List<String> labelOptions = ['Cá nhân', 'Công việc', 'Khác'];
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _fullNameController.addListener(() => setState(() {}));
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final zsolutionUserJson = prefs.getString('zsolution_user');
    if (zsolutionUserJson != null && zsolutionUserJson.isNotEmpty) {
      try {
        final Map<String, dynamic> jsonData = jsonDecode(zsolutionUserJson);
        final user = ZSolutionUser.fromJson(jsonData);
        print('Loaded user id: ${user.id}');
        setState(() {
          _userId = user.id;
          _fullNameController.text = user.userName ?? '';
          phones = [
            {
              'controller': TextEditingController(text: user.phone ?? ''),
              'label': 'Cá nhân',
              'error': false
            },
          ];
          emails = [
            {
              'controller': TextEditingController(text: user.email ?? ''),
              'label': 'Cá nhân',
              'error': false
            },
          ];
        });
      } catch (e) {
        setState(() {
          _userId = null;
          _fullNameController.text = '';
          phones = [
            {
              'controller': TextEditingController(),
              'label': 'Cá nhân',
              'error': false
            },
          ];
          emails = [
            {
              'controller': TextEditingController(),
              'label': 'Cá nhân',
              'error': false
            },
          ];
        });
      }
    } else {
      setState(() {
        _userId = null;
        _fullNameController.text = '';
        phones = [
          {
            'controller': TextEditingController(),
            'label': 'Cá nhân',
            'error': false
          },
        ];
        emails = [
          {
            'controller': TextEditingController(),
            'label': 'Cá nhân',
            'error': false
          },
        ];
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    for (var p in phones) {
      p['controller'].dispose();
    }
    for (var e in emails) {
      e['controller'].dispose();
    }
    super.dispose();
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    bool requiredField = false,
    bool error = false,
    VoidCallback? onClear,
    Widget? suffix,
    Color? fillColor,
    Color? borderColor,
    bool enabled = true,
    String? hint,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF223A5E)),
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        labelStyle: TextStyle(
          color: Color(0xFF223A5E),
          fontWeight: FontWeight.w600,
        ),
        hintText: hint,
        filled: true,
        fillColor: fillColor ?? Color(0xFFF7F9FB),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: borderColor ?? Color(0xFFB0B8C1),
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: error ? Color(0xFFF15B5B) : Color(0xFF2196F3),
            width: 2,
          ),
        ),
        suffixIcon: onClear != null
            ? IconButton(
                icon: Icon(Icons.close, color: Color(0xFF6B7A8F)),
                onPressed: onClear,
              )
            : suffix,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: requiredField
          ? (val) =>
              (val == null || val.trim().isEmpty) ? 'Không được để trống' : null
          : null,
    );
  }

  Widget _buildDynamicList({
    required String type,
    required List<Map<String, dynamic>> items,
    required VoidCallback onAdd,
    required void Function(int) onRemove,
    required void Function(int, String) onLabelChanged,
    Color? fillColor,
    Color? borderColor,
  }) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Field
              Expanded(
                flex: 2,
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  child: _buildEditableField(
                    label: type == 'phone' ? 'Số điện thoại' : 'Email',
                    controller: items[i]['controller'],
                    error: items[i]['error'] ?? false,
                    onClear: items[i]['controller'].text.isNotEmpty
                        ? () => setState(() => items[i]['controller'].clear())
                        : null,
                    fillColor: fillColor ??
                        (i == 0 ? Color(0xFFE6F6FF) : Color(0xFFF7F9FB)),
                    borderColor: borderColor ?? Color(0xFF2196F3),
                    hint: type == 'phone' ? '[0-9]' : 'email@example.com',
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Dropdown label
              Expanded(
                flex: 1,
                child: Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: fillColor ??
                        (i == 0 ? Color(0xFFE6F6FF) : Color(0xFFF7F9FB)),
                    border: Border.all(
                        color: borderColor ?? Color(0xFF2196F3), width: 2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: items[i]['label'],
                      isExpanded: true,
                      icon:
                          Icon(Icons.arrow_drop_down, color: Color(0xFF223A5E)),
                      items: labelOptions
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e,
                                    style: TextStyle(color: Color(0xFF223A5E))),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) onLabelChanged(i, val);
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Remove button
              Container(
                margin: EdgeInsets.only(bottom: 12),
                child: i == 0
                    ? GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          width: 40,
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Color(0xFF223A5E),
                                width: 2,
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.transparent,
                          ),
                          child: Icon(Icons.add, color: Color(0xFF223A5E)),
                        ),
                      )
                    : GestureDetector(
                        onTap: () => onRemove(i),
                        child: Container(
                          width: 40,
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Color(0xFFF15B5B),
                                width: 2,
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.transparent,
                          ),
                          child: Icon(Icons.close, color: Color(0xFFF15B5B)),
                        ),
                      ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _onUpdateProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tìm thấy thông tin user!')),
      );
      return;
    }
    final userName = _fullNameController.text.trim();
    final email = emails.isNotEmpty ? emails[0]['controller'].text.trim() : '';
    final phone = phones.isNotEmpty ? phones[0]['controller'].text.trim() : '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            LoadingAnimationWidget.inkDrop(
              color: Color(0xFF223A5E),
              size: 38,
            ),
            SizedBox(width: 20),
            Text('Đang cập nhật...'),
          ],
        ),
      ),
    );
    try {
      await ZSolutionService.updateProfile(
        id: _userId!,
        userName: userName,
        email: email,
        phone: phone,
      );
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật thành công!')),
      );
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Cập nhật thất bại: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    }
  }

  bool get _canUpdateProfile {
    return _fullNameController.text.trim().isNotEmpty &&
        emails.isNotEmpty &&
        emails[0]['controller'].text.trim().isNotEmpty &&
        phones.isNotEmpty &&
        phones[0]['controller'].text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thông tin cá nhân',
            style: TextStyle(color: Color(0xFF223A5E))),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Color(0xFF223A5E)),
        centerTitle: true,
      ),
      backgroundColor: Color(0xFFF7F9FB),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8),
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFFE3F0FA),
                  child: Icon(Icons.person, color: Color(0xFF6B7A8F), size: 48),
                ),
              ),
              SizedBox(height: 16),
              // Tên đầy đủ
              _buildEditableField(
                label: 'Tên đầy đủ',
                controller: _fullNameController,
                requiredField: true,
                fillColor: Color(0xFFF7F9FB),
                borderColor: Color(0xFF2196F3),
              ),
              SizedBox(height: 16),
              // Danh sách số điện thoại
              _buildDynamicList(
                type: 'phone',
                items: phones,
                onAdd: () {
                  setState(() {
                    final ctrl = TextEditingController();
                    ctrl.addListener(() => setState(() {}));
                    phones.add({
                      'controller': ctrl,
                      'label': 'Cá nhân',
                      'error': false
                    });
                  });
                },
                onRemove: (i) {
                  setState(() {
                    phones[i]['controller'].dispose();
                    phones.removeAt(i);
                  });
                },
                onLabelChanged: (i, val) {
                  setState(() {
                    phones[i]['label'] = val;
                  });
                },
                fillColor: Color(0xFFE6F6FF),
                borderColor: Color(0xFF2196F3),
              ),
              // Danh sách email
              _buildDynamicList(
                type: 'email',
                items: emails,
                onAdd: () {
                  setState(() {
                    final ctrl = TextEditingController();
                    ctrl.addListener(() => setState(() {}));
                    emails.add({
                      'controller': ctrl,
                      'label': 'Cá nhân',
                      'error': false
                    });
                  });
                },
                onRemove: (i) {
                  setState(() {
                    emails[i]['controller'].dispose();
                    emails.removeAt(i);
                  });
                },
                onLabelChanged: (i, val) {
                  setState(() {
                    emails[i]['label'] = val;
                  });
                },
                fillColor: Color(0xFFE6F6FF),
                borderColor: Color(0xFF2196F3),
              ),
              SizedBox(height: 24),
              // Nút cập nhật
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 49, 248, 99),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _canUpdateProfile ? _onUpdateProfile : null,
                  child: Text('Cập nhật',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white)),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
