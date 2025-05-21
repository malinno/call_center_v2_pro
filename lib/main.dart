import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'src/services/firebase_options.dart';
import 'src/theme_provider.dart';
import 'src/user_state/sip_user_cubit.dart';
import 'src/callscreen.dart';
import 'src/dialpad.dart';
import 'src/register.dart';
import 'src/intro_screen.dart';
import 'src/main_tabs.dart';
import 'src/z_solution_login_widget.dart';
import 'src/providers/call_provider.dart';
import 'src/widgets/call_handler.dart';
import 'src/call_history.dart';
import 'src/call_center_info.dart';
import 'src/change_password_screen.dart';
import 'src/device_permission_screen.dart';
import 'src/notification_settings_screen.dart';
import 'src/call_sound_settings_screen.dart';
import 'src/personal_info_screen.dart';

final _logger = Logger();

Future<void> initializeApp() async {
  try {
    // Khởi tạo SIPUAHelper
    final SIPUAHelper _normalHelper = SIPUAHelper();
    final SIPUAHelper _zSolutionHelper = SIPUAHelper();

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
        ],
        child: CallHandler(
          child: MyApp(),
        ),
      ),
    );
  } catch (e) {
    _logger.e('Error initializing app: $e');
    // Hiển thị màn hình lỗi với nút thử lại
    return runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Không thể khởi động ứng dụng: ${e.toString()}',
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
    final normalHelper = Provider.of<SIPUAHelper>(context, listen: false);
    final zSolutionHelper = Provider.of<SIPUAHelper>(context, listen: false);

    return MaterialApp(
      title: 'SOLY',
      theme: Provider.of<ThemeProvider>(context).currentTheme,
      home: IntroScreen(),
      routes: {
        '/intro': (context) => IntroScreen(),
        '/home': (context) {
          final helper =
              ModalRoute.of(context)?.settings.arguments as SIPUAHelper?;
          return MainTabs(helper ?? normalHelper);
        },
        '/dialpad': (context) {
          final helper =
              ModalRoute.of(context)?.settings.arguments as SIPUAHelper?;
          return DialPadWidget(helper: helper ?? normalHelper);
        },
        '/call_center_info': (context) => CallCenterInfoScreen(),
        '/history': (context) {
          final helper =
              ModalRoute.of(context)?.settings.arguments as SIPUAHelper?;
          return CallHistoryWidget(helper: helper ?? normalHelper);
        },
        '/register': (context) => RegisterWidget(normalHelper),
        '/zsolution': (context) =>
            ZSolutionLoginWidget(helper: zSolutionHelper),
        '/change_password': (context) => ChangePasswordScreen(),
        '/device_permission': (context) => DevicePermissionScreen(),
        '/notification_settings': (context) => NotificationSettingsScreen(),
        '/call_sound_settings': (context) => CallSoundSettingsScreen(),
        '/personal_info': (context) => PersonalInfoScreen(),
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
        title: const Text('Call Demo'),
      ),
      body: const Center(
        child: Text('Waiting for incoming calls...'),
      ),
    );
  }
}
