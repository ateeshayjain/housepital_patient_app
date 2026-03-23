// lib/services/video_call_service.dart
//
// Stub service for video consultation.
// Ready to plug in Agora SDK or WebRTC once API keys are available.

class VideoCallService {
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _isInCall = false;

  bool get isMuted => _isMuted;
  bool get isCameraOn => _isCameraOn;
  bool get isInCall => _isInCall;

  /// Join a video call room.
  ///
  /// TODO: Integrate Agora SDK or WebRTC here.
  /// For Agora:
  ///   1. Add `agora_rtc_engine` to pubspec.yaml
  ///   2. Initialize AgoraRtcEngine with your App ID
  ///   3. Call engine.joinChannel(token, channelName, uid: 0)
  ///   4. Set up event handlers for onJoinChannelSuccess, onUserJoined, etc.
  ///
  /// For WebRTC:
  ///   1. Add `flutter_webrtc` to pubspec.yaml
  ///   2. Create RTCPeerConnection with STUN/TURN servers
  ///   3. Get local media stream via navigator.mediaDevices.getUserMedia()
  ///   4. Connect to signaling server and exchange SDP offers/answers
  Future<void> joinRoom(String roomId, String token) async {
    // TODO: Replace with actual SDK join call
    _isInCall = true;
    _isMuted = false;
    _isCameraOn = true;
  }

  /// Leave the current video call room.
  ///
  /// TODO: Integrate Agora SDK or WebRTC here.
  /// For Agora:
  ///   1. Call engine.leaveChannel()
  ///   2. Dispose of the engine if no longer needed
  ///
  /// For WebRTC:
  ///   1. Close the RTCPeerConnection
  ///   2. Stop all local media tracks
  ///   3. Disconnect from the signaling server
  Future<void> leaveRoom() async {
    // TODO: Replace with actual SDK leave call
    _isInCall = false;
    _isMuted = false;
    _isCameraOn = true;
  }

  /// Toggle the microphone mute state.
  ///
  /// TODO: Integrate Agora SDK or WebRTC here.
  /// For Agora:
  ///   engine.muteLocalAudioStream(!_isMuted)
  ///
  /// For WebRTC:
  ///   localStream.getAudioTracks().first.enabled = _isMuted (toggle)
  void toggleMute() {
    // TODO: Replace with actual SDK mute call
    _isMuted = !_isMuted;
  }

  /// Toggle the camera on/off.
  ///
  /// TODO: Integrate Agora SDK or WebRTC here.
  /// For Agora:
  ///   engine.muteLocalVideoStream(!_isCameraOn)
  ///
  /// For WebRTC:
  ///   localStream.getVideoTracks().first.enabled = !_isCameraOn
  void toggleCamera() {
    // TODO: Replace with actual SDK camera toggle call
    _isCameraOn = !_isCameraOn;
  }

  /// Switch between front and rear camera.
  ///
  /// TODO: Integrate Agora SDK or WebRTC here.
  /// For Agora:
  ///   engine.switchCamera()
  ///
  /// For WebRTC:
  ///   1. Stop existing video track
  ///   2. Get new stream with opposite facingMode
  ///   3. Replace track on RTCPeerConnection sender
  Future<void> switchCamera() async {
    // TODO: Replace with actual SDK switch camera call
  }
}
