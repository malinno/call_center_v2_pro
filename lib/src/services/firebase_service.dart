import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:logger/logger.dart';
import 'firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  static FirebaseService get instance => _instance;
  
  final _logger = Logger();
  bool _isInitialized = false;

  FirebaseService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Kiểm tra xem Firebase đã được khởi tạo chưa
      if (Firebase.apps.isNotEmpty) {
        _isInitialized = true;
        return;
      }

      // Khởi tạo Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Cấu hình Firebase Messaging
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _isInitialized = true;
    } catch (e) {
      // Nếu có lỗi, thử lấy instance hiện có
      try {
        Firebase.app();
        _isInitialized = true;
      } catch (e) {
        // Nếu vẫn không được, đánh dấu là chưa khởi tạo
        _isInitialized = false;
      }
    }
  }

  Future<String?> getFCMToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      _logger.e('Error getting FCM token: $e');
      return null;
    }
  }
} 