import 'package:flutter/material.dart';

/// App color palette - Milk Tea Theme
/// 
/// Primary: 焦糖奶茶 #D4A574
/// Accent: 濃縮咖啡 #4A3728
abstract class AppColors {
  // ══════════════════════════════════════════
  // Primary Colors (Milk Tea)
  // ══════════════════════════════════════════
  
  /// Main brand color - 焦糖奶茶
  static const Color primary = Color(0xFFD4A574);
  
  /// Lighter variant - 鮮奶茶
  static const Color primaryLight = Color(0xFFE8CBAB);
  
  /// Darker variant - 濃奶茶
  static const Color primaryDark = Color(0xFFB8895A);

  // ══════════════════════════════════════════
  // Accent Colors (Coffee/Pearl)
  // ══════════════════════════════════════════
  
  /// Accent color - 濃縮咖啡
  static const Color accent = Color(0xFF4A3728);
  
  /// Lighter accent - 咖啡歐蕾
  static const Color accentLight = Color(0xFF6B5344);
  
  /// Darker accent - 黑珍珠
  static const Color accentDark = Color(0xFF2D1F15);

  // ══════════════════════════════════════════
  // Light Mode - Background Colors
  // ══════════════════════════════════════════
  
  /// Main background - 奶泡白
  static const Color background = Color(0xFFFAF6F1);
  
  /// Card/Surface background
  static const Color surface = Color(0xFFFFFFFF);
  
  /// Secondary background - 淡奶茶
  static const Color backgroundSecondary = Color(0xFFF3EBE1);

  // ══════════════════════════════════════════
  // Dark Mode - Background Colors
  // ══════════════════════════════════════════
  
  /// Dark background - 深咖啡
  static const Color backgroundDark = Color(0xFF1A1512);
  
  /// Dark surface - 深棕
  static const Color surfaceDark = Color(0xFF2A221C);
  
  /// Dark secondary background
  static const Color backgroundSecondaryDark = Color(0xFF352B24);

  // ══════════════════════════════════════════
  // Light Mode - Text Colors
  // ══════════════════════════════════════════
  
  /// Primary text - 濃縮咖啡
  static const Color textPrimary = Color(0xFF4A3728);
  
  /// Secondary text
  static const Color textSecondary = Color(0xFF8B7355);
  
  /// Hint/Placeholder text
  static const Color textHint = Color(0xFFB5A18C);
  
  /// Text on primary color
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ══════════════════════════════════════════
  // Dark Mode - Text Colors
  // ══════════════════════════════════════════
  
  /// Dark primary text - 奶泡白
  static const Color textPrimaryDark = Color(0xFFF5EDE4);
  
  /// Dark secondary text
  static const Color textSecondaryDark = Color(0xFFB5A18C);
  
  /// Dark hint text
  static const Color textHintDark = Color(0xFF7A6B5A);

  // ══════════════════════════════════════════
  // Status Colors (Same for both modes)
  // ══════════════════════════════════════════
  
  /// Success - 抹茶綠
  static const Color success = Color(0xFF7CAF5E);
  
  /// Warning - 蜂蜜黃
  static const Color warning = Color(0xFFE6B54A);
  
  /// Error - 草莓紅
  static const Color error = Color(0xFFD4665A);
  
  /// Info - 伯爵藍
  static const Color info = Color(0xFF6B8CAE);

  // ══════════════════════════════════════════
  // Light Mode - UI Element Colors
  // ══════════════════════════════════════════
  
  /// Divider
  static const Color divider = Color(0xFFE5DDD3);
  
  /// Shadow
  static const Color shadow = Color(0x1A4A3728);
  
  /// Disabled state
  static const Color disabled = Color(0xFFD1C7BB);

  // ══════════════════════════════════════════
  // Dark Mode - UI Element Colors
  // ══════════════════════════════════════════
  
  /// Dark divider
  static const Color dividerDark = Color(0xFF3D322A);
  
  /// Dark disabled state
  static const Color disabledDark = Color(0xFF5A4D42);

  // ══════════════════════════════════════════
  // Glass Effect (Same for both modes)
  // ══════════════════════════════════════════
  
  /// Glass effect overlay
  static const Color glassOverlay = Color(0x80FFFFFF);
  
  /// Glass effect border
  static const Color glassBorder = Color(0x40FFFFFF);
  
  /// Dark glass overlay
  static const Color glassOverlayDark = Color(0x40000000);

  // ══════════════════════════════════════════
  // Gradients
  // ══════════════════════════════════════════
  
  /// Soft background gradient (Light)
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, backgroundSecondary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Soft background gradient (Dark)
  static const LinearGradient backgroundGradientDark = LinearGradient(
    colors: [backgroundDark, backgroundSecondaryDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Primary button gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
