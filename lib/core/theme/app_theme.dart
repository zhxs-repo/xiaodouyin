import 'package:flutter/material.dart';

class AppTheme {
  // ==================== 设计Token ====================

  // 主色调
  static const Color primaryColor = Color(0xFFFE2C55);   // 抖音红
  static const Color secondaryColor = Color(0xFF00FFFF); // 青色
  static const Color accentColor = Color(0xFFFFD700);    // 金色

  // 功能色
  static const Color successColor = Color(0xFF00FF00);
  static const Color warningColor = Color(0xFFFF7F00);
  static const Color errorColor = Color(0xFFFF4444);
  static const Color infoColor = Color(0xFF87CEEB);

  // 中性色
  static const Color backgroundDark = Color(0xFF000000);
  static const Color backgroundLight = Color(0xFF111111);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCCCCCC);
  static const Color borderColor = Color(0xFF333333);

  // 间距
  static const double spacingXS = 5.0;
  static const double spacingS = 10.0;
  static const double spacingM = 15.0;
  static const double spacingL = 20.0;
  static const double spacingXL = 30.0;

  // 圆角
  static const double radiusS = 8.0;
  static const double radiusM = 10.0;
  static const double radiusL = 15.0;
  static const double radiusXL = 20.0;

  // 阴影
  static List<BoxShadow> get shadowLight => [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))];
  static List<BoxShadow> get shadowMedium => [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))];
  static List<BoxShadow> get shadowHeavy => [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))];
  static List<BoxShadow> get shadowGlow => [BoxShadow(color: primaryColor.withValues(alpha: 0.6), blurRadius: 12)];

  // 渐变
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    stops: [0.0, 1.0],
  );

  // ==================== 主题 ====================

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundDark,
      elevation: 0,
      iconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(color: textPrimary, fontSize: 18),
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: backgroundDark,
      error: errorColor,
    ),
    iconTheme: const IconThemeData(color: textPrimary),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      titleLarge: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryColor,
      inactiveTrackColor: Colors.white24,
      thumbColor: primaryColor,
      overlayColor: primaryColor.withValues(alpha: 0.12),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected) ? textPrimary : Colors.grey),
      trackColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected) ? primaryColor : Colors.grey.shade800),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
      color: backgroundLight,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL)),
      elevation: 10,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusS)),
      ),
    ),
  );
}
