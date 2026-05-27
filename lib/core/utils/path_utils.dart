import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../constants/app_constants.dart';
import 'platform_utils.dart';

class PathUtils {
  static String getSafeThumbnailName(String filePath) {
    final bytes = utf8.encode(filePath);
    final digest = md5.convert(bytes);
    return '${digest.toString()}.jpg';
  }
  
  static String getCleanVideoPath(String path, String baseUrl) {
    var clean = path.replaceAll(baseUrl, '');
    clean = Uri.decodeComponent(clean);
    clean = clean.split('?').first;
    return clean;
  }
  
  static Future<String> getVideoThumbCacheDir() async {
    final baseDir = await getBaseDir();
    final dir = Directory('${baseDir.path}/${AppConstants.videoThumbDirName}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }
  
  static Future<String> getImageThumbCacheDir() async {
    final baseDir = await getBaseDir();
    final dir = Directory('${baseDir.path}/${AppConstants.imageThumbDirName}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }
  
  static Future<String> getVideoDir({String? customDir}) async {
    if (customDir != null && customDir.isNotEmpty) {
      final dir = Directory(customDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    }
    final baseDir = await getBaseDir();
    final dir = Directory('${baseDir.path}/${AppConstants.videoDirName}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }
  
  static Future<String> getImageDir({String? customDir}) async {
    if (customDir != null && customDir.isNotEmpty) {
      final dir = Directory(customDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir.path;
    }
    final baseDir = await getBaseDir();
    final dir = Directory('${baseDir.path}/${AppConstants.imageDirName}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }
  
  static Future<String> getDataDir() async {
    final baseDir = await getBaseDir();
    final dir = Directory('${baseDir.path}/${AppConstants.dataDirName}');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  /// 获取基础目录：Android优先使用外部存储目录（用户可见），其他平台使用应用支持目录
  static Future<Directory> getBaseDir() async {
    if (PlatformUtils.isAndroid) {
      try {
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) return externalDir;
      } catch (_) {}
    }
    return getApplicationSupportDirectory();
  }
}
