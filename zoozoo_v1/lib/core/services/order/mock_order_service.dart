import 'dart:async';

import '../../models/order_model.dart';
import '../../models/order_status.dart';
import 'order_service.dart';

/// Mock implementation of OrderService
/// Generates fake orders for testing
class MockOrderService implements OrderService {
  /// Order generation interval in seconds
  final int intervalSeconds;
  
  Timer? _timer;
  final _orderController = StreamController<Order>.broadcast();
  Order? _currentOrder;
  bool _isListening = false;

  MockOrderService({this.intervalSeconds = 15});

  @override
  Stream<Order> listenForOrders() {
    if (!_isListening) {
      _startGeneratingOrders();
      _isListening = true;
    }
    return _orderController.stream;
  }

  void _startGeneratingOrders() {
    // Generate first order after a short delay
    Future.delayed(Duration(seconds: 3), () {
      if (_isListening && _currentOrder == null) {
        _generateOrder();
      }
    });

    // Then generate orders periodically
    _timer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      if (_currentOrder == null) {
        _generateOrder();
      }
    });
  }

  void _generateOrder() {
    final order = Order.mock();
    _orderController.add(order);
  }

  @override
  Future<Order> acceptOrder(String orderId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // In real app, this would update the database
    // For mock, we just create an updated order
    final order = Order.mock().copyWith(status: OrderStatus.matched);
    _currentOrder = order;
    return order;
  }

  @override
  Future<void> rejectOrder(String orderId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    _currentOrder = null;
  }

  @override
  Future<Order> updateOrderStatus(String orderId, OrderStatus status) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_currentOrder != null) {
      _currentOrder = _currentOrder!.copyWith(status: status);
      
      // Clear current order if completed or cancelled
      if (status == OrderStatus.completed || status == OrderStatus.cancelled) {
        final completedOrder = _currentOrder!;
        _currentOrder = null;
        return completedOrder;
      }
      
      return _currentOrder!;
    }
    
    throw Exception('No current order');
  }

  @override
  Order? get currentOrder => _currentOrder;

  /// Pause order generation (when driver goes offline)
  void pause() {
    _timer?.cancel();
    _timer = null;
    _isListening = false;
  }

  /// Resume order generation (when driver goes online)
  void resume() {
    if (!_isListening) {
      _startGeneratingOrders();
      _isListening = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _orderController.close();
    _isListening = false;
  }
}
