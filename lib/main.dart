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
import 'src/services/firebase_call_service.dart';
import 'src/services/firebase_options.dart';

import 'src/about.dart';
import 'src/callscreen.dart';
import 'src/dialpad.dart';
import 'src/register.dart';
import 'src/intro_screen.dart';
import 'src/main_tabs.dart';
import 'src/z_solution_login_widget.dart';
import 'src/providers/call_provider.dart';
import 'src/widgets/call_handler.dart';

// Xử lý thông báo khi ứng dụng ở background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Xử lý thông báo ở đây
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Khởi tạo Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Cấu hình Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Khởi tạo Firebase Call Service
  final firebaseCallService = FirebaseCallService();
  await firebaseCallService.initialize();
  
  Logger.level = Level.warning;
  if (WebRTC.platformIsDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
  
  // Khởi tạo SIPUAHelper với cấu hình mặc định
  final SIPUAHelper _normalHelper = SIPUAHelper();
  final SIPUAHelper _zSolutionHelper = SIPUAHelper();
  
  // Cấu hình logger chi tiết hơn
  Logger.level = Level.debug;
  
  runApp(
    MultiProvider(
      providers: [
        Provider<SIPUAHelper>.value(value: _normalHelper),
        Provider<SIPUAHelper>.value(value: _zSolutionHelper),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<CallProvider>(create: (_) => CallProvider()),
        Provider<SipUserCubit>(
          create: (context) => SipUserCubit(sipHelper: _normalHelper),
        ),
        Provider<FirebaseCallService>.value(value: firebaseCallService),
      ],
      child: CallHandler(
        child: MyApp(),
      ),
    ),
  );
}

typedef PageContentBuilder = Widget Function(
    [SIPUAHelper? helper, Object? arguments]);

// ignore: must_be_immutable
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final normalHelper = Provider.of<SIPUAHelper>(context);
    final zSolutionHelper = Provider.of<SIPUAHelper>(context);
    final sipUserCubit = Provider.of<SipUserCubit>(context);

    return MaterialApp(
      title: 'SOLY',
      theme: Provider.of<ThemeProvider>(context).currentTheme,
      initialRoute: '/intro',
      onGenerateRoute: (settings) {
        final String? name = settings.name;
        
        final Map<String, PageContentBuilder> routes = {
          '/home': ([SIPUAHelper? h, Object? arguments]) {
            if (arguments is SIPUAHelper) {
              return MainTabs(arguments);
            }
            return MainTabs(h ?? normalHelper);
          },
          '/intro': ([SIPUAHelper? h, Object? arguments]) => IntroScreen(),
          '/': ([SIPUAHelper? h, Object? arguments]) => DialPadWidget(helper: h ?? normalHelper),
          '/register': ([SIPUAHelper? h, Object? arguments]) => RegisterWidget(h ?? normalHelper),
          '/zsolution': ([SIPUAHelper? h, Object? arguments]) => ZSolutionLoginWidget(helper: zSolutionHelper),
          '/callscreen': ([SIPUAHelper? h, Object? arguments]) => CallScreenWidget(h, settings.arguments as Call?),
          '/about': ([SIPUAHelper? h, Object? arguments]) => AboutWidget(),
        };
        final PageContentBuilder? pageContentBuilder = routes[name!];
        if (pageContentBuilder != null) {
          if (settings.arguments != null) {
            return MaterialPageRoute<Widget>(
                builder: (context) =>
                    pageContentBuilder(settings.arguments as SIPUAHelper));
          } else {
            return MaterialPageRoute<Widget>(
                builder: (context) => pageContentBuilder(normalHelper));
          }
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
