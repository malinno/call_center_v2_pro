import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';
import 'widgets/action_button.dart';

enum Originator {
  local,
  remote,
  system
}

enum Direction {
  incoming,
  outgoing
}

class CallScreenWidget extends StatefulWidget {
  final SIPUAHelper? _helper;
  final Call? _call;

  CallScreenWidget(this._helper, this._call, {Key? key}) : super(key: key);

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

  SIPUAHelper? get helper => widget._helper;

  bool get voiceOnly => call?.voiceOnly == true && call?.remote_has_video != true;

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
    print('CallScreen - initState, call direction: ${call?.direction}');
    _initRenderers();
    helper!.addSipUaHelperListener(this);
    _startTimer();
    _callConfirmed = false;
    _state = CallStateEnum.NONE;
    
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

  @override
  void callStateChanged(Call call, CallState callState) {
    // Nếu là cuộc gọi đến và chưa được xác nhận
    if (call.direction?.toLowerCase() == 'incoming' && !_callConfirmed) {
      switch (callState.state) {
        case CallStateEnum.CALL_INITIATION:
        case CallStateEnum.PROGRESS:
          setState(() {});
          break;
        case CallStateEnum.ENDED:
        case CallStateEnum.FAILED:
          _backToDialPad();
          break;
        default:
          break;
      }
      return;
    }

    // Xử lý các trạng thái khác cho cuộc gọi đã được xác nhận
    if (callState.state == CallStateEnum.HOLD ||
        callState.state == CallStateEnum.UNHOLD) {
      _hold = callState.state == CallStateEnum.HOLD;
      if (callState.originator == 'local') {
        _holdOriginator = Originator.local;
      } else if (callState.originator == 'remote') {
        _holdOriginator = Originator.remote;
      } else if (callState.originator == 'system') {
        _holdOriginator = Originator.system;
      }
      setState(() {});
      return;
    }

    if (callState.state == CallStateEnum.MUTED) {
      if (callState.audio!) _audioMuted = true;
      if (callState.video!) _videoMuted = true;
      setState(() {});
      return;
    }

    if (callState.state == CallStateEnum.UNMUTED) {
      if (callState.audio!) _audioMuted = false;
      if (callState.video!) _videoMuted = false;
      setState(() {});
      return;
    }

    // Cập nhật trạng thái cho cuộc gọi đã được xác nhận
    if (callState.state != CallStateEnum.STREAM) {
      _state = callState.state;
    }

    switch (callState.state) {
      case CallStateEnum.STREAM:
        if (_callConfirmed) {
          _handleStreams(callState);
        }
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _backToDialPad();
        break;
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        if (_callConfirmed) {
          setState(() {});
        }
        break;
      case CallStateEnum.UNMUTED:
      case CallStateEnum.MUTED:
      case CallStateEnum.CONNECTING:
      case CallStateEnum.PROGRESS:
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
      case CallStateEnum.NONE:
      case CallStateEnum.CALL_INITIATION:
      case CallStateEnum.REFER:
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
    if (call != null) {
      call!.hangup({'status_code': 603});
    }
    _timer.cancel();
    
    // Cleanup resources first
    _cleanUp();
    _disposeRenderers();
    
    // Then navigate back to call history
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _backToDialPad() {
    _timer.cancel();
    _cleanUp();
    _disposeRenderers();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _handleStreams(CallState event) async {
    MediaStream? stream = event.stream;
    if (stream == null) return;

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
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = stream;
      }
      _remoteStream = stream;
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
        mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
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
    print('CallScreen - Building action buttons, state: $_state, direction: ${call?.direction}, confirmed: $_callConfirmed');
    
    final hangupBtn = ActionButton(
      title: "hangup",
      onPressed: () => _handleHangup(),
      icon: Icons.call_end,
      fillColor: Colors.red,
    );

    final hangupBtnInactive = ActionButton(
      title: "hangup",
      onPressed: () {},
      icon: Icons.call_end,
      fillColor: Colors.grey,
    );

    final basicActions = <Widget>[];
    final advanceActions = <Widget>[];
    final advanceActions2 = <Widget>[];

    if (call?.direction?.toLowerCase() == 'incoming' && !_callConfirmed) {
      print('CallScreen - Showing accept/reject buttons');
      basicActions.add(ActionButton(
        title: "Accept",
        fillColor: Colors.green,
        icon: Icons.phone,
        onPressed: () => _handleAccept(),
      ));
      basicActions.add(hangupBtn);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: basicActions,
            ),
          ),
        ],
      );
    }

    switch (_state) {
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        {
          advanceActions.add(ActionButton(
            title: _audioMuted ? 'unmute' : 'mute',
            icon: _audioMuted ? Icons.mic_off : Icons.mic,
            checked: _audioMuted,
            onPressed: () => _muteAudio(),
          ));

          if (voiceOnly) {
            advanceActions.add(ActionButton(
              title: "keypad",
              icon: Icons.dialpad,
              onPressed: () => _handleKeyPad(),
            ));
          } else {
            advanceActions.add(ActionButton(
              title: "switch camera",
              icon: Icons.switch_video,
              onPressed: () => _switchCamera(),
            ));
          }

          if (voiceOnly) {
            advanceActions.add(ActionButton(
              title: _speakerOn ? 'speaker off' : 'speaker on',
              icon: _speakerOn ? Icons.volume_off : Icons.volume_up,
              checked: _speakerOn,
              onPressed: () => _toggleSpeaker(),
            ));
            advanceActions2.add(ActionButton(
              title: 'request video',
              icon: Icons.videocam,
              onPressed: () => _handleVideoUpgrade(),
            ));
          } else {
            advanceActions.add(ActionButton(
              title: _videoMuted ? "camera on" : 'camera off',
              icon: _videoMuted ? Icons.videocam : Icons.videocam_off,
              checked: _videoMuted,
              onPressed: () => _muteVideo(),
            ));
          }

          basicActions.add(ActionButton(
            title: _hold ? 'unhold' : 'hold',
            icon: _hold ? Icons.play_arrow : Icons.pause,
            checked: _hold,
            onPressed: () => _handleHold(),
          ));

          basicActions.add(hangupBtn);

          if (_showNumPad) {
            basicActions.add(ActionButton(
              title: "back",
              icon: Icons.keyboard_arrow_down,
              onPressed: () => _handleKeyPad(),
            ));
          } else {
            basicActions.add(ActionButton(
              title: "transfer",
              icon: Icons.phone_forwarded,
              onPressed: () => _handleTransfer(),
            ));
          }
        }
        break;
      case CallStateEnum.FAILED:
      case CallStateEnum.ENDED:
        basicActions.add(hangupBtnInactive);
        break;
      case CallStateEnum.PROGRESS:
        basicActions.add(hangupBtn);
        break;
      default:
        print('Other state => $_state');
        break;
    }

    final actionWidgets = <Widget>[];

    if (_showNumPad) {
      actionWidgets.addAll(_buildNumPad());
    } else {
      if (advanceActions2.isNotEmpty) {
        actionWidgets.add(
          Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: advanceActions2),
          ),
        );
      }
      if (advanceActions.isNotEmpty) {
        actionWidgets.add(
          Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: advanceActions),
          ),
        );
      }
    }

    actionWidgets.add(
      Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: basicActions),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.end,
      children: actionWidgets,
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
    final textColor = Colors.white;
    final bg = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black87, Colors.black54],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: bg,
        child: SafeArea(
          child: Column(
            children: [
              // --- Header: số/tên và trạng thái ---
              SizedBox(height: 40),
              Text(
                remoteIdentity ?? 'Đang kết nối...',
                style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              // Chỉ hiển thị thời gian khi đã accept cuộc gọi
              if (_callConfirmed && call != null)
                ValueListenableBuilder<String>(
                  valueListenable: _timeLabel,
                  builder: (_, val, __) => Text(
                    val,
                    style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 16),
                  ),
                ),
              Spacer(),

              // --- Row nút chức năng: mute, keypad, speaker ---
              if (_callConfirmed && call != null) // Chỉ hiển thị khi đã accept và có call
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCircleButton(
                      icon: _audioMuted ? Icons.mic_off : Icons.mic,
                      label: 'Mute',
                      onTap: _muteAudio,
                    ),
                    _buildCircleButton(
                      icon: Icons.dialpad,
                      label: 'Keypad',
                      onTap: _handleKeyPad,
                    ),
                    _buildCircleButton(
                      icon: _speakerOn ? Icons.volume_up : Icons.hearing,
                      label: 'Speaker',
                      onTap: _toggleSpeaker,
                    ),
                  ],
                ),

              Spacer(),

              // --- Nút Accept/Reject hoặc Hangup ---
              Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (call?.direction?.toLowerCase() == 'incoming' && !_callConfirmed)
                      ...[
                        // Nút Accept
                        GestureDetector(
                          onTap: _handleAccept,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.phone, color: Colors.white, size: 36),
                          ),
                        ),
                        SizedBox(width: 40),
                        // Nút Reject
                        GestureDetector(
                          onTap: _handleHangup,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.call_end, color: Colors.white, size: 36),
                          ),
                        ),
                      ]
                    else
                      // Nút Hangup khi đã accept hoặc là cuộc gọi đi
                      GestureDetector(
                        onTap: call != null ? _handleHangup : null,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.call_end, color: Colors.white, size: 36),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper để tạo nút tròn với icon + label bên dưới
  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
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
    _timer.cancel();
    _cleanUp();
    _disposeRenderers();
    super.dispose();
  }
}