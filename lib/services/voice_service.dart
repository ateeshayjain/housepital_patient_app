import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Abstraction over voice I/O so the provider/executor stay unit-testable
/// without a device (tests provide a lightweight fake instead of extending
/// the plugin-using [PluginVoiceService], whose constructor touches platform
/// channels).
abstract class VoiceService {
  bool get isListening;

  /// Initialise speech recognition. Returns `false` if speech is unavailable
  /// (web, no mic, or permission denied) so the caller falls back to text.
  Future<bool> initSpeech();

  /// Start listening; [onResult] is called with the recognized text.
  Future<void> listen(void Function(String text) onResult,
      {String locale = 'hi_IN'});

  Future<void> stopListening();

  /// Speak [text] aloud.
  Future<void> speak(String text, {String locale = 'hi-IN'});
}

/// Real implementation — thin, isolated wrapper over `speech_to_text`
/// (mic → text) and `flutter_tts` (text → speech).
///
/// ALL platform-plugin calls live ONLY here.
///
/// Web: the voice plugins are limited / unavailable, so every method is
/// `kIsWeb`-guarded — on web the assistant degrades to text-only (acceptable)
/// and the app still builds and runs.
class PluginVoiceService implements VoiceService {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _available = false;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initSpeech() async {
    if (kIsWeb) return false;
    try {
      _available = await _speech.initialize(
        onStatus: (status) {
          _listening = status == 'listening';
        },
        onError: (_) {
          _listening = false;
        },
      );
      return _available;
    } catch (e) {
      debugPrint('VoiceService: initSpeech failed: $e');
      _available = false;
      return false;
    }
  }

  @override
  Future<void> listen(
    void Function(String text) onResult, {
    String locale = 'hi_IN',
  }) async {
    if (kIsWeb || !_available) return;
    try {
      _listening = true;
      await _speech.listen(
        onResult: (result) => onResult(result.recognizedWords),
        listenOptions: SpeechListenOptions(localeId: locale),
      );
    } catch (e) {
      debugPrint('VoiceService: listen failed: $e');
      _listening = false;
    }
  }

  @override
  Future<void> stopListening() async {
    if (kIsWeb) return;
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('VoiceService: stopListening failed: $e');
    } finally {
      _listening = false;
    }
  }

  @override
  Future<void> speak(String text, {String locale = 'hi-IN'}) async {
    if (kIsWeb || text.isEmpty) return;
    try {
      await _tts.setLanguage(locale);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('VoiceService: speak failed: $e');
    }
  }
}

/// A no-op voice service — used where voice is unavailable (e.g. web) or as a
/// safe default. Satisfies the interface without touching platform channels.
class NoopVoiceService implements VoiceService {
  @override
  bool get isListening => false;
  @override
  Future<bool> initSpeech() async => false;
  @override
  Future<void> listen(void Function(String text) onResult,
      {String locale = 'hi_IN'}) async {}
  @override
  Future<void> stopListening() async {}
  @override
  Future<void> speak(String text, {String locale = 'hi-IN'}) async {}
}
