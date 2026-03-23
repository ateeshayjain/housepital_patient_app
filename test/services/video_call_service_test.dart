import 'package:flutter_test/flutter_test.dart';
import 'package:housepital_patient/services/video_call_service.dart';

void main() {
  late VideoCallService service;

  setUp(() {
    service = VideoCallService();
  });

  group('VideoCallService', () {
    test('initial state: not in call, not muted, camera on', () {
      expect(service.isInCall, isFalse);
      expect(service.isMuted, isFalse);
      expect(service.isCameraOn, isTrue);
    });

    test('toggleMute() flips isMuted', () {
      expect(service.isMuted, isFalse);
      service.toggleMute();
      expect(service.isMuted, isTrue);
      service.toggleMute();
      expect(service.isMuted, isFalse);
    });

    test('toggleCamera() flips isCameraOn', () {
      expect(service.isCameraOn, isTrue);
      service.toggleCamera();
      expect(service.isCameraOn, isFalse);
      service.toggleCamera();
      expect(service.isCameraOn, isTrue);
    });

    test('joinRoom() sets isInCall to true and resets mute/camera', () async {
      service.toggleMute(); // muted = true
      service.toggleCamera(); // camera = false

      await service.joinRoom('room1', 'token1');

      expect(service.isInCall, isTrue);
      expect(service.isMuted, isFalse);
      expect(service.isCameraOn, isTrue);
    });

    test('leaveRoom() sets isInCall to false and resets state', () async {
      await service.joinRoom('room1', 'token1');
      service.toggleMute();

      await service.leaveRoom();

      expect(service.isInCall, isFalse);
      expect(service.isMuted, isFalse);
      expect(service.isCameraOn, isTrue);
    });

    test('multiple toggles work correctly', () {
      service.toggleMute();
      service.toggleMute();
      service.toggleMute();
      expect(service.isMuted, isTrue);

      service.toggleCamera();
      service.toggleCamera();
      service.toggleCamera();
      expect(service.isCameraOn, isFalse);
    });
  });
}
