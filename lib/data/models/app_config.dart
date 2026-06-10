import 'package:flutter/foundation.dart';

enum PlayMode { normal, loop, loopOne }

enum TextEffectType { solid, gradient, colorful }

@immutable
class AppConfig {
  final PlayMode playMode;
  final double scale;
  final double rotation;
  final double saturation;
  final double uiOpacity;
  final double nameOpacity;
  final double fontSize;
  final String textColor;
  final TextEffectType textEffect;
  final bool cultivationEnabled;
  final bool vibrationEnabled;
  final bool swipeAnimationEnabled;
  final bool thumbnailLoadEnabled;
  final bool globalResumeEnabled;
  final String defaultStartupMode;
  final String? customVideoDir;
  final String? customImageDir;
  final String videoModePassword;
  final String beautyModePassword;
  final String onlineModePassword;
  // 主题模式: 'system' / 'dark' / 'light'
  final String themeMode;
  // 智能播放模式开关（默认关闭，用户可手动开启）
  final bool smartPlayModeEnabled;
  // 设备性能等级：'low' / 'medium' / 'high' (自动检测或手动设置)
  final String devicePerformanceLevel;
  // 高级特效默认开启状态（根据性能等级自动调整）
  final bool advancedEffectsEnabled;

  const AppConfig({
    this.playMode = PlayMode.normal,
    this.scale = 1.25,
    this.rotation = 0,
    this.saturation = 100,
    this.uiOpacity = 1.0,
    this.nameOpacity = 1.0,
    this.fontSize = 16,
    this.textColor = '#FFFFFF',
    this.textEffect = TextEffectType.solid,
    this.cultivationEnabled = false,
    this.vibrationEnabled = true,
    this.swipeAnimationEnabled = true,
    this.thumbnailLoadEnabled = true,
    this.globalResumeEnabled = true,
    this.defaultStartupMode = 'none',
    this.customVideoDir,
    this.customImageDir,
    this.videoModePassword = '99',
    this.beautyModePassword = '88',
    this.onlineModePassword = '77',
    this.themeMode = 'system',
    this.smartPlayModeEnabled = false,
    this.devicePerformanceLevel = 'medium',
    this.advancedEffectsEnabled = true,
  });

  AppConfig copyWith({
    PlayMode? playMode,
    double? scale,
    double? rotation,
    double? saturation,
    double? uiOpacity,
    double? nameOpacity,
    double? fontSize,
    String? textColor,
    TextEffectType? textEffect,
    bool? cultivationEnabled,
    bool? vibrationEnabled,
    bool? swipeAnimationEnabled,
    bool? thumbnailLoadEnabled,
    bool? globalResumeEnabled,
    String? defaultStartupMode,
    String? customVideoDir,
    String? customImageDir,
    String? videoModePassword,
    String? beautyModePassword,
    String? onlineModePassword,
    String? themeMode,
    bool? smartPlayModeEnabled,
    String? devicePerformanceLevel,
    bool? advancedEffectsEnabled,
  }) => AppConfig(
    playMode: playMode ?? this.playMode,
    scale: scale ?? this.scale,
    rotation: rotation ?? this.rotation,
    saturation: saturation ?? this.saturation,
    uiOpacity: uiOpacity ?? this.uiOpacity,
    nameOpacity: nameOpacity ?? this.nameOpacity,
    fontSize: fontSize ?? this.fontSize,
    textColor: textColor ?? this.textColor,
    textEffect: textEffect ?? this.textEffect,
    cultivationEnabled: cultivationEnabled ?? this.cultivationEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    swipeAnimationEnabled: swipeAnimationEnabled ?? this.swipeAnimationEnabled,
    thumbnailLoadEnabled: thumbnailLoadEnabled ?? this.thumbnailLoadEnabled,
    globalResumeEnabled: globalResumeEnabled ?? this.globalResumeEnabled,
    defaultStartupMode: defaultStartupMode ?? this.defaultStartupMode,
    customVideoDir: customVideoDir ?? this.customVideoDir,
    customImageDir: customImageDir ?? this.customImageDir,
    videoModePassword: videoModePassword ?? this.videoModePassword,
    beautyModePassword: beautyModePassword ?? this.beautyModePassword,
    smartPlayModeEnabled: smartPlayModeEnabled ?? this.smartPlayModeEnabled,
    devicePerformanceLevel: devicePerformanceLevel ?? this.devicePerformanceLevel,
    advancedEffectsEnabled: advancedEffectsEnabled ?? this.advancedEffectsEnabled,
    onlineModePassword: onlineModePassword ?? this.onlineModePassword,
    themeMode: themeMode ?? this.themeMode,
  );

  Map<String, dynamic> toJson() => {
    'playMode': playMode.name,
    'scale': scale,
    'rotation': rotation,
    'saturation': saturation,
    'uiOpacity': uiOpacity,
    'nameOpacity': nameOpacity,
    'fontSize': fontSize,
    'textColor': textColor,
    'textEffect': textEffect.name,
    'cultivationEnabled': cultivationEnabled,
    'vibrationEnabled': vibrationEnabled,
    'swipeAnimationEnabled': swipeAnimationEnabled,
    'thumbnailLoadEnabled': thumbnailLoadEnabled,
    'globalResumeEnabled': globalResumeEnabled,
    'defaultStartupMode': defaultStartupMode,
    'customVideoDir': customVideoDir,
    'customImageDir': customImageDir,
    'videoModePassword': videoModePassword,
    'beautyModePassword': beautyModePassword,
    'onlineModePassword': onlineModePassword,
    'themeMode': themeMode,
    'smartPlayModeEnabled': smartPlayModeEnabled,
    'devicePerformanceLevel': devicePerformanceLevel,
    'advancedEffectsEnabled': advancedEffectsEnabled,
  };

  factory AppConfig.fromJson(Map<String, dynamic> json) => AppConfig(
    playMode: PlayMode.values.firstWhere(
      (e) => e.name == json['playMode'], orElse: () => PlayMode.normal),
    scale: (json['scale'] as num?)?.toDouble() ?? 1.25,
    rotation: (json['rotation'] as num?)?.toDouble() ?? 0,
    saturation: (json['saturation'] as num?)?.toDouble() ?? 100,
    uiOpacity: (json['uiOpacity'] as num?)?.toDouble() ?? 1.0,
    nameOpacity: (json['nameOpacity'] as num?)?.toDouble() ?? 1.0,
    fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16,
    textColor: json['textColor'] as String? ?? '#FFFFFF',
    textEffect: TextEffectType.values.firstWhere(
      (e) => e.name == json['textEffect'], orElse: () => TextEffectType.solid),
    cultivationEnabled: json['cultivationEnabled'] as bool? ?? false,
    vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
    swipeAnimationEnabled: json['swipeAnimationEnabled'] as bool? ?? true,
    thumbnailLoadEnabled: json['thumbnailLoadEnabled'] as bool? ?? true,
    globalResumeEnabled: json['globalResumeEnabled'] as bool? ?? true,
    defaultStartupMode: json['defaultStartupMode'] as String? ?? 'none',
    customVideoDir: json['customVideoDir'] as String?,
    customImageDir: json['customImageDir'] as String?,
    videoModePassword: json['videoModePassword'] as String? ?? '99',
    beautyModePassword: json['beautyModePassword'] as String? ?? '88',
    onlineModePassword: json['onlineModePassword'] as String? ?? '77',
    themeMode: json['themeMode'] as String? ?? 'system',
    smartPlayModeEnabled: json['smartPlayModeEnabled'] as bool? ?? false,
    devicePerformanceLevel: json['devicePerformanceLevel'] as String? ?? 'medium',
    advancedEffectsEnabled: json['advancedEffectsEnabled'] as bool? ?? true,
  );
}
