import 'package:flutter/material.dart';
import '../../../../core/services/voice/voice_assistant_service.dart';

class VoiceReplyDialog extends StatefulWidget {
  final VoidCallback? onDismiss;

  const VoiceReplyDialog({Key? key, this.onDismiss}) : super(key: key);

  @override
  State<VoiceReplyDialog> createState() => _VoiceReplyDialogState();
}

class _VoiceReplyDialogState extends State<VoiceReplyDialog> {
  final VoiceAssistantService _voiceAssistant = VoiceAssistantService();
  String _statusText = "Listening...";
  String _recognizedText = "";

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  Future<void> _startListening() async {
    await _voiceAssistant.listen(onResult: (text) {
      if (mounted) {
        setState(() {
          _recognizedText = text;
          _statusText = "Sending reply...";
        });
        
        // Simulate sending reply
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
            widget.onDismiss?.call();
          }
        });
      }
    });

    if (!_voiceAssistant.isListening && _recognizedText.isEmpty && mounted) {
        // Fallback if permission denied or error
         setState(() {
            _statusText = "Tap to speak";
         });
    }
  }
  
  void _retryListening() {
      setState(() {
          _statusText = "Listening...";
      });
      _startListening();
  }

  @override
  void dispose() {
    _voiceAssistant.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mic, size: 48, color: Colors.blueAccent),
            const SizedBox(height: 16),
            Text(
              _statusText,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (_recognizedText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '"$_recognizedText"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
            ],
             if (_statusText == "Tap to speak") ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _retryListening,
                  child: const Text("Start Recording"),
                )
            ]
          ],
        ),
      ),
    );
  }
}
