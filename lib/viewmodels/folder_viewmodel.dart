import 'dart:io';
import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../data/services/file_service.dart';
import '../data/services/thumbnail_service.dart';

/// 文件夹管理视图模型
class FolderViewModel extends ChangeNotifier {
  final FileService _fileService = FileService();
  final ThumbnailService _thumbnailService = ThumbnailService();

  List<FolderItem> _folders = [];
  bool _isLoading = false;
  String? _error;

  List<FolderItem> get folders => _folders;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 扫描媒体文件夹
  Future<void> scanFolders() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 获取所有视频文件
      final videoFiles = await _fileService.getAllVideoFiles();
      
      // 按文件夹分组
      final Map<String, List<VideoItem>> folderMap = {};
      
      for (final file in videoFiles) {
        final dirPath = file.path.substring(0, file.path.lastIndexOf('/'));
        if (!folderMap.containsKey(dirPath)) {
          folderMap[dirPath] = [];
        }
        folderMap[dirPath]!.add(file);
      }

      // 转换为 FolderItem 列表
      _folders = [];
      for (final entry in folderMap.entries) {
        final dirPath = entry.key;
        final videos = entry.value;
        
        if (videos.isEmpty) continue;

        // 排序：按修改时间倒序
        videos.sort((a, b) => b.lastModified.compareTo(a.lastModified));

        // 确定封面：最后一次播放的视频缩略图，或第一个视频的缩略图
        VideoItem coverVideo;
        if (videos.any((v) => v.lastPlayedAt != null)) {
          // 有播放历史的，取最近播放的
          final playedVideos = videos.where((v) => v.lastPlayedAt != null).toList();
          playedVideos.sort((a, b) => b.lastPlayedAt!.compareTo(a.lastPlayedAt!));
          coverVideo = playedVideos.first;
        } else {
          // 无播放历史的，取第一个（最新修改的）
          coverVideo = videos.first;
        }

        // 生成缩略图
        final thumbnail = await _thumbnailService.getThumbnail(coverVideo.path);

        _folders.add(FolderItem(
          path: dirPath,
          name: dirPath.split('/').last,
          videoCount: videos.length,
          coverThumbnail: thumbnail,
          lastPlayedTime: videos.map((v) => v.lastPlayedAt).nonNulls.maxOrNull,
          recentVideos: videos.take(3).toList(),
        ));
      }

      // 按最后播放时间排序文件夹
      _folders.sort((a, b) {
        if (a.lastPlayedTime == null && b.lastPlayedTime == null) return 0;
        if (a.lastPlayedTime == null) return 1;
        if (b.lastPlayedTime == null) return -1;
        return b.lastPlayedTime!.compareTo(a.lastPlayedTime!);
      });

    } catch (e) {
      _error = '扫描失败：$e';
      print('[FolderViewModel] 扫描错误：$e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 刷新单个文件夹
  Future<void> refreshFolder(String folderPath) async {
    await scanFolders();
  }
}

/// 文件夹数据模型
class FolderItem {
  final String path;
  final String name;
  final int videoCount;
  final Uint8List? coverThumbnail;
  final DateTime? lastPlayedTime;
  final List<VideoItem> recentVideos;

  FolderItem({
    required this.path,
    required this.name,
    required this.videoCount,
    this.coverThumbnail,
    this.lastPlayedTime,
    required this.recentVideos,
  });

  /// 获取格式化后的最后播放时间
  String get formattedLastPlayedTime {
    if (lastPlayedTime == null) return '未播放';
    
    final now = DateTime.now();
    final diff = now.difference(lastPlayedTime!);
    
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()}年前';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()}个月前';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}天前';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  /// 获取最近视频的信息摘要
  String get recentInfo {
    if (recentVideos.isEmpty) return '0 个视频';
    
    final formats = recentVideos.map((v) {
      final ext = v.path.split('.').last.toUpperCase();
      return ext;
    }).toSet().take(2).join('/');
    
    final totalDuration = recentVideos.fold<int>(
      0,
      (sum, v) => sum + (v.duration?.inSeconds ?? 0),
    );
    
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;
    
    return '$formats · ${hours}h${minutes}m';
  }
}
