import 'package:dart_sip_ua_example/src/theme_provider.dart';
import 'package:dart_sip_ua_example/src/user_state/sip_user_cubit.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';

import 'src/about.dart';
import 'src/callscreen.dart';
import 'src/dialpad.dart';
import 'src/register.dart';
import 'src/intro_screen.dart';
import 'src/main_tabs.dart';
import 'src/z_solution_login_widget.dart';

void main() {
  Logger.level = Level.warning;
  if (WebRTC.platformIsDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
  final SIPUAHelper _normalHelper = SIPUAHelper();
  final SIPUAHelper _zSolutionHelper = SIPUAHelper();
  
 runApp(
    MultiProvider(
      providers: [
        Provider<SIPUAHelper>.value(value: _normalHelper),
        Provider<SIPUAHelper>.value(value: _zSolutionHelper),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ],
      child: MyApp(),
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
    final SIPUAHelper helper = normalHelper;

    return MultiProvider(
      providers: [
        Provider<SipUserCubit>(
            create: (context) => SipUserCubit(sipHelper: normalHelper)),
      ],
      child: MaterialApp(
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
              return MainTabs(h);
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
                      pageContentBuilder(helper, settings.arguments));
            } else {
              return MaterialPageRoute<Widget>(
                  builder: (context) => pageContentBuilder(helper));
            }
          }
          return null;
        },
      ),
    );
  }
}
