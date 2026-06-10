import 'package:flutter/material.dart';
import '../data/repositories/config_repository.dart';
import '../data/models/app_config.dart';
import '../data/services/file_service.dart';

class ConfigProvider extends ChangeNotifier {
  final ConfigRepository _repository;
  final FileService _fileService;
  AppConfig _config = const AppConfig();

  ConfigProvider(this._repository, this._fileService);

  AppConfig get config => _config;

  Future<void> loadConfig() async {
    await _repository.load();
    _config = _repository.config;
    _syncCustomDirs();
    notifyListeners();
  }

  void _syncCustomDirs() {
    _fileService.updateCustomDirs(
      videoDir: _config.customVideoDir,
      imageDir: _config.customImageDir,
    );
  }

  Future<void> updateConfig(AppConfig config) async {
    await _repository.updateConfig(config);
    _config = config;
    _syncCustomDirs();
    notifyListeners();
  }

  Future<void> updateField({
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
  }) async {
    _config = _config.copyWith(
      playMode: playMode,
      scale: scale,
      rotation: rotation,
      saturation: saturation,
      uiOpacity: uiOpacity,
      nameOpacity: nameOpacity,
      fontSize: fontSize,
      textColor: textColor,
      textEffect: textEffect,
      cultivationEnabled: cultivationEnabled,
      vibrationEnabled: vibrationEnabled,
      swipeAnimationEnabled: swipeAnimationEnabled,
      thumbnailLoadEnabled: thumbnailLoadEnabled,
      globalResumeEnabled: globalResumeEnabled,
      defaultStartupMode: defaultStartupMode,
      customVideoDir: customVideoDir,
      customImageDir: customImageDir,
      videoModePassword: videoModePassword,
      beautyModePassword: beautyModePassword,
      onlineModePassword: onlineModePassword,
      themeMode: themeMode,
      smartPlayModeEnabled: smartPlayModeEnabled,
      devicePerformanceLevel: devicePerformanceLevel,
      advancedEffectsEnabled: advancedEffectsEnabled,
    );
    await _repository.updateConfig(_config);
    _syncCustomDirs();
    notifyListeners();
  }

  /// 仅更新内存状态（用于 Slider 拖拽实时预览），不持久化
  void updateFieldMemoryOnly({
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
  }) {
    _config = _config.copyWith(
      playMode: playMode,
      scale: scale,
      rotation: rotation,
      saturation: saturation,
      uiOpacity: uiOpacity,
      nameOpacity: nameOpacity,
      fontSize: fontSize,
      textColor: textColor,
      textEffect: textEffect,
      cultivationEnabled: cultivationEnabled,
      vibrationEnabled: vibrationEnabled,
      swipeAnimationEnabled: swipeAnimationEnabled,
      thumbnailLoadEnabled: thumbnailLoadEnabled,
      globalResumeEnabled: globalResumeEnabled,
      defaultStartupMode: defaultStartupMode,
      customVideoDir: customVideoDir,
      customImageDir: customImageDir,
      videoModePassword: videoModePassword,
      beautyModePassword: beautyModePassword,
      onlineModePassword: onlineModePassword,
      themeMode: themeMode,
      smartPlayModeEnabled: smartPlayModeEnabled,
      devicePerformanceLevel: devicePerformanceLevel,
      advancedEffectsEnabled: advancedEffectsEnabled,
    );
    notifyListeners();
  }

  // === v2.0 新增方法：智能模式与性能分级控制 ===

  /// 切换智能播放模式开关
  Future<void> toggleSmartPlayMode(bool enabled) async {
    await updateField(smartPlayModeEnabled: enabled);
  }

  /// 更新设备性能等级 (low/medium/high)
  Future<void> updatePerformanceLevel(String level) async {
    if (!['low', 'medium', 'high'].contains(level)) {
      throw ArgumentError('Invalid performance level: $level');
    }
    await updateField(devicePerformanceLevel: level);
  }

  /// 切换高级特效总开关
  Future<void> toggleAdvancedEffects(bool enabled) async {
    await updateField(advancedEffectsEnabled: enabled);
  }
}
