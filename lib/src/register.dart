import 'package:dart_sip_ua_example/src/user_state/sip_user.dart';
import 'package:dart_sip_ua_example/src/user_state/sip_user_cubit.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class RegisterWidget extends StatefulWidget {
  final SIPUAHelper? _helper;

  RegisterWidget(this._helper, {Key? key}) : super(key: key);

  @override
  State<RegisterWidget> createState() => _MyRegisterWidget();
}

class _MyRegisterWidget extends State<RegisterWidget>
    implements SipUaHelperListener {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _wsUriController = TextEditingController();
  final TextEditingController _sipUriController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _authorizationUserController =
      TextEditingController();
  final Map<String, String> _wsExtraHeaders = {
    'X-WebSocket-Protocol': 'sip',
    'X-WebSocket-Extensions': 'permessage-deflate',
    'X-WebSocket-Version': '13',
    'X-WebSocket-Allow-Self-Signed': 'true'
  };
  late SharedPreferences _preferences;
  late RegistrationState _registerState;

  TransportType _selectedTransport = TransportType.TCP;

  SIPUAHelper? get helper => widget._helper;

  late SipUserCubit currentUser;

  @override
  void initState() {
    super.initState();
    _registerState = helper!.registerState;
    helper!.addSipUaHelperListener(this);
    _loadSettings();
    if (kIsWeb) {
      _selectedTransport = TransportType.WS;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _wsUriController.dispose();
    _sipUriController.dispose();
    _displayNameController.dispose();
    _authorizationUserController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    super.deactivate();
    helper!.removeSipUaHelperListener(this);
    _saveSettings();
  }

  void _loadSettings() async {
    _preferences = await SharedPreferences.getInstance();
    setState(() {
      _portController.text = '8089';
      _wsUriController.text = 'wss://c6.zsolution.vn:8089/ws';
      _sipUriController.text = '442002@c6.zsolution.vn';
      _passwordController.text = 'f99@2022';
      _authorizationUserController.text = '442002';
    });
    print('WebSocket URI set to: ${_wsUriController.text}');
  }

  void _saveSettings() {
    _preferences.setString('port', _portController.text);
    _preferences.setString('ws_uri', _wsUriController.text);
    _preferences.setString('sip_uri', _sipUriController.text);
    _preferences.setString('display_name', _displayNameController.text);
    _preferences.setString('password', _passwordController.text);
    _preferences.setString('auth_user', _authorizationUserController.text);
  }

  @override
  void registrationStateChanged(RegistrationState state) {
    print('Registration state changed: ${state.state?.name}');
    
    if (mounted) {
      setState(() {
        _registerState = state;
      });
    }

    // Handle registration state
    switch (state.state) {
      case RegistrationStateEnum.REGISTERED:
        print('Successfully registered');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully registered')),
        );
        Navigator.pop(context); // Return to previous screen
        break;
      case RegistrationStateEnum.REGISTRATION_FAILED:
        print('Registration failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed')),
        );
        break;
      case RegistrationStateEnum.UNREGISTERED:
        print('Unregistered');
        break;
      default:
        print('Other registration state: ${state.state?.name}');
    }
  }

  void _alert(BuildContext context, String alertFieldName) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
            title: Text('$alertFieldName is empty'),
            content: Text('Please enter $alertFieldName!'),
            actions: <Widget>[
              TextButton(
                child: Text('Ok'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ]);
      },
    );
  }

  void _register(BuildContext context) async {
    if (_wsUriController.text == '') {
      _alert(context, "WebSocket URL");
      return;
    } else if (_sipUriController.text == '') {
      _alert(context, "SIP URI");
      return;
    }

    _saveSettings();
    print('Starting registration with WebSocket URI: ${_wsUriController.text}');

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Registering...")
            ],
          ),
        );
      },
    );

    // Run registration in background
    await Future.microtask(() {
      currentUser.register(SipUser(
          selectedTransport: _selectedTransport,
          wsExtraHeaders: _wsExtraHeaders,
          wsUrl: _wsUriController.text,
          sipUri: _sipUriController.text,
          port: _portController.text,
          displayName: _displayNameController.text,
          password: _passwordController.text,
          authUser: _authorizationUserController.text));
    });
  }

  @override
  Widget build(BuildContext context) {
    Color? textColor = Theme.of(context).textTheme.bodyMedium?.color;
    Color? textFieldFill =
        Theme.of(context).buttonTheme.colorScheme?.surfaceContainerLowest;
    currentUser = context.watch<SipUserCubit>();

    OutlineInputBorder border = OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.circular(5),
    );
    Color? textLabelColor =
        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5);
    return Scaffold(
      appBar: AppBar(
        title: Text("SIP Account"),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      child: Text('Register'),
                      onPressed: () => _register(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        children: <Widget>[
          Center(
            child: Text(
              'Register Status: ${_registerState.state?.name ?? ''}',
              style: TextStyle(fontSize: 18, color: textColor),
            ),
          ),
          SizedBox(height: 15),
          if (_selectedTransport == TransportType.WS) ...[
            Text('WebSocket', style: TextStyle(color: textLabelColor)),
            SizedBox(height: 5),
            TextFormField(
              controller: _wsUriController,
              keyboardType: TextInputType.text,
              autocorrect: false,
              textAlign: TextAlign.center,
            ),
          ],
          if (_selectedTransport == TransportType.TCP) ...[
            Text('Port', style: TextStyle(color: textLabelColor)),
            SizedBox(height: 5),
            TextFormField(
              controller: _portController,
              keyboardType: TextInputType.text,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: textFieldFill,
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
            ),
          ],
          SizedBox(height: 15),
          Text('SIP URI', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _sipUriController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
            ),
          ),
          SizedBox(height: 15),
          Text('Authorization User', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _authorizationUserController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText:
                  _authorizationUserController.text.isEmpty ? '[Empty]' : null,
            ),
          ),
          SizedBox(height: 15),
          Text('Password', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _passwordController,
            keyboardType: TextInputType.text,
            autocorrect: false,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText: _passwordController.text.isEmpty ? '[Empty]' : null,
            ),
          ),
          SizedBox(height: 15),
          Text('Display Name', style: TextStyle(color: textLabelColor)),
          SizedBox(height: 5),
          TextFormField(
            controller: _displayNameController,
            keyboardType: TextInputType.text,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: textFieldFill,
              border: border,
              enabledBorder: border,
              focusedBorder: border,
              hintText: _displayNameController.text.isEmpty ? '[Empty]' : null,
            ),
          ),
          const SizedBox(height: 20),
          if (!kIsWeb) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RadioMenuButton<TransportType>(
                    value: TransportType.TCP,
                    groupValue: _selectedTransport,
                    onChanged: ((value) => setState(() {
                          _selectedTransport = value!;
                        })),
                    child: Text("TCP")),
                RadioMenuButton<TransportType>(
                    value: TransportType.WS,
                    groupValue: _selectedTransport,
                    onChanged: ((value) => setState(() {
                          _selectedTransport = value!;
                        })),
                    child: Text("WS")),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  void callStateChanged(Call call, CallState state) {
    //NO OP
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // NO OP
  }

  @override
  void onNewNotify(Notify ntf) {
    // NO OP
  }

  @override
  void onNewReinvite(ReInvite event) {
    // TODO: implement onNewReinvite
  }
}
