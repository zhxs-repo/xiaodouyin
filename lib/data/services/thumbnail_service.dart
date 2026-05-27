import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../core/utils/path_utils.dart';

class ThumbnailService {
  static const int maxConcurrency = 5;
  final Map<String, Uint8List> _memoryCache = {};
  static const int maxMemoryCacheSize = 100 * 1024 * 1024; // 100MB
  int _currentCacheSize = 0;

  Future<Uint8List?> getThumbnail(String videoPath) async {
    final safeName = PathUtils.getSafeThumbnailName(videoPath);
    
    // 1. 内存缓存
    if (_memoryCache.containsKey(safeName)) {
      return _memoryCache[safeName];
    }
    
    // 2. 文件缓存
    final cacheDir = await PathUtils.getVideoThumbCacheDir();
    final cacheFile = File('$cacheDir/$safeName');
    if (await cacheFile.exists()) {
      final bytes = await cacheFile.readAsBytes();
      _addToMemoryCache(safeName, bytes);
      return bytes;
    }
    
    // 3. 生成
    return _generateAndCache(videoPath, safeName, cacheDir);
  }

  Future<void> generateBatch(List<String> videoPaths) async {
    final batches = <List<String>>[];
    for (var i = 0; i < videoPaths.length; i += maxConcurrency) {
      batches.add(videoPaths.sublist(
        i, (i + maxConcurrency).clamp(0, videoPaths.length)));
    }
    
    for (final batch in batches) {
      await Future.wait(batch.map((path) async {
        final safeName = PathUtils.getSafeThumbnailName(path);
        final cacheDir = await PathUtils.getVideoThumbCacheDir();
        final cacheFile = File('$cacheDir/$safeName');
        if (!await cacheFile.exists()) {
          await _generateAndCache(path, safeName, cacheDir);
        }
      }));
    }
  }

  Future<void> cleanInvalid(List<String> validVideoPaths) async {
    final cacheDir = await PathUtils.getVideoThumbCacheDir();
    final dir = Directory(cacheDir);
    if (!await dir.exists()) return;
    
    final validNames = validVideoPaths.map(PathUtils.getSafeThumbnailName).toSet();
    
    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = p.basename(entity.path);
        if (!validNames.contains(name)) {
          await entity.delete();
        }
      }
    }
  }

  Future<Uint8List?> _generateAndCache(String videoPath, String safeName, String cacheDir) async {
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 75,
      );
      
      if (bytes != null) {
        final cacheFile = File('$cacheDir/$safeName');
        await cacheFile.writeAsBytes(bytes);
        _addToMemoryCache(safeName, bytes);
      }
      
      return bytes;
    } catch (_) {
      return null;
    }
  }

  void _addToMemoryCache(String key, Uint8List bytes) {
    // LRU淘汰：超限时移除最旧条目直到有足够空间
    while (_currentCacheSize + bytes.length > maxMemoryCacheSize && _memoryCache.isNotEmpty) {
      final oldestKey = _memoryCache.keys.first;
      final removed = _memoryCache.remove(oldestKey);
      if (removed != null) _currentCacheSize -= removed.length;
    }
    _memoryCache[key] = bytes;
    _currentCacheSize += bytes.length;
  }
}
