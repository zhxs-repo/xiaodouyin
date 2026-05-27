import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'filename_parser.dart';

@immutable
class VideoItem {
  final String path;
  final String fileName;
  final String? bloggerName;
  final String? douyinId;
  final DateTime? date;
  final String? thumbnailPath;
  final int index;

  const VideoItem({
    required this.path,
    required this.fileName,
    this.bloggerName,
    this.douyinId,
    this.date,
    this.thumbnailPath,
    required this.index,
  });

  factory VideoItem.fromPath(String path, int index) {
    final fileName = p.basename(path);
    final parsed = FilenameParser.parse(fileName);
    return VideoItem(
      path: path,
      fileName: fileName,
      bloggerName: parsed.bloggerName,
      douyinId: parsed.douyinId,
      date: parsed.date,
      index: index,
    );
  }

  /// copyWith支持nullable字段置null：传入对应sentinel对象即可
  /// 例如: copyWith(bloggerName: VideoItem._nullSentinel) 将bloggerName设为null
  static const _nullSentinel = Object();

  VideoItem copyWith({
    Object? path = _nullSentinel,
    Object? fileName = _nullSentinel,
    Object? bloggerName = _nullSentinel,
    Object? douyinId = _nullSentinel,
    Object? date = _nullSentinel,
    Object? thumbnailPath = _nullSentinel,
    Object? index = _nullSentinel,
  }) {
    return VideoItem(
      path: path == _nullSentinel ? this.path : path as String,
      fileName: fileName == _nullSentinel ? this.fileName : fileName as String,
      bloggerName: bloggerName == _nullSentinel ? this.bloggerName : bloggerName as String?,
      douyinId: douyinId == _nullSentinel ? this.douyinId : douyinId as String?,
      date: date == _nullSentinel ? this.date : date as DateTime?,
      thumbnailPath: thumbnailPath == _nullSentinel ? this.thumbnailPath : thumbnailPath as String?,
      index: index == _nullSentinel ? this.index : index as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'fileName': fileName,
    'bloggerName': bloggerName,
    'douyinId': douyinId,
    'date': date?.toIso8601String(),
    'thumbnailPath': thumbnailPath,
    'index': index,
  };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
    path: json['path'] as String,
    fileName: json['fileName'] as String,
    bloggerName: json['bloggerName'] as String?,
    douyinId: json['douyinId'] as String?,
    date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
    thumbnailPath: json['thumbnailPath'] as String?,
    index: json['index'] as int,
  );
}
