/// Driver-side order history model
/// Lightweight model for storing completed order information
class DriverOrderHistory {
  final String orderId;
  final String passengerId;
  final String passengerName;
  final String pickupAddress;
  final String destinationAddress;
  final int price;
  final double distance; // km
  final DateTime completedAt;

  const DriverOrderHistory({
    required this.orderId,
    required this.passengerId,
    required this.passengerName,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.price,
    required this.distance,
    required this.completedAt,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'price': price,
      'distance': distance,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory DriverOrderHistory.fromJson(Map<String, dynamic> json) {
    return DriverOrderHistory(
      orderId: json['orderId'] as String,
      passengerId: json['passengerId'] as String,
      passengerName: json['passengerName'] as String,
      pickupAddress: json['pickupAddress'] as String,
      destinationAddress: json['destinationAddress'] as String,
      price: json['price'] as int,
      distance: (json['distance'] as num).toDouble(),
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'DriverOrderHistory($orderId: $pickupAddress → $destinationAddress, ¥$price)';
  }
}
