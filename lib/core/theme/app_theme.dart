import 'dart:ui';

import 'package:flutter/material.dart';

class AppTheme {
  // ==================== 品牌色 ====================
  static const Color seedColor = Color(0xFFFE2C55);
  static const Color primaryColor = Color(0xFFFE2C55);
  static const Color secondaryColor = Color(0xFF00FFFF);
  static const Color accentColor = Color(0xFFFFD700);

  // 兼容旧代码
  static const Color backgroundDark = Color(0xFF000000);
  static const Color backgroundLight = Color(0xFF111111);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCCCCCC);
  static const Color borderColor = Color(0xFF333333);

  // ==================== 间距 ====================
  static const double spacingXS = 5.0;
  static const double spacingS = 10.0;
  static const double spacingM = 15.0;
  static const double spacingL = 20.0;
  static const double spacingXL = 30.0;

  // ==================== 圆角 ====================
  static const double radiusS = 8.0;
  static const double radiusM = 10.0;
  static const double radiusL = 15.0;
  static const double radiusXL = 20.0;
  static const double radiusFull = 999.0;

  // ==================== 动效常量 ====================
  static const Duration durFast = Duration(milliseconds: 200);
  static const Duration durMedium = Duration(milliseconds: 300);
  static const Duration durSlow = Duration(milliseconds: 500);
  static const Duration durVerySlow = Duration(milliseconds: 800);
  static const Curve curveEmphasized = Cubic(0.2, 0, 0, 1);
  static const Curve curveStandard = Curves.easeInOutCubic;

  // ==================== 主题 ====================
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);
  static ThemeData get lightTheme => _buildTheme(Brightness.light);

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface),
      textTheme: _buildTextTheme(colorScheme),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: SliderComponentShape.noOverlay,
        showValueIndicator: ShowValueIndicator.onlyForContinuous,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colorScheme.onPrimary
                : colorScheme.outline),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusL)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusXL)),
        elevation: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(color: colorScheme.onSurface, fontSize: 12),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
      ),
    );
  }

  static TextTheme _buildTextTheme(ColorScheme colorScheme) {
    return TextTheme(
      displayLarge: TextStyle(color: colorScheme.onSurface, fontSize: 36, fontWeight: FontWeight.w700),
      displayMedium: TextStyle(color: colorScheme.onSurface, fontSize: 32, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: colorScheme.onSurface, fontSize: 28, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: colorScheme.onSurface, fontSize: 16),
      bodyMedium: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
      bodySmall: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
      labelLarge: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
      labelMedium: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
      labelSmall: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
    );
  }

  // ==================== 渐变 (兼容旧代码) ====================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, Color(0xFFFF6B9D)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 1.0],
  );

  // ==================== 阴影 (兼容旧代码) ====================
  static List<BoxShadow> get shadowLight => [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))];
  static List<BoxShadow> get shadowMedium => [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))];
  static List<BoxShadow> get shadowHeavy => [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 30, offset: const Offset(0, 10))];
  static List<BoxShadow> get shadowGlow => [BoxShadow(color: primaryColor.withValues(alpha: 0.6), blurRadius: 12)];
}

// ==================== 玻璃拟态装饰 ====================

class GlassDecoration {
  final double blur;
  final double opacity;
  final Color tint;
  final double borderOpacity;
  final BorderRadius? borderRadius;

  const GlassDecoration({
    this.blur = 16,
    this.opacity = 0.55,
    this.tint = Colors.black,
    this.borderOpacity = 0.08,
    this.borderRadius,
  });

  GlassDecoration copyWith({
    double? blur,
    double? opacity,
    Color? tint,
    double? borderOpacity,
    BorderRadius? borderRadius,
  }) =>
      GlassDecoration(
        blur: blur ?? this.blur,
        opacity: opacity ?? this.opacity,
        tint: tint ?? this.tint,
        borderOpacity: borderOpacity ?? this.borderOpacity,
        borderRadius: borderRadius ?? this.borderRadius,
      );

  static const GlassDecoration subtle = GlassDecoration(blur: 12, opacity: 0.40, borderOpacity: 0.06);
  static const GlassDecoration medium = GlassDecoration(blur: 16, opacity: 0.55, borderOpacity: 0.08);
  static const GlassDecoration strong = GlassDecoration(blur: 24, opacity: 0.72, borderOpacity: 0.10);
}

/// 玻璃容器
class GlassContainer extends StatelessWidget {
  final Widget? child;
  final GlassDecoration decoration;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Clip clipBehavior;

  const GlassContainer({
    super.key,
    this.child,
    this.decoration = GlassDecoration.medium,
    this.padding,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tintColor = isDark
        ? Colors.black.withValues(alpha: decoration.opacity)
        : Colors.white.withValues(alpha: decoration.opacity);
    final borderColor = Colors.white.withValues(alpha: decoration.borderOpacity);

    return ClipRRect(
      borderRadius: decoration.borderRadius ?? BorderRadius.zero,
      clipBehavior: clipBehavior,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: decoration.blur, sigmaY: decoration.blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: tintColor,
            borderRadius: decoration.borderRadius,
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 渐变蒙层 (用于覆盖在视频/图片上以提升文字可读性)
class GradientMask extends StatelessWidget {
  final Widget child;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final List<double>? stops;

  const GradientMask({
    super.key,
    required this.child,
    this.colors = const [Colors.transparent, Colors.black54],
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.stops,
  });

  const GradientMask.topFade({super.key, required this.child, double intensity = 0.6})
      : colors = const [Colors.black, Colors.transparent],
        begin = Alignment.topCenter,
        end = Alignment.bottomCenter,
        stops = null;

  const GradientMask.bottomFade({super.key, required this.child, double intensity = 0.6})
      : colors = const [Colors.transparent, Colors.black],
        begin = Alignment.topCenter,
        end = Alignment.bottomCenter,
        stops = null;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: begin,
          end: end,
          stops: stops,
        ),
      ),
      child: child,
    );
  }
}
