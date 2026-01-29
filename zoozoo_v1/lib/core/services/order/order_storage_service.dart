import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/driver_order_history.dart';
import '../../models/order_model.dart';

/// Service for managing driver order history storage
/// Uses shared_preferences to persist completed orders locally
class OrderStorageService {
  static const String _storageKey = 'driver_order_history';
  static const int _maxHistoryCount = 50;

  /// Save a completed order to history
  /// Automatically converts Order to DriverOrderHistory
  Future<void> saveOrder(Order order) async {
    final history = DriverOrderHistory(
      orderId: order.id,
      passengerId: order.passenger.id,
      passengerName: order.passenger.name,
      pickupAddress: order.pickupAddress,
      destinationAddress: order.destinationAddress,
      price: order.price,
      distance: order.distance,
      completedAt: DateTime.now(),
    );

    await saveOrderHistory(history);
  }

  /// Save a DriverOrderHistory directly
  Future<void> saveOrderHistory(DriverOrderHistory history) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing history
    final historyList = await getOrderHistory();
    
    // Add new order at the beginning (most recent first)
    historyList.insert(0, history);
    
    // Limit to max count
    if (historyList.length > _maxHistoryCount) {
      historyList.removeRange(_maxHistoryCount, historyList.length);
    }
    
    // Convert to JSON and save
    final jsonList = historyList.map((h) => h.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_storageKey, jsonString);
  }

  /// Get all order history (sorted by most recent first)
  Future<List<DriverOrderHistory>> getOrderHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => DriverOrderHistory.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If parsing fails, return empty list and clear corrupted data
      await clearHistory();
      return [];
    }
  }

  /// Delete a specific order from history
  Future<void> deleteOrder(String orderId) async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = await getOrderHistory();
    
    // Remove the order with matching ID
    historyList.removeWhere((h) => h.orderId == orderId);
    
    // Save updated list
    final jsonList = historyList.map((h) => h.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await prefs.setString(_storageKey, jsonString);
  }

  /// Clear all order history
  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Get total number of orders in history
  Future<int> getHistoryCount() async {
    final history = await getOrderHistory();
    return history.length;
  }

  /// Get total earnings from history
  Future<int> getTotalEarnings() async {
    final history = await getOrderHistory();
    return history.fold<int>(0, (sum, order) => sum + order.price);
  }

  /// Get total distance from history
  Future<double> getTotalDistance() async {
    final history = await getOrderHistory();
    return history.fold<double>(0.0, (sum, order) => sum + order.distance);
  }
}
