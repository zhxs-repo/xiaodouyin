import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/xml_danmaku.dart';

/// 解析 B 站弹幕 XML：`<i><d p="时间,模式,字号,颜色,...">文本</d></i>`
class DanmakuXmlParser {
  static const int _maxFileBytes = 8 * 1024 * 1024;

  static List<XmlDanmaku> parse(String content) {
    final result = <XmlDanmaku>[];
    final XmlDocument document;
    try {
      document = XmlDocument.parse(content);
    } on XmlException {
      return result;
    }
    final root = document.rootElement;
    if (root.name.local != 'i') return result;

    for (final element in root.findElements('d')) {
      final parts = element.getAttribute('p')?.split(',') ?? const [];
      if (parts.length < 4) continue;

      final time = double.tryParse(parts[0]);
      final rawMode = int.tryParse(parts[1]);
      final fontSize = double.tryParse(parts[2]);
      final rgb = int.tryParse(parts[3]);
      final text = element.innerText.trim();
      if (time == null || rawMode == null || fontSize == null || rgb == null || text.isEmpty) {
        continue;
      }

      result.add(XmlDanmaku(
        text: text,
        timeSec: time,
        mode: _mode(rawMode),
        colorValue: 0xFF000000 | (rgb & 0xFFFFFF),
        fontSize: fontSize,
      ));
    }

    result.sort((a, b) => a.timeSec.compareTo(b.timeSec));
    return result;
  }

  /// 与视频同目录同名的弹幕文件路径，例如 `a/b.mp4` -> `a/b.xml`
  static String xmlPathFor(String videoPath) => p.setExtension(videoPath, '.xml');

  static Future<List<XmlDanmaku>> loadForVideo(String videoPath) =>
      loadFile(xmlPathFor(videoPath));

  static Future<List<XmlDanmaku>> loadFile(String xmlPath) async {
    final file = File(xmlPath);
    if (!file.existsSync() || file.lengthSync() > _maxFileBytes) return const [];

    final bytes = await file.readAsBytes();
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    return parse(text);
  }

  // 6/7 逆向与 8/9 高级弹幕当前渲染器不支持，统一降级为滚动
  static XmlDanmakuMode _mode(int rawMode) {
    switch (rawMode) {
      case 4:
        return XmlDanmakuMode.bottom;
      case 5:
        return XmlDanmakuMode.top;
      default:
        return XmlDanmakuMode.scroll;
    }
  }
}
