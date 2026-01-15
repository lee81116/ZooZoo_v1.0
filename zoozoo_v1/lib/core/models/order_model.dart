import 'dart:math';

import '../services/map/map_models.dart';
import 'order_status.dart';
import 'passenger_model.dart';

/// Order model
class Order {
  final String id;
  final Passenger passenger;
  final AppLatLng pickupLocation;
  final String pickupAddress;
  final AppLatLng destinationLocation;
  final String destinationAddress;
  final String vehicleType;
  final String vehicleEmoji;
  final int price;
  final double distance; // km
  final int estimatedMinutes;
  final OrderStatus status;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.passenger,
    required this.pickupLocation,
    required this.pickupAddress,
    required this.destinationLocation,
    required this.destinationAddress,
    required this.vehicleType,
    required this.vehicleEmoji,
    required this.price,
    required this.distance,
    required this.estimatedMinutes,
    required this.status,
    required this.createdAt,
  });

  /// Create a copy with updated status
  Order copyWith({OrderStatus? status}) {
    return Order(
      id: id,
      passenger: passenger,
      pickupLocation: pickupLocation,
      pickupAddress: pickupAddress,
      destinationLocation: destinationLocation,
      destinationAddress: destinationAddress,
      vehicleType: vehicleType,
      vehicleEmoji: vehicleEmoji,
      price: price,
      distance: distance,
      estimatedMinutes: estimatedMinutes,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  /// Create a mock order with random data
  factory Order.mock() {
    final random = Random();

    // Taipei locations
    final locations = [
      {'name': '台北車站', 'lat': 25.0478, 'lng': 121.5170},
      {'name': '台北101', 'lat': 25.0330, 'lng': 121.5654},
      {'name': '西門町', 'lat': 25.0421, 'lng': 121.5081},
      {'name': '信義威秀', 'lat': 25.0360, 'lng': 121.5670},
      {'name': '國父紀念館', 'lat': 25.0400, 'lng': 121.5600},
      {'name': '松山機場', 'lat': 25.0694, 'lng': 121.5525},
      {'name': '饒河夜市', 'lat': 25.0510, 'lng': 121.5775},
      {'name': '士林夜市', 'lat': 25.0880, 'lng': 121.5240},
      {'name': '大安森林公園', 'lat': 25.0300, 'lng': 121.5356},
      {'name': '中正紀念堂', 'lat': 25.0350, 'lng': 121.5220},
    ];

    // Vehicle types
    final vehicles = [
      {'name': '元氣汪汪', 'emoji': '🐕', 'multiplier': 1.0},
      {'name': '招財貓貓', 'emoji': '🐱', 'multiplier': 1.3},
      {'name': '北極熊阿北', 'emoji': '🐻‍❄️', 'multiplier': 1.6},
      {'name': '袋鼠媽媽', 'emoji': '🦘', 'multiplier': 1.4},
    ];

    // Random pickup and destination (make sure they're different)
    final pickupIndex = random.nextInt(locations.length);
    var destIndex = random.nextInt(locations.length);
    while (destIndex == pickupIndex) {
      destIndex = random.nextInt(locations.length);
    }

    final pickup = locations[pickupIndex];
    final destination = locations[destIndex];
    final vehicle = vehicles[random.nextInt(vehicles.length)];

    // Calculate distance (simple approximation)
    final distance = _calculateDistance(
      pickup['lat'] as double,
      pickup['lng'] as double,
      destination['lat'] as double,
      destination['lng'] as double,
    );

    // Calculate price
    final basePrice = 70;
    final perKmPrice = 15;
    final multiplier = vehicle['multiplier'] as double;
    final price = ((basePrice + distance * perKmPrice) * multiplier).round();

    // Estimate time (assume 25 km/h average in city)
    final estimatedMinutes = (distance / 25 * 60).round().clamp(5, 60);

    return Order(
      id: 'order_${DateTime.now().millisecondsSinceEpoch}',
      passenger: Passenger.mock(),
      pickupLocation: AppLatLng(pickup['lat'] as double, pickup['lng'] as double),
      pickupAddress: pickup['name'] as String,
      destinationLocation: AppLatLng(destination['lat'] as double, destination['lng'] as double),
      destinationAddress: destination['name'] as String,
      vehicleType: vehicle['name'] as String,
      vehicleEmoji: vehicle['emoji'] as String,
      price: price,
      distance: distance,
      estimatedMinutes: estimatedMinutes,
      status: OrderStatus.searching,
      createdAt: DateTime.now(),
    );
  }

  /// Calculate distance between two points in km (Haversine formula)
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * pi / 180;

  @override
  String toString() => 'Order($id: $pickupAddress → $destinationAddress)';
}
