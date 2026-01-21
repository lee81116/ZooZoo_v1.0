import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceAssistantService {
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  
  bool _isListening = false;
  bool get isListening => _isListening;
  
  VoiceAssistantService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("zh-TW");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> speak(String message) async {
    if (message.isEmpty) return;
    debugPrint('VoiceAssistant: Speaking "$message"');
    await _flutterTts.stop();
    await _flutterTts.speak(message);
  }

  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
  }

  Future<void> listen({
    required Function(String) onResult,
    Duration listenFor = const Duration(seconds: 5),
  }) async {
    if (_isListening) return;

    // Check permissions
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('VoiceAssistant: Microphone permission denied');
        return;
      }
    }

    bool available = await _speechToText.initialize(
      onError: (val) => debugPrint('VoiceAssistant: Error $val'),
      onStatus: (val) {
        debugPrint('VoiceAssistant: Status $val');
        if (val == 'done' || val == 'notListening') {
          _isListening = false;
        }
      },
    );

    if (available) {
      _isListening = true;
      _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) {
             debugPrint('VoiceAssistant: Heard "${result.recognizedWords}"');
             onResult(result.recognizedWords);
             _isListening = false;
             _speechToText.stop();
          }
        },
        localeId: "zh-TW",
        listenFor: listenFor,
        pauseFor: const Duration(seconds: 2),
      );
    } else {
      debugPrint('VoiceAssistant: Speech recognition not available');
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }
}
