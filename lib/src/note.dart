import 'package:flutter/material.dart';

class NoteWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text('Phiếu ghi', style: TextStyle(fontSize: 24)),
      ),
    );
  }
} 