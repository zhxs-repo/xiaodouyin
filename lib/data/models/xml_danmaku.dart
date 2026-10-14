import 'package:flutter/foundation.dart';

enum XmlDanmakuMode { scroll, top, bottom }

/// B 站弹幕 XML 中单条 `<d>` 标签的解析结果，时间基于视频时间轴（秒）。
@immutable
class XmlDanmaku {
  final String text;
  final double timeSec;
  final XmlDanmakuMode mode;

  /// ARGB，已由 XML 的 24 位 RGB 补上不透明度
  final int colorValue;
  final double fontSize;

  const XmlDanmaku({
    required this.text,
    required this.timeSec,
    required this.mode,
    required this.colorValue,
    required this.fontSize,
  });
}
