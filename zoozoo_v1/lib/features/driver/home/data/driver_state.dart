import '../../../../core/models/order_model.dart';

/// Driver status enum
enum DriverStatus {
  offline, // 下線
  online, // 上線等待中
  hasOrder, // 收到訂單（待決定）
  toPickup, // 已接單，前往接客
  arrived, // 已到達上車點
  inTrip, // 行程進行中
  completed, // 行程完成（顯示結算）
}

/// Extension for DriverStatus
extension DriverStatusExtension on DriverStatus {
  String get displayName {
    switch (this) {
      case DriverStatus.offline:
        return '離線';
      case DriverStatus.online:
        return '等待訂單';
      case DriverStatus.hasOrder:
        return '新訂單';
      case DriverStatus.toPickup:
        return '前往接客';
      case DriverStatus.arrived:
        return '等待乘客';
      case DriverStatus.inTrip:
        return '行程中';
      case DriverStatus.completed:
        return '行程完成';
    }
  }

  bool get isWorking {
    return this != DriverStatus.offline;
  }

  bool get hasActiveTrip {
    return this == DriverStatus.toPickup ||
        this == DriverStatus.arrived ||
        this == DriverStatus.inTrip;
  }
}

/// Driver state class
class DriverState {
  final DriverStatus status;
  final Order? currentOrder;
  final DateTime? onlineSince;
  final int todayTrips;
  final int todayEarnings;
  final int dailyEarningsGoal;
  final bool isMuted;
  final bool areNotificationsEnabled;
  final bool? isChatVoiceReplyEnabled; // Nullable for hot reload safety

  bool get chatVoiceEnabledSafe => isChatVoiceReplyEnabled ?? true;

  const DriverState({
    this.status = DriverStatus.offline,
    this.currentOrder,
    this.onlineSince,
    this.todayTrips = 0,
    this.todayEarnings = 0,
    this.dailyEarningsGoal = 500,
    this.isMuted = false,
    this.areNotificationsEnabled = true,
    this.isChatVoiceReplyEnabled = true,
  });

  DriverState copyWith({
    DriverStatus? status,
    Order? currentOrder,
    bool clearOrder = false,
    DateTime? onlineSince,
    bool clearOnlineSince = false,
    int? todayTrips,
    int? todayEarnings,
    int? dailyEarningsGoal,
    bool? isMuted,
    bool? areNotificationsEnabled,
    bool? isChatVoiceReplyEnabled,
  }) {
    return DriverState(
      status: status ?? this.status,
      currentOrder: clearOrder ? null : (currentOrder ?? this.currentOrder),
      onlineSince: clearOnlineSince ? null : (onlineSince ?? this.onlineSince),
      todayTrips: todayTrips ?? this.todayTrips,
      todayEarnings: todayEarnings ?? this.todayEarnings,
      dailyEarningsGoal: dailyEarningsGoal ?? this.dailyEarningsGoal,
      isMuted: isMuted ?? this.isMuted,
      areNotificationsEnabled:
          areNotificationsEnabled ?? this.areNotificationsEnabled,
      isChatVoiceReplyEnabled:
          isChatVoiceReplyEnabled ?? this.isChatVoiceReplyEnabled,
    );
  }

  @override
  String toString() => 'DriverState($status, order: ${currentOrder?.id})';
}
