// This is a test file for the order storage service. Currently just for fun.


import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zoozoo_v1/core/models/driver_order_history.dart';
import 'package:zoozoo_v1/core/models/order_model.dart';
import 'package:zoozoo_v1/core/services/order/order_storage_service.dart';

void main() {
  group('DriverOrderHistory', () {
    test('toJson and fromJson should work correctly', () {
      final history = DriverOrderHistory(
        orderId: 'order_123',
        passengerId: 'passenger_456',
        passengerName: '王小明',
        pickupAddress: '台北車站',
        destinationAddress: '台北101',
        price: 250,
        distance: 5.5,
        completedAt: DateTime(2024, 1, 20, 14, 30),
      );

      final json = history.toJson();
      final restored = DriverOrderHistory.fromJson(json);

      expect(restored.orderId, history.orderId);
      expect(restored.passengerId, history.passengerId);
      expect(restored.passengerName, history.passengerName);
      expect(restored.pickupAddress, history.pickupAddress);
      expect(restored.destinationAddress, history.destinationAddress);
      expect(restored.price, history.price);
      expect(restored.distance, history.distance);
      expect(restored.completedAt, history.completedAt);
    });
  });

  group('OrderStorageService', () {
    late OrderStorageService storageService;

    setUp(() async {
      // Initialize with empty preferences
      SharedPreferences.setMockInitialValues({});
      storageService = OrderStorageService();
    });

    test('should save and retrieve order history', () async {
      final history = DriverOrderHistory(
        orderId: 'order_1',
        passengerId: 'passenger_1',
        passengerName: '李美麗',
        pickupAddress: '西門町',
        destinationAddress: '信義威秀',
        price: 180,
        distance: 3.2,
        completedAt: DateTime.now(),
      );

      await storageService.saveOrderHistory(history);
      final retrieved = await storageService.getOrderHistory();

      expect(retrieved.length, 1);
      expect(retrieved.first.orderId, 'order_1');
      expect(retrieved.first.passengerName, '李美麗');
    });

    test('should save from Order model', () async {
      final order = Order.mock();
      
      await storageService.saveOrder(order);
      final retrieved = await storageService.getOrderHistory();

      expect(retrieved.length, 1);
      expect(retrieved.first.orderId, order.id);
      expect(retrieved.first.passengerName, order.passenger.name);
      expect(retrieved.first.price, order.price);
    });

    test('should maintain order by most recent first', () async {
      final history1 = DriverOrderHistory(
        orderId: 'order_1',
        passengerId: 'passenger_1',
        passengerName: '第一筆',
        pickupAddress: 'A',
        destinationAddress: 'B',
        price: 100,
        distance: 1.0,
        completedAt: DateTime(2024, 1, 20, 10, 0),
      );

      final history2 = DriverOrderHistory(
        orderId: 'order_2',
        passengerId: 'passenger_2',
        passengerName: '第二筆',
        pickupAddress: 'C',
        destinationAddress: 'D',
        price: 200,
        distance: 2.0,
        completedAt: DateTime(2024, 1, 20, 11, 0),
      );

      await storageService.saveOrderHistory(history1);
      await storageService.saveOrderHistory(history2);

      final retrieved = await storageService.getOrderHistory();

      expect(retrieved.length, 2);
      expect(retrieved[0].orderId, 'order_2'); // Most recent first
      expect(retrieved[1].orderId, 'order_1');
    });

    test('should limit history to 50 orders', () async {
      // Add 60 orders
      for (int i = 0; i < 60; i++) {
        final history = DriverOrderHistory(
          orderId: 'order_$i',
          passengerId: 'passenger_$i',
          passengerName: '乘客 $i',
          pickupAddress: '起點 $i',
          destinationAddress: '終點 $i',
          price: 100 + i,
          distance: 1.0 + i,
          completedAt: DateTime.now().add(Duration(minutes: i)),
        );
        await storageService.saveOrderHistory(history);
      }

      final retrieved = await storageService.getOrderHistory();

      expect(retrieved.length, 50); // Should be limited to 50
      expect(retrieved.first.orderId, 'order_59'); // Most recent
      expect(retrieved.last.orderId, 'order_10'); // Oldest kept
    });

    test('should delete specific order', () async {
      final history1 = DriverOrderHistory(
        orderId: 'order_1',
        passengerId: 'passenger_1',
        passengerName: '訂單1',
        pickupAddress: 'A',
        destinationAddress: 'B',
        price: 100,
        distance: 1.0,
        completedAt: DateTime.now(),
      );

      final history2 = DriverOrderHistory(
        orderId: 'order_2',
        passengerId: 'passenger_2',
        passengerName: '訂單2',
        pickupAddress: 'C',
        destinationAddress: 'D',
        price: 200,
        distance: 2.0,
        completedAt: DateTime.now(),
      );

      await storageService.saveOrderHistory(history1);
      await storageService.saveOrderHistory(history2);

      await storageService.deleteOrder('order_1');

      final retrieved = await storageService.getOrderHistory();

      expect(retrieved.length, 1);
      expect(retrieved.first.orderId, 'order_2');
    });

    test('should clear all history', () async {
      final history = DriverOrderHistory(
        orderId: 'order_1',
        passengerId: 'passenger_1',
        passengerName: '測試',
        pickupAddress: 'A',
        destinationAddress: 'B',
        price: 100,
        distance: 1.0,
        completedAt: DateTime.now(),
      );

      await storageService.saveOrderHistory(history);
      await storageService.clearHistory();

      final retrieved = await storageService.getOrderHistory();

      expect(retrieved.length, 0);
    });

    test('should calculate total earnings correctly', () async {
      final history1 = DriverOrderHistory(
        orderId: 'order_1',
        passengerId: 'passenger_1',
        passengerName: '訂單1',
        pickupAddress: 'A',
        destinationAddress: 'B',
        price: 150,
        distance: 1.0,
        completedAt: DateTime.now(),
      );

      final history2 = DriverOrderHistory(
        orderId: 'order_2',
        passengerId: 'passenger_2',
        passengerName: '訂單2',
        pickupAddress: 'C',
        destinationAddress: 'D',
        price: 250,
        distance: 2.0,
        completedAt: DateTime.now(),
      );

      await storageService.saveOrderHistory(history1);
      await storageService.saveOrderHistory(history2);

      final totalEarnings = await storageService.getTotalEarnings();

      expect(totalEarnings, 400);
    });

    test('should calculate total distance correctly', () async {
      final history1 = DriverOrderHistory(
        orderId: 'order_1',
        passengerId: 'passenger_1',
        passengerName: '訂單1',
        pickupAddress: 'A',
        destinationAddress: 'B',
        price: 100,
        distance: 5.5,
        completedAt: DateTime.now(),
      );

      final history2 = DriverOrderHistory(
        orderId: 'order_2',
        passengerId: 'passenger_2',
        passengerName: '訂單2',
        pickupAddress: 'C',
        destinationAddress: 'D',
        price: 200,
        distance: 3.2,
        completedAt: DateTime.now(),
      );

      await storageService.saveOrderHistory(history1);
      await storageService.saveOrderHistory(history2);

      final totalDistance = await storageService.getTotalDistance();

      expect(totalDistance, closeTo(8.7, 0.01));
    });

    test('should handle corrupted data gracefully', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_order_history', 'invalid json');

      final retrieved = await storageService.getOrderHistory();

      expect(retrieved.length, 0); // Should return empty list
      
      // Should have cleared corrupted data
      final clearedData = prefs.getString('driver_order_history');
      expect(clearedData, isNull);
    });
  });
}
