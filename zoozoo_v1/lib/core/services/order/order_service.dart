import '../../models/order_model.dart';
import '../../models/order_status.dart';

/// Abstract order service interface
/// Implementations: MockOrderService, FirebaseOrderService (future)
abstract class OrderService {
  /// Listen for incoming orders (for drivers)
  Stream<Order> listenForOrders();

  /// Accept an order
  Future<Order> acceptOrder(String orderId);

  /// Reject an order
  Future<void> rejectOrder(String orderId);

  /// Update order status
  Future<Order> updateOrderStatus(String orderId, OrderStatus status);

  /// Get current active order (if any)
  Order? get currentOrder;

  /// Cancel listening
  void dispose();
}
