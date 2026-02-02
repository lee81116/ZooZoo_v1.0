import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';

/// Service for persisting chat messages locally
/// Each order has its own chat room identified by orderId
class ChatStorageService {
  static const String _messagesKeyPrefix = 'chat_messages_';
  static const String _currentOrderKey = 'current_order_id';

  /// Save messages for a specific order
  Future<void> saveMessages(List<ChatMessage> messages, String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = messages.map((msg) => msg.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      await prefs.setString('$_messagesKeyPrefix$orderId', jsonString);
    } catch (e) {
      print('Error saving messages for order $orderId: $e');
    }
  }

  /// Load messages for a specific order
  Future<List<ChatMessage>> loadMessages(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('$_messagesKeyPrefix$orderId');

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading messages for order $orderId: $e');
      return [];
    }
  }

  /// Clear messages for a specific order
  Future<void> clearMessages(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_messagesKeyPrefix$orderId');
    } catch (e) {
      print('Error clearing messages for order $orderId: $e');
    }
  }

  /// Set the current active order ID
  Future<void> setCurrentOrderId(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentOrderKey, orderId);
    } catch (e) {
      print('Error setting current order ID: $e');
    }
  }

  /// Get the current active order ID
  Future<String?> getCurrentOrderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currentOrderKey);
    } catch (e) {
      print('Error getting current order ID: $e');
      return null;
    }
  }

  /// Clear the current order ID
  Future<void> clearCurrentOrderId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentOrderKey);
    } catch (e) {
      print('Error clearing current order ID: $e');
    }
  }

  /// Add a single message to a specific order's chat and save
  Future<void> addMessage(ChatMessage message, String orderId) async {
    final messages = await loadMessages(orderId);
    messages.add(message);
    await saveMessages(messages, orderId);
  }

  /// Get all order IDs that have chat messages
  Future<List<String>> getAllOrderIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      return allKeys
          .where((key) => key.startsWith(_messagesKeyPrefix))
          .map((key) => key.replaceFirst(_messagesKeyPrefix, ''))
          .toList();
    } catch (e) {
      print('Error getting all order IDs: $e');
      return [];
    }
  }
}
