import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

class CallScreen extends StatefulWidget {
  final String callerName;
  final String callerId;
  final String? avatar;
  final bool isIncoming;
  final Function(bool) onCallEnded;

  const CallScreen({
    Key? key,
    required this.callerName,
    required this.callerId,
    this.avatar,
    required this.isIncoming,
    required this.onCallEnded,
  }) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),
            CircleAvatar(
              radius: 60,
              backgroundImage: widget.avatar != null
                  ? NetworkImage(widget.avatar!)
                  : null,
              child: widget.avatar == null
                  ? Text(
                      widget.callerName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              widget.callerName,
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.isIncoming ? 'Incoming call...' : 'Calling...',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  label: _isMuted ? 'Unmute' : 'Mute',
                  onPressed: () {
                    setState(() {
                      _isMuted = !_isMuted;
                    });
                  },
                ),
                _buildCallButton(
                  icon: Icons.call_end,
                  label: 'End',
                  backgroundColor: Colors.red,
                  onPressed: () {
                    widget.onCallEnded(true);
                    Navigator.pop(context);
                  },
                ),
                _buildCallButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                  label: _isSpeakerOn ? 'Speaker Off' : 'Speaker On',
                  onPressed: () {
                    setState(() {
                      _isSpeakerOn = !_isSpeakerOn;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required String label,
    Color backgroundColor = Colors.white24,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: backgroundColor,
          child: IconButton(
            icon: Icon(icon),
            color: Colors.white,
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
} 