import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/models/order_status.dart';
import '../../../../core/services/order/mock_order_service.dart';
import '../../../../core/services/order/order_storage_service.dart';
import '../data/driver_state.dart';

/// Driver state manager (simplified BLoC pattern)
class DriverBloc extends ChangeNotifier {
  final MockOrderService _orderService;
  final OrderStorageService _storageService;
  
  DriverState _state = const DriverState();
  StreamSubscription<Order>? _orderSubscription;

  DriverBloc({
    MockOrderService? orderService,
    OrderStorageService? storageService,
  })  : _orderService = orderService ?? MockOrderService(),
        _storageService = storageService ?? OrderStorageService();

  /// Current state
  DriverState get state => _state;

  /// Go online
  void goOnline() {
    _state = _state.copyWith(
      status: DriverStatus.online,
      onlineSince: DateTime.now(),
    );
    notifyListeners();

    // Start listening for orders
    _orderService.resume();
    _orderSubscription = _orderService.listenForOrders().listen(_onNewOrder);
  }

  /// Go offline
  void goOffline() {
    _orderSubscription?.cancel();
    _orderService.pause();
    
    _state = _state.copyWith(
      status: DriverStatus.offline,
      clearOrder: true,
      clearOnlineSince: true,
    );
    notifyListeners();
  }

  /// Handle new incoming order
  void _onNewOrder(Order order) {
    if (_state.status == DriverStatus.online) {
      _state = _state.copyWith(
        status: DriverStatus.hasOrder,
        currentOrder: order,
      );
      notifyListeners();
    }
  }

  /// Accept current order
  Future<void> acceptOrder() async {
    if (_state.currentOrder == null) return;

    try {
      final order = await _orderService.acceptOrder(_state.currentOrder!.id);
      _state = _state.copyWith(
        status: DriverStatus.toPickup,
        currentOrder: order,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error accepting order: $e');
    }
  }

  /// Reject current order
  Future<void> rejectOrder() async {
    if (_state.currentOrder == null) return;

    try {
      await _orderService.rejectOrder(_state.currentOrder!.id);
      _state = _state.copyWith(
        status: DriverStatus.online,
        clearOrder: true,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error rejecting order: $e');
    }
  }

  /// Order timed out (no response)
  void orderTimeout() {
    _state = _state.copyWith(
      status: DriverStatus.online,
      clearOrder: true,
    );
    notifyListeners();
  }

  /// Arrived at pickup location
  Future<void> arrivedAtPickup() async {
    if (_state.currentOrder == null) return;

    try {
      final order = await _orderService.updateOrderStatus(
        _state.currentOrder!.id,
        OrderStatus.matched,
      );
      _state = _state.copyWith(
        status: DriverStatus.arrived,
        currentOrder: order,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating status: $e');
    }
  }

  /// Start trip (passenger picked up)
  Future<void> startTrip() async {
    if (_state.currentOrder == null) return;

    try {
      final order = await _orderService.updateOrderStatus(
        _state.currentOrder!.id,
        OrderStatus.inTrip,
      );
      _state = _state.copyWith(
        status: DriverStatus.inTrip,
        currentOrder: order,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error starting trip: $e');
    }
  }

  /// Complete trip
  Future<void> completeTrip() async {
    if (_state.currentOrder == null) return;

    try {
      final completedOrder = await _orderService.updateOrderStatus(
        _state.currentOrder!.id,
        OrderStatus.completed,
      );
      
      // Save to order history
      await _storageService.saveOrder(completedOrder);
      
      _state = _state.copyWith(
        status: DriverStatus.completed,
        currentOrder: completedOrder,
        todayTrips: _state.todayTrips + 1,
        todayEarnings: _state.todayEarnings + completedOrder.price,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error completing trip: $e');
    }
  }

  /// Return to waiting for orders
  void returnToWaiting() {
    _state = _state.copyWith(
      status: DriverStatus.online,
      clearOrder: true,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _orderService.dispose();
    super.dispose();
  }
}
