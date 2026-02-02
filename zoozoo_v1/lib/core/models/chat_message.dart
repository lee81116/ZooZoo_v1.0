import 'package:flutter/foundation.dart';

/// Message type enum
enum MessageType {
  text,
  voice,
}

/// Message sender enum
enum MessageSender {
  driver,
  passenger,
}

/// Chat message model
@immutable
class ChatMessage {
  final String id;
  final String content; // For text: actual text. For voice: transcribed text
  final MessageType type;
  final MessageSender sender;
  final DateTime timestamp;
  final String? voiceFilePath; // Optional: path to voice recording file

  const ChatMessage({
    required this.id,
    required this.content,
    required this.type,
    required this.sender,
    required this.timestamp,
    this.voiceFilePath,
  });

  /// Create a text message
  factory ChatMessage.text({
    required String content,
    required MessageSender sender,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: MessageType.text,
      sender: sender,
      timestamp: DateTime.now(),
    );
  }

  /// Create a voice message
  factory ChatMessage.voice({
    required String transcribedText,
    required String voiceFilePath,
    required MessageSender sender,
  }) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: transcribedText,
      type: MessageType.voice,
      sender: sender,
      timestamp: DateTime.now(),
      voiceFilePath: voiceFilePath,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.index,
      'sender': sender.index,
      'timestamp': timestamp.toIso8601String(),
      'voiceFilePath': voiceFilePath,
    };
  }

  /// Create from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      type: MessageType.values[json['type'] as int],
      sender: MessageSender.values[json['sender'] as int],
      timestamp: DateTime.parse(json['timestamp'] as String),
      voiceFilePath: json['voiceFilePath'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ChatMessage(id: $id, content: $content, type: $type, sender: $sender, timestamp: $timestamp)';
  }
}
