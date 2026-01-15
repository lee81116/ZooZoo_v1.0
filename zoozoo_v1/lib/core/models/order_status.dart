/// Order status enum
/// Matches the database schema
enum OrderStatus {
  searching,  // 搜尋司機中
  matched,    // 已配對司機
  inTrip,     // 行程中
  completed,  // 已完成
  cancelled,  // 已取消
}

/// Extension for OrderStatus
extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.searching:
        return '搜尋中';
      case OrderStatus.matched:
        return '已配對';
      case OrderStatus.inTrip:
        return '行程中';
      case OrderStatus.completed:
        return '已完成';
      case OrderStatus.cancelled:
        return '已取消';
    }
  }

  bool get isActive {
    return this == OrderStatus.searching ||
        this == OrderStatus.matched ||
        this == OrderStatus.inTrip;
  }
}
