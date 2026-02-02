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

/// Driving Modes
enum DrivingMode {
  standard, // 一般
  rush, // 趕一下
  comfort, // 舒適
  pet, // 寵物
  quiet, // 安靜
}

extension DrivingModeExtension on DrivingMode {
  String get label {
    switch (this) {
      case DrivingMode.standard:
        return '一般';
      case DrivingMode.rush:
        return '趕一下';
      case DrivingMode.comfort:
        return '舒適';
      case DrivingMode.pet:
        return '寵物';
      case DrivingMode.quiet:
        return '安靜';
    }
  }

  String get description {
    switch (this) {
      case DrivingMode.standard:
        return '標準接單模式';
      case DrivingMode.rush:
        return '在安全的駕駛行為下盡量最快的抵達目的地，可以接受較低標準的乘車平穩度';
      case DrivingMode.comfort:
        return '請遵守-緩步加減速，加速時以不聽到引擎聲為基準，減速時請提前輕踩住煞車緩步減速。行駛過程盡量保持定油門，勿頻繁踩、放油門，盡量不點煞急煞。';
      case DrivingMode.pet:
        return '可接受寵物上車(除一般毛髮外寵物排泄或嘔吐乘客須支付清潔費)';
      case DrivingMode.quiet:
        return '請遵守-關閉車窗，關閉車內音樂，盡量關閉導航及測速語音，盡量不按喇叭，行程結束後記得開啟聲音才不會聽不到我們的播報歐!';
    }
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
  final Set<DrivingMode>? activeDrivingModes; // Nullable for hot reload

  bool get chatVoiceEnabledSafe => isChatVoiceReplyEnabled ?? true;
  Set<DrivingMode> get activeModesSafe =>
      activeDrivingModes ?? const {DrivingMode.standard};

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
    this.activeDrivingModes = const {DrivingMode.standard},
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
    Set<DrivingMode>? activeDrivingModes,
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
      activeDrivingModes: activeDrivingModes ?? this.activeDrivingModes,
    );
  }

  @override
  String toString() => 'DriverState($status, order: ${currentOrder?.id})';
}
