import 'dart:io';
import 'package:xml/xml.dart';
import '../models/danmaku.dart';

/// Bilibili XML 弹幕解析器
/// 支持加载与视频同名的 .xml 文件
class DanmakuXmlParser {
  /// 解析 XML 文件内容为 Danmaku 列表
  static List<Danmaku> parse(String xmlContent) {
    final List<Danmaku> danmakus = [];
    
    try {
      final document = XmlDocument.parse(xmlContent);
      final root = document.rootElement;
      
      if (root.name.local != 'i') return danmakus;

      for (final element in root.childElements) {
        if (element.name.local == 'd' && element.attributes.isNotEmpty) {
          final pAttr = element.getAttribute('p');
          if (pAttr == null) continue;

          final parts = pAttr.split(',');
          if (parts.length < 8) continue;

          try {
            final time = double.parse(parts[0]); // 出现时间 (秒)
            final mode = int.parse(parts[1]); // 模式：1-3 滚动，4 底部，5 顶部，6-7 逆向，8-9 特殊
            final fontSize = double.parse(parts[2]); // 字号
            final colorValue = int.parse(parts[3]); // 颜色 (十进制)
            final timestamp = int.parse(parts[4]); // 发送时间戳
            // parts[5] 是弹幕池 ID (通常忽略)
            // parts[6] 是用户 ID (通常忽略)
            // parts[7] 是弹幕 ID (通常忽略)

            final text = element.text.trim();
            if (text.isEmpty) continue;

            // 转换颜色 (十进制 -> Color)
            final color = _convertColor(colorValue);

            // 转换模式
            final danmakuMode = _convertMode(mode);

            danmakus.add(Danmaku(
              text: text,
              time: time,
              mode: danmakuMode,
              fontSize: fontSize,
              color: color,
              sender: '', // XML 中通常不包含发送者昵称
              sendTime: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
            ));
          } catch (e) {
            // 跳过解析失败的单条弹幕
            continue;
          }
        }
      }
    } catch (e) {
      print('[DanmakuXmlParser] 解析失败: $e');
    }

    return danmakus;
  }

  /// 从文件路径加载并解析 XML
  static Future<List<Danmaku>> loadFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      return [];
    }
    
    try {
      final content = await file.readAsString();
      return parse(content);
    } catch (e) {
      print('[DanmakuXmlParser] 读取文件失败: $e');
      return [];
    }
  }

  /// 根据视频路径自动查找同名 XML 文件
  /// 例如: /path/to/video.mp4 -> /path/to/video.xml
  static Future<List<Danmaku>> loadForVideo(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      return [];
    }

    final baseName = file.path.substring(0, file.path.lastIndexOf('.'));
    final xmlPath = '$baseName.xml';
    
    print('[DanmakuXmlParser] 尝试加载弹幕: $xmlPath');
    return loadFromFile(xmlPath);
  }

  /// 转换颜色值 (Bilibili XML 使用十进制 RGB，Flutter 使用 ARGB)
  static int _convertColor(int rgbValue) {
    // XML 中的颜色是 10 进制 RGB (如 16777215 = 0xFFFFFF)
    // Flutter Color 需要 ARGB (如 0xFFFFFFFF)
    final r = (rgbValue >> 16) & 0xFF;
    final g = (rgbValue >> 8) & 0xFF;
    final b = rgbValue & 0xFF;
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }

  /// 转换弹幕模式
  static DanmakuMode _convertMode(int xmlMode) {
    switch (xmlMode) {
      case 1:
      case 2:
      case 3:
        return DanmakuMode.scroll; // 普通滚动
      case 4:
        return DanmakuMode.bottom; // 底部固定
      case 5:
        return DanmakuMode.top; // 顶部固定
      case 6:
      case 7:
        return DanmakuMode.scrollReverse; // 逆向滚动 (降级为普通滚动)
      case 8:
      case 9:
        return DanmakuMode.special; // 高级弹幕 (降级为普通滚动)
      default:
        return DanmakuMode.scroll;
    }
  }
}
