import 'package:flutter/material.dart';

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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 50),
            CircleAvatar(
              radius: 50,
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
                  color: Colors.red,
                  onPressed: () {
                    widget.onCallEnded(true);
                    Navigator.of(context).pop();
                  },
                ),
                _buildCallButton(
                  icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
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
    required VoidCallback onPressed,
    Color color = Colors.white,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: color,
          child: Icon(icon),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
} 