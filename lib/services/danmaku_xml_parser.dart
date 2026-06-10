import 'dart:io';
import 'package:xml/xml.dart';
import '../models/danmaku.dart';

/// Bilibili XML 弹幕解析器
/// 支持加载与视频同名的 .xml 文件
class DanmakuXmlParser {
  /// 解析 XML 文件内容
  static List<Danmaku> parse(String xmlContent) {
    final document = XmlDocument.parse(xmlContent);
    final danmakus = <Danmaku>[];

    for (final element in document.findAllElements('d')) {
      try {
        final pAttr = element.getAttribute('p');
        if (pAttr == null) continue;

        final parts = pAttr.split(',');
        if (parts.length < 8) continue;

        final time = double.tryParse(parts[0]) ?? 0.0;
        final type = int.tryParse(parts[1]) ?? 1;
        final fontSize = double.tryParse(parts[2]) ?? 25.0;
        final color = int.tryParse(parts[3]) ?? 0xFFFFFFFF;
        final timestamp = int.tryParse(parts[4]) ?? 0;
        // parts[5] 是发送者 ID，忽略
        // parts[6] 是弹幕池 ID，忽略
        final content = element.text.trim();

        if (content.isEmpty) continue;

        danmakus.add(Danmaku(
          content: content,
          time: time,
          type: _mapType(type),
          fontSize: fontSize,
          color: color,
          timestamp: timestamp,
        ));
      } catch (e) {
        // 跳过解析失败的条目
        continue;
      }
    }

    return danmakus;
  }

  /// 从文件路径加载并解析
  static Future<List<Danmaku>> loadFromFile(String videoPath) async {
    final xmlPath = videoPath.replaceAllMapped(
      RegExp(r'\.[^.]+$'),
      (match) => '.xml',
    );

    final file = File(xmlPath);
    if (!await file.exists()) {
      return [];
    }

    try {
      final content = await file.readAsString();
      return parse(content);
    } catch (e) {
      print('[DanmakuXmlParser] Failed to load $xmlPath: $e');
      return [];
    }
  }

  /// 映射弹幕类型
  static DanmakuType _mapType(int type) {
    switch (type) {
      case 4: return DanmakuType.bottom;
      case 5: return DanmakuType.top;
      case 6: return DanmakuType.reverse;
      default: return DanmakuType.scroll; // 1, 2, 3
    }
  }
}
