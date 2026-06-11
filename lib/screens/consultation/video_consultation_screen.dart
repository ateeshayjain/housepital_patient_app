// lib/screens/consultation/video_consultation_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/app_colors.dart';
import '../../services/video_call_service.dart';
import '../../widgets/common_widgets.dart';

/// Video Consultation screen — UI shell ready for Agora/WebRTC integration.
///
/// States:
///   - pre_call:  Shows doctor info + "Connecting..." overlay
///   - in_call:   Live video area + controls bar
///   - post_call: Summary with rating & prescription link
enum _CallState { preCall, inCall, postCall }

class VideoConsultationScreen extends StatefulWidget {
  final String doctorName;
  final String? doctorPhotoUrl;
  final String? roomId;
  final String? token;

  const VideoConsultationScreen({
    super.key,
    required this.doctorName,
    this.doctorPhotoUrl,
    this.roomId,
    this.token,
  });

  @override
  State<VideoConsultationScreen> createState() =>
      _VideoConsultationScreenState();
}

class _VideoConsultationScreenState extends State<VideoConsultationScreen> {
  final VideoCallService _callService = VideoCallService();

  _CallState _state = _CallState.preCall;
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _showChat = false;
  int _rating = 0;

  // Call duration timer
  Timer? _timer;
  int _durationSeconds = 0;

  @override
  void initState() {
    super.initState();
    // Auto-connect after 2s to simulate connection
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _startCall();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_callService.isInCall) {
      _callService.leaveRoom();
    }
    super.dispose();
  }

  Future<void> _startCall() async {
    await _callService.joinRoom(
      widget.roomId ?? 'demo-room',
      widget.token ?? '',
    );
    if (!mounted) return;
    setState(() => _state = _CallState.inCall);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _durationSeconds++);
    });
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    await _callService.leaveRoom();
    if (mounted) setState(() => _state = _CallState.postCall);
  }

  String get _formattedDuration {
    final m = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.hc.background,
      body: SafeArea(
        child: switch (_state) {
          _CallState.preCall => _buildPreCall(),
          _CallState.inCall => _buildInCall(),
          _CallState.postCall => _buildPostCall(),
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRE-CALL: Doctor info + "Connecting..."
  // ---------------------------------------------------------------------------
  Widget _buildPreCall() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: HousepitalColors.orange,
            backgroundImage: widget.doctorPhotoUrl != null
                ? NetworkImage(widget.doctorPhotoUrl!)
                : null,
            child: widget.doctorPhotoUrl == null
                ? Text(
                    widget.doctorName
                        .split(' ')
                        .map((n) => n[0])
                        .take(2)
                        .join(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 20),
          Text(
            widget.doctorName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HousepitalColors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Connecting...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.hc.error, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // IN-CALL: Video areas + controls
  // ---------------------------------------------------------------------------
  Widget _buildInCall() {
    return Stack(
      children: [
        // Remote video placeholder (full screen)
        Container(
          color: context.hc.white,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person, color: Colors.white24, size: 120),
                SizedBox(height: 8),
                Text(
                  'Remote Video',
                  style: TextStyle(color: Colors.white24, fontSize: 14),
                ),
              ],
            ),
          ),
        ),

        // Local video thumbnail (top right)
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            width: 100,
            height: 140,
            decoration: BoxDecoration(
              color: _isCameraOn
                  ? context.hc.greyLighter
                  : Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: HousepitalColors.orange, width: 2),
            ),
            child: Center(
              child: _isCameraOn
                  ? const Icon(Icons.videocam,
                      color: Colors.white38, size: 36)
                  : const Icon(Icons.videocam_off,
                      color: Colors.white38, size: 36),
            ),
          ),
        ),

        // Duration timer (top center)
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formattedDuration,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),

        // Doctor name (top left)
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.doctorName,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ),

        // In-call chat overlay (simple placeholder)
        if (_showChat)
          Positioned(
            bottom: 100,
            left: 16,
            right: 16,
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text(
                    'In-Call Chat',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  Spacer(),
                  Text(
                    'Chat messages will appear here',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),

        // Controls bar (bottom)
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute mic toggle
              _controlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Unmute' : 'Mute',
                isActive: _isMuted,
                onTap: () {
                  _callService.toggleMute();
                  setState(() => _isMuted = _callService.isMuted);
                },
              ),

              // Camera toggle
              _controlButton(
                icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                label: _isCameraOn ? 'Cam On' : 'Cam Off',
                isActive: !_isCameraOn,
                onTap: () {
                  _callService.toggleCamera();
                  setState(() => _isCameraOn = _callService.isCameraOn);
                },
              ),

              // End Call (red)
              GestureDetector(
                onTap: _endCall,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: context.hc.error,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_end,
                      color: Colors.white, size: 30),
                ),
              ),

              // Chat toggle
              _controlButton(
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
                isActive: _showChat,
                onTap: () => setState(() => _showChat = !_showChat),
              ),

              // Switch camera
              _controlButton(
                icon: Icons.flip_camera_ios,
                label: 'Flip',
                onTap: () => _callService.switchCamera(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // POST-CALL: Summary with rate + prescription
  // ---------------------------------------------------------------------------
  Widget _buildPostCall() {
    return Scaffold(
      backgroundColor: context.hc.background,
      appBar: AppBar(
        title: const Text('Consultation Complete'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Doctor card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: HousepitalColors.orange,
                      backgroundImage: widget.doctorPhotoUrl != null
                          ? NetworkImage(widget.doctorPhotoUrl!)
                          : null,
                      child: widget.doctorPhotoUrl == null
                          ? Text(
                              widget.doctorName
                                  .split(' ')
                                  .map((n) => n[0])
                                  .take(2)
                                  .join(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.doctorName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Duration: $_formattedDuration',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.hc.greyLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.check_circle,
                        color: context.hc.success, size: 32),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Rate Doctor
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Rate your consultation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Shared accessible star rater (44pt targets + per-star
                    // Semantics) — replaces a bare GestureDetector row.
                    StarRatingInput(
                      value: _rating,
                      onChanged: (stars) => setState(() => _rating = stars),
                      size: 36,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  // FUTURE: Submit rating via API and navigate to prescription
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.star),
                label: const Text('Rate Doctor'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  // FUTURE: Navigate to prescription viewer once documents module is ready
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.description),
                label: const Text('View Prescription'),
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}
