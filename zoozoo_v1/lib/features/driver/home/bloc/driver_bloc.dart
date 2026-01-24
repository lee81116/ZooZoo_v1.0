import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/models/order_model.dart';
import '../../../../core/models/order_status.dart';
import '../../../../core/services/order/mock_order_service.dart';
import '../../../../core/services/order/order_storage_service.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/services/voice/voice_assistant_service.dart';
import '../../../../core/services/notification/notification_service.dart';
import '../data/driver_state.dart';

/// Driver state manager (simplified BLoC pattern)
class DriverBloc extends ChangeNotifier {
  final MockOrderService _orderService;
  final OrderStorageService _storageService;
  final VoiceAssistantService _voiceService;
  final NotificationService _notificationService;
  
  DriverState _state = const DriverState();
  StreamSubscription<Order>? _orderSubscription;
  StreamSubscription<Position>? _locationSubscription;

  DriverBloc({
    MockOrderService? orderService,
    OrderStorageService? storageService,
    VoiceAssistantService? voiceService,
    NotificationService? notificationService,
  })  : _orderService = orderService ?? MockOrderService(),
        _storageService = storageService ?? OrderStorageService(),
        _voiceService = voiceService ?? VoiceAssistantService(),
        _notificationService = notificationService ?? NotificationService();

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

    // Start background location updates (Green Bar)
    _startLocationUpdates();
  }

  /// Go offline
  void goOffline() {
    _orderSubscription?.cancel();
    _stopLocationUpdates();
    _orderService.pause();
    _voiceService.stopSpeaking();
    
    _state = _state.copyWith(
      status: DriverStatus.offline,
      clearOrder: true,
      clearOnlineSince: true,
    );
    notifyListeners();
  }

  /// Toggle mute status
  void toggleMute() {
    _state = _state.copyWith(isMuted: !_state.isMuted);
    notifyListeners();
  }

  /// Toggle notification status
  void toggleNotifications() {
    _state = _state.copyWith(areNotificationsEnabled: !_state.areNotificationsEnabled);
    notifyListeners();
  }

  /// Handle new incoming order
  Future<void> _onNewOrder(Order order) async {
    if (_state.status == DriverStatus.online) {
      _state = _state.copyWith(
        status: DriverStatus.hasOrder,
        currentOrder: order,
      );
      notifyListeners();

      // 1. Voice Announcement
      if (!_state.isMuted) {
        await _voiceService.prepareForBackgroundSpeak();
        // Await speak completion
        await _voiceService.speak("收到新訂單，從${order.pickupAddress}到${order.destinationAddress}，請問要接單嗎？");
      }

      // 2. Notification (After voice or immediately if muted)
      if (_state.areNotificationsEnabled) {
        await _notificationService.showOrderNotification(
          id: order.id.hashCode,
          title: '收到新訂單！',
          body: '從 ${order.pickupAddress} 到 ${order.destinationAddress}',
          payload: order.id,
        );
      }
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
    _stopLocationUpdates();
    _orderService.dispose();
    super.dispose();
  }

  void _startLocationUpdates() {
    _stopLocationUpdates();

    LocationSettings locationSettings;
    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true, // This enables the green bar/pill
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      );
    }

    _locationSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      // Keep alive logic
      debugPrint('[Location Update] Lat: ${position.latitude}, Lng: ${position.longitude}');
    }, onError: (e) {
      debugPrint('[Location Error] $e');
    });
  }

  void _stopLocationUpdates() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }
}
