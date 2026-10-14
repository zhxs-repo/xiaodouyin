import 'package:path/path.dart' as p;

import '../models/video_folder.dart';
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

  /// 视频目录树里"装着视频"的文件夹，供文件夹浏览页使用
  Future<List<VideoFolder>> loadFolders({
    int maxDepth = FileService.folderScanMaxDepth,
  }) async {
    final root = await _fileService.videoDirPath();
    final byDir = await _fileService.scanVideoDirs(maxDepth: maxDepth);

    final folders = byDir.entries.map((entry) {
      // 子目录多为连续剧集，按文件名排序保证集数顺序
      final paths = entry.value..sort();
      return VideoFolder(
        path: entry.key,
        name: _folderLabel(root, entry.key),
        videos: paths.asMap().entries
            .map((e) => VideoItem.fromPath(e.value, e.key))
            .toList(),
      );
    }).toList();
    folders.sort((a, b) => a.name.compareTo(b.name));
    return folders;
  }

  /// 用相对路径当显示名，同名子目录也能分清层级
  String _folderLabel(String root, String dir) {
    if (p.equals(dir, root)) return '根目录';
    return p.relative(dir, from: root);
  }

  Future<String?> importVideo(String sourcePath) async {
    return _fileService.copyFileToVideoDir(sourcePath);
  }

  Future<void> deleteVideo(String path) async {
    await _fileService.deleteFile(path);
    videos.removeWhere((v) => v.path == path);
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
