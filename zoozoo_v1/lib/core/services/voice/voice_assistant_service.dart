import 'dart:async';
import 'dart:io';
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
    if (Platform.isIOS) {
      // Configure for background playback and mixing
      // mixWithOthers allows it to play over other audio (or duck them) without crashing
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    }
    await _flutterTts.setLanguage("zh-TW");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    // Important: Wait for speak completion to handle sequential flow (Speak -> Notify)
    await _flutterTts.awaitSpeakCompletion(true);
  }

  /// Prepare audio session for background usage (call this before speaking if app might be in background)
  Future<void> prepareForBackgroundSpeak() async {
     if (Platform.isIOS) {
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    }
  }

  Future<void> speak(String message) async {
    if (message.isEmpty) return;
    debugPrint('VoiceAssistant: Speaking "$message"');
    // Ensure we stop any previous speech
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
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speechToText.stop();
      _isListening = false;
    }
  }
}
