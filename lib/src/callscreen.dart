import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widgets/action_button.dart';
import 'call_history.dart';

enum Originator { local, remote, system }

enum Direction { incoming, outgoing }

class CallScreenWidget extends StatefulWidget {
  final SIPUAHelper? _helper;
  final Call? _call;
  final String? source;

  CallScreenWidget(this._helper, this._call, {this.source, Key? key})
      : super(key: key);

  @override
  State<CallScreenWidget> createState() => _MyCallScreenWidget();
}

class _MyCallScreenWidget extends State<CallScreenWidget>
    implements SipUaHelperListener {
  RTCVideoRenderer? _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer? _remoteRenderer = RTCVideoRenderer();
  double? _localVideoHeight;
  double? _localVideoWidth;
  EdgeInsetsGeometry? _localVideoMargin;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  bool _showNumPad = false;
  final ValueNotifier<String> _timeLabel = ValueNotifier<String>('00:00');
  bool _audioMuted = false;
  bool _videoMuted = false;
  bool _speakerOn = false;
  bool _hold = false;
  bool _mirror = true;
  Originator? _holdOriginator;
  bool _callConfirmed = false;
  CallStateEnum _state = CallStateEnum.NONE;

  late String _transferTarget;
  late Timer _timer;
  DateTime? _callStartTime;
  int _talkDuration = 0;
  Timer? _talkTimer;

  SIPUAHelper? get helper => widget._helper;

  bool get voiceOnly =>
      call?.voiceOnly == true && call?.remote_has_video != true;

  String? get remoteIdentity => call?.remote_identity;

  Direction? get direction {
    if (call == null) return null;
    if (call!.direction?.toLowerCase() == 'incoming') return Direction.incoming;
    if (call!.direction?.toLowerCase() == 'outgoing') return Direction.outgoing;
    return null;
  }

  Call? get call => widget._call;

  @override
  initState() {
    super.initState();
    _talkDuration = 0;
    print(
        'CallScreen - initState, call direction: ${call?.direction}, state: ${call?.state}');
    _initRenderers();
    helper!.addSipUaHelperListener(this);
    _callConfirmed = false;
    _state = CallStateEnum.NONE;
    _timer = Timer(Duration(days: 365),
        () {}); // Dummy timer để tránh LateInitializationError

    // Khởi tạo audio session
    if (!kIsWeb) {
      _initAudioSession();
    }
  }

  @override
  deactivate() {
    super.deactivate();
    helper!.removeSipUaHelperListener(this);
    _disposeRenderers();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      Duration duration = Duration(seconds: timer.tick);
      if (mounted) {
        _timeLabel.value = [duration.inMinutes, duration.inSeconds]
            .map((seg) => seg.remainder(60).toString().padLeft(2, '0'))
            .join(':');
      } else {
        _timer.cancel();
      }
    });
  }

  void _initRenderers() async {
    if (_localRenderer != null) {
      await _localRenderer!.initialize();
    }
    if (_remoteRenderer != null) {
      await _remoteRenderer!.initialize();
    }
  }

  void _disposeRenderers() {
    if (_localRenderer != null) {
      _localRenderer!.dispose();
      _localRenderer = null;
    }
    if (_remoteRenderer != null) {
      _remoteRenderer!.dispose();
      _remoteRenderer = null;
    }
  }

  Future<void> _initAudioSession() async {
    try {
      // Cấu hình audio session
      if (_localStream != null) {
        for (var track in _localStream!.getAudioTracks()) {
          track.enableSpeakerphone(false);
        }
      }
    } catch (e) {
      print('Error initializing audio session: $e');
    }
  }

  Future<bool> _checkMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Cần quyền truy cập microphone'),
            content: Text(
                'Ứng dụng cần quyền truy cập microphone để thực hiện cuộc gọi. Vui lòng cấp quyền trong Cài đặt.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Hủy'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text('Mở Cài đặt'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    return status.isGranted;
  }

  Future<void> _handleCall() async {
    if (!await _checkMicrophonePermission()) {
      return;
    }

    // Tiếp tục xử lý cuộc gọi nếu đã có quyền
    if (call != null) {
      if (call!.state == CallStateEnum.CONFIRMED) {
        call!.hangup();
      } else {
        call!.answer(helper!.buildCallOptions(call!.voiceOnly));
      }
    }
  }

  @override
  void callStateChanged(Call call, CallState state) {
    print(
        'CallScreen - callStateChanged: state=${state.state}, direction=${call.direction}, _callConfirmed=$_callConfirmed, _state=$_state, remote_identity=${call.remote_identity}');

    // Cập nhật trạng thái cuộc gọi
    _state = state.state;

    switch (state.state) {
      case CallStateEnum.CONFIRMED:
        print('CallScreen - Call CONFIRMED, setting _callConfirmed to true');
        setState(() {
          _callConfirmed = true;
        });
        _startTimer();
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        print(
            'CallScreen - Call ENDED/FAILED, _callConfirmed=$_callConfirmed, direction=${call.direction}');
        if (call.direction?.toLowerCase() == 'outgoing') {
          print(
              'CallScreen - Saving call history for outgoing call, missed=${!_callConfirmed}, remote=${call.remote_identity}');
          saveCallHistory(call.remote_identity ?? '', missed: !_callConfirmed);
        }
        if (widget.source == 'history') {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil(
              '/dialpad', (route) => false,
              arguments: helper);
        }
        break;
      case CallStateEnum.ACCEPTED:
        print('CallScreen - Call ACCEPTED');
        setState(() {});
        break;
      case CallStateEnum.PROGRESS:
        print('CallScreen - Call PROGRESS');
        setState(() {});
        break;
      case CallStateEnum.CALL_INITIATION:
        print('CallScreen - Call INITIATION');
        setState(() {});
        break;
      default:
        print('CallScreen - Other state: ${state.state}');
        setState(() {});
        break;
    }
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void registrationStateChanged(RegistrationState state) {}

  void _cleanUp() {
    try {
      if (_localStream != null) {
        for (var track in _localStream!.getTracks()) {
          track.stop();
        }
        _localStream!.dispose();
        _localStream = null;
      }

      if (_remoteStream != null) {
        for (var track in _remoteStream!.getTracks()) {
          track.stop();
        }
        _remoteStream!.dispose();
        _remoteStream = null;
      }
    } catch (e) {
      print('Error cleaning up streams: $e');
    }
  }

  void _handleHangup() {
    print('CallScreen - _handleHangup called, source: ${widget.source}');
    try {
      if (call != null &&
          call!.state != CallStateEnum.ENDED &&
          call!.state != CallStateEnum.FAILED) {
        call!.hangup({'status_code': 603});
      }
    } catch (e) {
      print('Error when hanging up: $e');
    }
    if (_timer.isActive) _timer.cancel();

    // Cleanup resources first
    _cleanUp();
    _disposeRenderers();

    // Quay về màn hình phù hợp dựa vào nguồn gọi
    if (mounted) {
      print('CallScreen - Navigating back, source: ${widget.source}');
      if (widget.source == 'history') {
        // Nếu gọi từ màn lịch sử thì quay về màn lịch sử
        Navigator.of(context).pop();
      } else {
        // Nếu gọi từ màn dialpad thì quay về màn dialpad
        Navigator.of(context).pushNamedAndRemoveUntil(
            '/dialpad', (route) => false,
            arguments: helper);
      }
    }
  }

  void _backToDialPad() {
    if (_timer.isActive) _timer.cancel();
    _cleanUp();
    _disposeRenderers();
    if (mounted) {
      if (widget.source == 'history') {
        // Nếu gọi từ màn lịch sử thì quay về màn lịch sử
        Navigator.of(context).pop();
      } else {
        // Nếu gọi từ màn dialpad thì quay về màn dialpad
        Navigator.of(context).pushNamedAndRemoveUntil(
            '/dialpad', (route) => false,
            arguments: helper);
      }
    }
  }

  void _handleStreams(CallState event) async {
    MediaStream? stream = event.stream;
    if (stream == null) return;

    print(
        'CallScreen - _handleStreams: originator=${event.originator}, state=${_state}, _callConfirmed=$_callConfirmed');

    if (event.originator == 'local') {
      if (_localRenderer != null) {
        _localRenderer!.srcObject = stream;
      }
      if (!kIsWeb) {
        final audioTracks = stream.getAudioTracks();
        if (audioTracks.isNotEmpty) {
          audioTracks.first.enableSpeakerphone(false);
        }
      }
      _localStream = stream;
    }
    if (event.originator == 'remote') {
      print(
          'CallScreen - Received remote stream, setting _callConfirmed to true');
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = stream;
      }
      _remoteStream = stream;
      setState(() {
        _callConfirmed = true;
      });
    }
    setState(() {
      _resizeLocalVideo();
    });
  }

  void _resizeLocalVideo() {
    _localVideoMargin = _remoteStream != null
        ? EdgeInsets.only(top: 15, right: 15)
        : EdgeInsets.all(0);
    _localVideoWidth = _remoteStream != null
        ? MediaQuery.of(context).size.width / 4
        : MediaQuery.of(context).size.width;
    _localVideoHeight = _remoteStream != null
        ? MediaQuery.of(context).size.height / 4
        : MediaQuery.of(context).size.height;
  }

  void _handleAccept() async {
    if (call?.direction?.toLowerCase() != 'incoming') {
      return;
    }

    setState(() {
      _callConfirmed = true;
    });

    bool remoteHasVideo = call!.remote_has_video;
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': remoteHasVideo
          ? {
              'mandatory': <String, dynamic>{
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': <dynamic>[],
            }
          : false
    };
    MediaStream mediaStream;

    try {
      if (kIsWeb && remoteHasVideo) {
        mediaStream =
            await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
        MediaStream userStream =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
        mediaStream.addTrack(userStream.getAudioTracks()[0], addToNative: true);
      } else {
        if (!remoteHasVideo) {
          mediaConstraints['video'] = false;
        }
        mediaStream =
            await navigator.mediaDevices.getUserMedia(mediaConstraints);
      }

      // Cấu hình audio trước khi answer
      if (!kIsWeb) {
        for (var track in mediaStream.getAudioTracks()) {
          track.enableSpeakerphone(false);
        }
      }

      call!.answer(helper!.buildCallOptions(!remoteHasVideo),
          mediaStream: mediaStream);
    } catch (e) {
      setState(() {
        _callConfirmed = false;
      });
    }
  }

  void _switchCamera() {
    if (_localStream != null) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
      setState(() {
        _mirror = !_mirror;
      });
    }
  }

  void _muteAudio() {
    if (_audioMuted) {
      call!.unmute(true, false);
    } else {
      call!.mute(true, false);
    }
  }

  void _muteVideo() {
    if (_videoMuted) {
      call!.unmute(false, true);
    } else {
      call!.mute(false, true);
    }
  }

  void _handleHold() {
    if (_hold) {
      call!.unhold();
    } else {
      call!.hold();
    }
  }

  void _handleTransfer() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Enter target to transfer.'),
          content: TextField(
            onChanged: (String text) {
              setState(() {
                _transferTarget = text;
              });
            },
            decoration: InputDecoration(
              hintText: 'URI or Username',
            ),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Ok'),
              onPressed: () {
                call!.refer(_transferTarget);
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _handleDtmf(String tone) {
    print('Dtmf tone => $tone');
    call!.sendDTMF(tone);
  }

  void _handleKeyPad() {
    setState(() {
      _showNumPad = !_showNumPad;
    });
  }

  void _handleVideoUpgrade() {
    if (voiceOnly) {
      setState(() {
        call!.voiceOnly = false;
      });
      helper!.renegotiate(
          call: call!,
          voiceOnly: false,
          done: (IncomingMessage? incomingMessage) {});
    } else {
      helper!.renegotiate(
          call: call!,
          voiceOnly: true,
          done: (IncomingMessage? incomingMessage) {});
    }
  }

  void _toggleSpeaker() {
    if (_localStream != null) {
      _speakerOn = !_speakerOn;
      if (!kIsWeb) {
        for (var track in _localStream!.getAudioTracks()) {
          track.enableSpeakerphone(_speakerOn);
        }
      }
    }
  }

  List<Widget> _buildNumPad() {
    final labels = [
      [
        {'1': ''},
        {'2': 'abc'},
        {'3': 'def'}
      ],
      [
        {'4': 'ghi'},
        {'5': 'jkl'},
        {'6': 'mno'}
      ],
      [
        {'7': 'pqrs'},
        {'8': 'tuv'},
        {'9': 'wxyz'}
      ],
      [
        {'*': ''},
        {'0': '+'},
        {'#': ''}
      ],
    ];

    return labels
        .map((row) => Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row
                    .map((label) => ActionButton(
                          title: label.keys.first,
                          subTitle: label.values.first,
                          onPressed: () => _handleDtmf(label.keys.first),
                          number: true,
                        ))
                    .toList())))
        .toList();
  }

  Widget _buildActionButtons() {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ActionButton(
            icon: Icons.mic,
            fillColor: _audioMuted ? Colors.red : Colors.white,
            onPressed: () {
              if (call != null) {
                if (_audioMuted) {
                  call!.unmute(true, false);
                } else {
                  call!.mute(true, false);
                }
              }
            },
          ),
          ActionButton(
            icon: Icons.call_end,
            fillColor: Colors.red,
            onPressed: _handleCall,
          ),
          ActionButton(
            icon: Icons.videocam,
            fillColor: _videoMuted ? Colors.red : Colors.white,
            onPressed: () {
              if (call != null) {
                if (_videoMuted) {
                  call!.unmute(false, true);
                } else {
                  call!.mute(false, true);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    Color? textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final stackWidgets = <Widget>[];

    if (_callConfirmed && !voiceOnly && _remoteStream != null) {
      stackWidgets.add(
        Center(
          child: RTCVideoView(
            _remoteRenderer!,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      );
    }

    if (_callConfirmed && !voiceOnly && _localStream != null) {
      stackWidgets.add(
        AnimatedContainer(
          child: RTCVideoView(
            _localRenderer!,
            mirror: _mirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
          height: _localVideoHeight,
          width: _localVideoWidth,
          alignment: Alignment.topRight,
          duration: Duration(milliseconds: 300),
          margin: _localVideoMargin,
        ),
      );
    }

    stackWidgets.addAll(
      [
        Positioned(
          top: MediaQuery.of(context).size.height / 8,
          left: 0,
          right: 0,
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      (voiceOnly ? 'VOICE CALL' : 'VIDEO CALL') +
                          (_hold ? ' PAUSED BY ${_holdOriginator!.name}' : ''),
                      style: TextStyle(fontSize: 24, color: textColor),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      remoteIdentity ?? 'Đang kết nối...',
                      style: TextStyle(fontSize: 18, color: textColor),
                    ),
                  ),
                ),
                if (_callConfirmed && call != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ValueListenableBuilder<String>(
                        valueListenable: _timeLabel,
                        builder: (context, value, child) {
                          return Text(
                            _timeLabel.value,
                            style: TextStyle(fontSize: 14, color: textColor),
                          );
                        },
                      ),
                    ),
                  )
              ],
            ),
          ),
        ),
      ],
    );

    return Stack(
      children: stackWidgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color bgColor = const Color(0xFF22304A); // Màu nền xanh đậm
    final String myNumber =
        '0996484060'; // Số của bạn (có thể lấy động nếu cần)
    final String callTime = _callStartTime != null
        ? "${_callStartTime!.hour.toString().padLeft(2, '0')}:${_callStartTime!.minute.toString().padLeft(2, '0')}"
        : '';
    final String remoteNumber = call?.remote_identity ?? '0963998081';
    final String remoteName = 'Không xác định'; // Có thể lấy tên nếu có
    final bool isConnecting = !_callConfirmed;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Header
            Positioned(
              top: 16,
              left: 16,
              child: Row(
                children: [
                  Icon(Icons.phone, color: Colors.white70, size: 18),
                  SizedBox(width: 6),
                  Text(myNumber,
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                ],
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Text('Cuộc gọi đi $callTime',
                  style: TextStyle(color: Colors.white70, fontSize: 15)),
            ),
            // Avatar + tên + số
            Align(
              alignment: Alignment(0, -0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 60),
                  ),
                  SizedBox(height: 18),
                  Text(remoteName,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text(remoteNumber,
                      style: TextStyle(color: Colors.white70, fontSize: 18)),
                ],
              ),
            ),
            // Trạng thái kết nối hoặc thời gian
            Align(
              alignment: Alignment(0, 0.5),
              child: isConnecting
                  ? Text(
                      'Đang kết nối...',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w400),
                    )
                  : ValueListenableBuilder<String>(
                      valueListenable: _timeLabel,
                      builder: (context, value, child) => Text(
                        value,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w400),
                      ),
                    ),
            ),
            // Nút kết thúc cuộc gọi
            Align(
              alignment: Alignment(0, 0.85),
              child: GestureDetector(
                onTap: call != null ? _handleHangup : null,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.call_end, color: Colors.white, size: 36),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void onNewReinvite(ReInvite event) {
    if (event.accept == null) return;
    if (event.reject == null) return;
    if (voiceOnly && (event.hasVideo ?? false)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Upgrade to video?'),
            content: Text('$remoteIdentity is inviting you to video call'),
            alignment: Alignment.center,
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  event.reject!.call({'status_code': 607});
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  event.accept!.call({});
                  setState(() {
                    call!.voiceOnly = false;
                    _resizeLocalVideo();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // NO OP
  }

  @override
  void onNewNotify(Notify ntf) {
    // NO OP
  }

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    if (_talkTimer != null) _talkTimer!.cancel();
    _cleanUp();
    _disposeRenderers();
    super.dispose();
  }
}
