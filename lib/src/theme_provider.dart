import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  /// Theme hiện tại
  late ThemeData currentTheme;

  Timer? _timer;

  ThemeProvider() {
    // Khởi theme ban đầu theo hệ thống
    final brightness = PlatformDispatcher.instance.platformBrightness;
    currentTheme = brightness == Brightness.dark
        ? ThemeData.dark()
        : ThemeData.light();

    // Khởi timer mỗi phút để tự động check giờ
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkTime(),
    );
  }

  // Hàm check giờ để chuyển theme
  void _checkTime() {
    final now = DateTime.now();
    // Ví dụ: Dark mode từ 18:00 đến 06:00
    final isDarkTime = now.hour >= 18 || now.hour < 6;
    final isCurrentlyDark = currentTheme.brightness == Brightness.dark;

    if (isDarkTime && !isCurrentlyDark) {
      setDarkMode();
    } else if (!isDarkTime && isCurrentlyDark) {
      setLightMode();
    }
  }

  /// Bật Light mode
  void setLightMode() {
    currentTheme = ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'Roboto',
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.grey),
        contentPadding: EdgeInsets.all(10),
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.black12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(fontSize: 18),
        ),
      ),
    );
    notifyListeners();
  }

  /// Bật Dark mode
  void setDarkMode() {
    currentTheme = ThemeData.dark().copyWith(
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          textStyle: const TextStyle(fontSize: 18),
        ),
      ),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
