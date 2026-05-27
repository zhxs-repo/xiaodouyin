class ParsedFilename {
  final String? bloggerName;
  final String? douyinId;
  final DateTime? date;

  const ParsedFilename({this.bloggerName, this.douyinId, this.date});
}

class FilenameParser {
  /// 解析抖音视频文件名，常见格式：
  /// - "博主名_抖音ID_20240101.mp4"
  /// - "博主名_20240101.mp4"
  /// - "20240101_抖音ID.mp4"
  static ParsedFilename parse(String fileName) {
    // 去掉扩展名
    final name = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    final parts = name.split('_');

    String? bloggerName;
    String? douyinId;
    DateTime? date;

    for (final part in parts) {
      // 尝试解析日期：8位数字 YYYYMMDD
      if (part.length == 8 && int.tryParse(part) != null) {
        final year = int.parse(part.substring(0, 4));
        final month = int.parse(part.substring(4, 6));
        final day = int.parse(part.substring(6, 8));
        date = DateTime.tryParse('$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}');
      }
      // 尝试解析抖音ID：纯数字且非8位日期
      else if (RegExp(r'^\d+$').hasMatch(part) && part.length != 8) {
        douyinId = part;
      }
      // 其他部分作为博主名
      else if (!RegExp(r'^\d+$').hasMatch(part)) {
        bloggerName = bloggerName == null ? part : '$bloggerName$part';
      }
    }

    return ParsedFilename(bloggerName: bloggerName, douyinId: douyinId, date: date);
  }
}
