import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/models/chat_message.dart';
import '../../../../../core/services/chat_storage_service.dart';

class DriverChatPage extends StatefulWidget {
  final String? passengerName;

  const DriverChatPage({super.key, this.passengerName});

  @override
  State<DriverChatPage> createState() => _DriverChatPageState();
}

class _DriverChatPageState extends State<DriverChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ChatStorageService _storageService = ChatStorageService();
  bool _isLoading = true;
  String? _currentOrderId;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Load messages from local storage for current order
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    // Get current order ID
    _currentOrderId = await _storageService.getCurrentOrderId();

    if (_currentOrderId == null) {
      // No active order, show empty state
      setState(() => _isLoading = false);
      return;
    }

    final messages = await _storageService.loadMessages(_currentOrderId!);
    setState(() {
      _messages.clear();
      _messages.addAll(messages);
      _isLoading = false;
    });
  }

  /// Send a text message
  void _sendTextMessage() async {
    if (_controller.text.trim().isEmpty) return;

    // Get current order ID
    _currentOrderId ??= await _storageService.getCurrentOrderId();
    if (_currentOrderId == null) return;

    final message = ChatMessage.text(
      content: _controller.text.trim(),
      sender: MessageSender.driver,
    );

    setState(() {
      _messages.add(message);
    });

    // Save to local storage for this order
    await _storageService.saveMessages(_messages, _currentOrderId!);

    _controller.clear();
  }

  /// Add a voice message (to be called when voice message is received or sent)
  void _addVoiceMessage({
    required String transcribedText,
    required String voiceFilePath,
    required MessageSender sender,
  }) async {
    // Get current order ID
    _currentOrderId ??= await _storageService.getCurrentOrderId();
    if (_currentOrderId == null) return;

    final message = ChatMessage.voice(
      transcribedText: transcribedText,
      voiceFilePath: voiceFilePath,
      sender: sender,
    );

    setState(() {
      _messages.add(message);
    });

    // Save to local storage for this order
    await _storageService.saveMessages(_messages, _currentOrderId!);
  }

  /// Simulate receiving a passenger voice message (for demo purposes)
  void _simulatePassengerVoiceMessage() {
    _addVoiceMessage(
      transcribedText: "請問還有多久會到？",
      voiceFilePath: "/path/to/voice/recording.m4a",
      sender: MessageSender.passenger,
    );
  }

  /// Simulate driver voice reply (for demo purposes)
  void _simulateDriverVoiceReply() {
    _addVoiceMessage(
      transcribedText: "大約還有五分鐘就到了",
      voiceFilePath: "/path/to/voice/reply.m4a",
      sender: MessageSender.driver,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.passengerName != null && widget.passengerName!.isNotEmpty
              ? '${widget.passengerName![0]}先生'
              : '先生',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            '尚無訊息',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            return _buildMessageBubble(message);
                          },
                        ),
                ),
                _buildMessageInput(),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isDriver = message.sender == MessageSender.driver;
    final isVoice = message.type == MessageType.voice;

    return Align(
      alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isDriver ? AppColors.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Voice indicator
            if (isVoice)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mic,
                      size: 16,
                      color: isDriver ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '語音訊息',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDriver ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            // Message content (transcribed text for voice messages)
            Text(
              message.content,
              style: TextStyle(
                color: isDriver ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),

            // Timestamp
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: TextStyle(
                fontSize: 10,
                color: isDriver ? Colors.white60 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "輸入訊息...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendTextMessage(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _sendTextMessage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return '剛剛';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分鐘前';
    } else if (difference.inDays < 1) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
