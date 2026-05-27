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
