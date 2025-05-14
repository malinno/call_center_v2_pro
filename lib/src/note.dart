import 'package:flutter/material.dart';

class NoteWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Phiếu ghi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF223A5E))),
                          SizedBox(height: 2),
                          Text('0 phiếu ghi', style: TextStyle(fontSize: 13.5, color: Color(0xFFB0B8C1))),
                        ],
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 40,
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.search, color: Color(0xFF223A5E)),
                        onPressed: () {},
                        iconSize: 22,
                        splashRadius: 22,
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.tune, color: Color(0xFF223A5E)),
                        onPressed: () {},
                        iconSize: 22,
                        splashRadius: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sync, size: 90, color: Color(0xFF1DA1F2)), // Thay bằng ảnh minh họa nếu có
                    SizedBox(height: 18),
                    Text('Chưa có dữ liệu', style: TextStyle(fontSize: 17, color: Color(0xFFB0B8C1), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 