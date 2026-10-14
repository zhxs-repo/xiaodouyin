import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/path_utils.dart';
import '../../core/constants/app_constants.dart';

class FileService {
  String? customVideoDir;
  String? customImageDir;

  FileService({this.customVideoDir, this.customImageDir});

  void updateCustomDirs({String? videoDir, String? imageDir}) {
    customVideoDir = videoDir;
    customImageDir = imageDir;
  }

  Future<List<String>> scanVideoFiles() async {
    try {
      if (customVideoDir != null && customVideoDir!.isNotEmpty) {
        final dir = Directory(customVideoDir!);
        if (!await dir.exists()) await dir.create(recursive: true);
        return await _scanFiles(dir, AppConstants.videoExtensions);
      }
      final videoDir = await _getOrCreateDir(AppConstants.videoDirName);
      return await _scanFiles(videoDir, AppConstants.videoExtensions);
    } catch (_) { return []; }
  }

  /// 视频根目录（自定义目录优先），目录不存在时创建
  Future<String> videoDirPath() async => (await _getVideoDir()).path;

  static const int folderScanMaxDepth = 3;
  static const int _folderScanMaxDirs = 1500;

  /// 递归找出"直接放着视频文件"的目录，返回 目录 -> 该目录下的视频路径。
  ///
  /// 扫描成本控制：限定深度（默认 3 层子目录）与最多访问的目录数；`.` 开头的目录不进入；
  /// 目录内存在 `.nomedia` 时，该目录及其子树整体排除（与系统媒体库语义一致）。
  Future<Map<String, List<String>>> scanVideoDirs({
    int maxDepth = folderScanMaxDepth,
  }) async {
    final result = <String, List<String>>{};
    final root = await _getVideoDir();
    var frontier = <String>[root.path];
    var level = 0;
    var visited = 0;

    while (frontier.isNotEmpty && level <= maxDepth) {
      final nextLevel = <String>[];
      for (final dirPath in frontier) {
        if (visited >= _folderScanMaxDirs) return result;
        visited++;
        final scanned = await _scanDirOnce(dirPath);
        if (scanned == null) continue;
        if (scanned.videos.isNotEmpty) result[dirPath] = scanned.videos;
        if (level < maxDepth) nextLevel.addAll(scanned.subDirs);
      }
      frontier = nextLevel;
      level++;
    }
    return result;
  }

  /// 一次 list() 同时取出子目录与视频文件；返回 null 表示该目录被排除
  Future<_DirScan?> _scanDirOnce(String dirPath) async {
    final subDirs = <String>[];
    final videos = <String>[];
    try {
      await for (final entity
          in Directory(dirPath).list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (name.startsWith('.')) {
          if (entity is File && name.toLowerCase() == '.nomedia') return null;
          continue;
        }
        if (entity is Directory) {
          subDirs.add(entity.path);
        } else if (entity is File && _isVideoName(name)) {
          videos.add(entity.path);
        }
      }
    } catch (_) {
      return null;
    }
    return _DirScan(subDirs, videos);
  }

  bool _isVideoName(String name) {
    final lower = name.toLowerCase();
    return AppConstants.videoExtensions.any(lower.endsWith);
  }

  Future<List<String>> scanImageFiles() async {
    try {
      if (customImageDir != null && customImageDir!.isNotEmpty) {
        final dir = Directory(customImageDir!);
        if (!await dir.exists()) await dir.create(recursive: true);
        return await _scanFiles(dir, AppConstants.imageExtensions);
      }
      final imageDir = await _getOrCreateDir(AppConstants.imageDirName);
      return await _scanFiles(imageDir, AppConstants.imageExtensions);
    } catch (_) { return []; }
  }

  Future<List<String>> scanAudioFiles(String dirPath) async {
    try {
      return await _scanFiles(Directory(dirPath), AppConstants.audioExtensions);
    } catch (_) { return []; }
  }

  Future<String?> copyFileToVideoDir(String sourcePath) async {
    try {
      final videoDir = await _getVideoDir();
      final fileName = p.basename(sourcePath);
      final destPath = p.join(videoDir.path, fileName);
      if (sourcePath == destPath) return destPath;
      // 确保目标目录存在
      if (!await videoDir.exists()) await videoDir.create(recursive: true);
      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('copyFileToVideoDir失败: $e, source=$sourcePath, customVideoDir=$customVideoDir');
      return null;
    }
  }

  Future<String?> copyFileToImageDir(String sourcePath) async {
    try {
      final imageDir = await _getImageDir();
      final fileName = p.basename(sourcePath);
      final destPath = p.join(imageDir.path, fileName);
      if (sourcePath == destPath) return destPath;
      if (!await imageDir.exists()) await imageDir.create(recursive: true);
      await File(sourcePath).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('copyFileToImageDir失败: $e, source=$sourcePath, customImageDir=$customImageDir');
      return null;
    }
  }

  Future<Directory> _getVideoDir() async {
    if (customVideoDir != null && customVideoDir!.isNotEmpty) {
      final dir = Directory(customVideoDir!);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    return _getOrCreateDir(AppConstants.videoDirName);
  }

  Future<Directory> _getImageDir() async {
    if (customImageDir != null && customImageDir!.isNotEmpty) {
      final dir = Directory(customImageDir!);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }
    return _getOrCreateDir(AppConstants.imageDirName);
  }

  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<bool> fileExists(String filePath) async {
    try {
      return File(filePath).exists();
    } catch (_) { return false; }
  }

  Future<Directory> _getOrCreateDir(String dirName) async {
    final baseDir = await PathUtils.getBaseDir();
    final dir = Directory(p.join(baseDir.path, dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<List<String>> _scanFiles(Directory dir, List<String> extensions) async {
    if (!await dir.exists()) return [];
    final results = <String>[];
    await for (final entity in dir.list()) {
      if (entity is File) {
        final path = entity.path.toLowerCase();
        if (extensions.any((ext) => path.endsWith(ext))) {
          results.add(entity.path);
        }
      }
    }
    return results;
  }
}

class _DirScan {
  final List<String> subDirs;
  final List<String> videos;

  const _DirScan(this.subDirs, this.videos);
}
