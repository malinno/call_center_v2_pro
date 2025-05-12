import 'package:dart_sip_ua_example/src/theme_provider.dart';
import 'package:dart_sip_ua_example/src/user_state/sip_user_cubit.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'src/services/firebase_call_service.dart';
import 'src/services/firebase_options.dart';
// import 'src/services/firebase_service.dart';

import 'src/about.dart';
import 'src/callscreen.dart';
import 'src/dialpad.dart';
import 'src/register.dart';
import 'src/intro_screen.dart';
import 'src/main_tabs.dart';
import 'src/z_solution_login_widget.dart';
import 'src/providers/call_provider.dart';
import 'src/widgets/call_handler.dart';

final _logger = Logger();

// Xử lý thông báo khi ứng dụng ở background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _logger.d('Firebase initialized in background handler');
  } catch (e) {
    _logger.e('Error initializing Firebase in background: $e');
  }
}

Future<void> initializeFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _logger.d('Firebase initialized successfully');
      
      // Cấu hình Firebase Messaging
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      _logger.d('Firebase Messaging configured');
      
      // Lấy FCM token
      String? token = await FirebaseMessaging.instance.getToken();
      _logger.d('FCM Token: $token');
    } else {
      _logger.d('Firebase already initialized');
    }
  } catch (e) {
    _logger.e('Error initializing Firebase: $e');
  }
}

Future<void> initializeApp() async {
  try {
    // // Khởi tạo Firebase thông qua service
    // await FirebaseService.instance.initialize();

    // Khởi tạo SIPUAHelper
    final SIPUAHelper _normalHelper = SIPUAHelper();
    final SIPUAHelper _zSolutionHelper = SIPUAHelper();

    // // Khởi tạo Firebase Call Service
    // final firebaseCallService = FirebaseCallService();
    // await firebaseCallService.initialize();

    if (WebRTC.platformIsDesktop) {
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
    }

    return runApp(
      MultiProvider(
        providers: [
          Provider<SIPUAHelper>.value(value: _normalHelper),
          Provider<SIPUAHelper>.value(value: _zSolutionHelper),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<CallProvider>(create: (_) => CallProvider()),
          Provider<SipUserCubit>(
            create: (context) => SipUserCubit(sipHelper: _normalHelper),
          ),
          // Provider<FirebaseCallService>.value(value: firebaseCallService),
        ],
        child: CallHandler(
          child: MyApp(),
        ),
      ),
    );
  } catch (e) {
    // Hiển thị màn hình lỗi với nút thử lại
    return runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Không thể khởi động ứng dụng',
                  style: TextStyle(fontSize: 18),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await initializeApp();
                  },
                  child: Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeApp();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final normalHelper = Provider.of<SIPUAHelper>(context);
    final zSolutionHelper = Provider.of<SIPUAHelper>(context);

    return MaterialApp(
      title: 'SOLY',
      theme: Provider.of<ThemeProvider>(context).currentTheme,
      home: IntroScreen(),
      routes: {
        '/intro': (context) => IntroScreen(),
        '/home': (context) => MainTabs(normalHelper),
        '/dialpad': (context) => DialPadWidget(helper: normalHelper),
        '/register': (context) => RegisterWidget(normalHelper),
        '/zsolution': (context) => ZSolutionLoginWidget(helper: zSolutionHelper),
        '/about': (context) => AboutWidget(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/callscreen') {
          final Call? call = settings.arguments as Call?;
          return MaterialPageRoute(
            builder: (context) => CallScreenWidget(normalHelper, call),
          );
        }
        return null;
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Call Demo'),
      ),
      body: const Center(
        child: Text('Waiting for incoming calls...'),
      ),
    );
  }
}
