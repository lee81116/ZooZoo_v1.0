import 'dart:math';

/// Passenger model
class Passenger {
  final String id;
  final String name;
  final String phone;
  final String avatarEmoji;
  final double rating;
  final int totalTrips;

  const Passenger({
    required this.id,
    required this.name,
    required this.phone,
    required this.avatarEmoji,
    required this.rating,
    required this.totalTrips,
  });

  /// Create a mock passenger with random data
  factory Passenger.mock() {
    final random = Random();
    
    // Random names
    final names = [
      '王小明', '李美麗', '張大華', '陳志強', '林雅婷',
      '黃俊傑', '吳淑芬', '劉建宏', '蔡佳玲', '楊宗翰',
    ];
    
    // Random animal emojis
    final emojis = ['🐶', '🐱', '🐰', '🦊', '🐻', '🐼', '🐨', '🦁', '🐯', '🐮'];
    
    return Passenger(
      id: 'passenger_${DateTime.now().millisecondsSinceEpoch}',
      name: names[random.nextInt(names.length)],
      phone: '09${random.nextInt(10)}${random.nextInt(10)}-${100000 + random.nextInt(899999)}',
      avatarEmoji: emojis[random.nextInt(emojis.length)],
      rating: 4.0 + random.nextDouble(), // 4.0 ~ 5.0
      totalTrips: 10 + random.nextInt(200),
    );
  }

  @override
  String toString() => 'Passenger($name)';
}
