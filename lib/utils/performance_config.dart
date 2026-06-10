import 'dart:io';
import 'package:flutter/foundation.dart';

/// 设备性能等级
enum PerformanceLevel { low, medium, high }

/// 性能配置工具类
class PerformanceConfig {
  /// 检测当前设备性能等级
  static Future<PerformanceLevel> detectDeviceLevel() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final memInfo = await File('/proc/meminfo').readAsString();
        final match = RegExp(r'MemTotal:\s+(\d+)\s+kB').firstMatch(memInfo);
        if (match != null) {
          final totalMemKB = int.parse(match.group(1)!);
          final totalMemMB = totalMemKB ~/ 1024;
          if (totalMemMB < 2048) return PerformanceLevel.low;
          if (totalMemMB < 4096) return PerformanceLevel.medium;
          return PerformanceLevel.high;
        }
      } catch (_) {}
      return PerformanceLevel.medium;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return PerformanceLevel.high;
    } else {
      return PerformanceLevel.high;
    }
  }

  static Map<String, dynamic> getRecommendedConfig(PerformanceLevel level) {
    switch (level) {
      case PerformanceLevel.low:
        return {
          'smartPlayModeEnabled': false,
          'advancedEffectsEnabled': false,
          'thumbnailPreviewEnabled': false,
          'gestureSensitivity': 0.5,
        };
      case PerformanceLevel.medium:
        return {
          'smartPlayModeEnabled': false,
          'advancedEffectsEnabled': true,
          'thumbnailPreviewEnabled': true,
          'gestureSensitivity': 0.8,
        };
      case PerformanceLevel.high:
        return {
          'smartPlayModeEnabled': true,
          'advancedEffectsEnabled': true,
          'thumbnailPreviewEnabled': true,
          'gestureSensitivity': 1.0,
        };
    }
  }
}
