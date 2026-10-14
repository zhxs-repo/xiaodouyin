import 'package:flutter/foundation.dart';

import 'video_item.dart';

/// 视频目录树里一个直接放着视频的文件夹
@immutable
class VideoFolder {
  final String path;

  /// 相对视频根目录的显示名，根目录本身显示为"根目录"
  final String name;
  final List<VideoItem> videos;

  const VideoFolder({
    required this.path,
    required this.name,
    required this.videos,
  });

  int get videoCount => videos.length;
}
