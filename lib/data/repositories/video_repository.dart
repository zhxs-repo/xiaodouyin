import '../services/file_service.dart';
import '../models/video_item.dart';

class VideoRepository {
  final FileService _fileService;
  List<VideoItem> videos = [];

  VideoRepository(this._fileService);

  Future<List<VideoItem>> loadVideos() async {
    final paths = await _fileService.scanVideoFiles();
    videos = paths.asMap().entries.map((e) => 
      VideoItem.fromPath(e.value, e.key)).toList();
    return videos;
  }

  Future<String?> importVideo(String sourcePath) async {
    return _fileService.copyFileToVideoDir(sourcePath);
  }

  Future<void> deleteVideo(String path) async {
    await _fileService.deleteFile(path);
    videos.removeWhere((v) => v.path == path);
  }

  List<VideoItem> search(String keyword) {
    final lower = keyword.toLowerCase();
    return videos.where((v) =>
      v.fileName.toLowerCase().contains(lower) ||
      (v.bloggerName?.toLowerCase().contains(lower) ?? false) ||
      (v.douyinId?.contains(lower) ?? false)
    ).toList();
  }

  Map<String, List<VideoItem>> groupByBlogger() {
    final map = <String, List<VideoItem>>{};
    for (final v in videos) {
      final name = v.bloggerName ?? '未知';
      map.putIfAbsent(name, () => []).add(v);
    }
    return map;
  }

  /// 按文件名(去后缀)分组，返回同名视频组(数量>1)
  Map<String, List<VideoItem>> findDuplicateVideos() {
    final map = <String, List<VideoItem>>{};
    for (final v in videos) {
      // 去掉扩展名，按纯文件名分组
      final lastDot = v.fileName.lastIndexOf('.');
      final baseName = lastDot > 0 ? v.fileName.substring(0, lastDot) : v.fileName;
      map.putIfAbsent(baseName, () => []).add(v);
    }
    // 仅保留重复组
    map.removeWhere((_, list) => list.length <= 1);
    return map;
  }
}
