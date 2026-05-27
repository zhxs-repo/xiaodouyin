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
    );
    await _repository.updateConfig(_config);
    _syncCustomDirs();
    notifyListeners();
  }

  /// 仅更新内存状态（用于Slider拖拽实时预览），不持久化
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
    );
    notifyListeners();
  }

}
