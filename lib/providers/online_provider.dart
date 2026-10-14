import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../core/constants/app_constants.dart';
import '../core/utils/path_utils.dart';
import '../data/services/online_api_service.dart';
import '../data/models/online_category.dart';

class OnlineProvider extends ChangeNotifier {
  final OnlineApiService _apiService;
  List<OnlineCategory> _videoCategories = [];
  List<OnlineCategory> _imageCategories = [];
  bool _isLoading = false;
  String? _error;

  // 视频滑动列表
  final List<String> _videoUrlList = [];
  int _currentVideoIndex = 0;
  String? _currentCategoryId;
  String? _currentCategoryName;
  bool _isStreaming = false;
  String? _streamingTitle;
  static const int _preloadCount = 3;

  // 图片水平滑动列表
  final List<String> _imageUrlList = [];
  String? _currentImageCategoryId;
  bool _isLoadingMoreImages = false;
  static const int _imageInitialCount = 6;
  static const int _imageKeepAhead = 2;
  static const int _imageFetchBatch = 3;

  // 会话列表：记录当前会话浏览过的视频URL
  final List<SessionItem> _sessionItems = [];

  OnlineProvider(this._apiService);

  List<OnlineCategory> get videoCategories => _videoCategories;
  List<OnlineCategory> get imageCategories => _imageCategories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get videoUrlList => _videoUrlList;
  int get currentVideoIndex => _currentVideoIndex;
  String? get currentCategoryId => _currentCategoryId;
  String? get currentImageCategoryId => _currentImageCategoryId;
  bool get isStreaming => _isStreaming;
  String? get streamingTitle => _streamingTitle;
  List<String> get imageUrlList => _imageUrlList;
  List<SessionItem> get sessionItems => List.unmodifiable(_sessionItems);

  void loadCategories() {
    _videoCategories = _apiService.getVideoCategories();
    _imageCategories = _apiService.getImageCategories();
    notifyListeners();
  }


  /// 初始化视频滑动列表，预加载若干条
  Future<void> initVideoSwipeList(String categoryId, {String categoryName = ''}) async {
    _currentCategoryId = categoryId;
    _currentCategoryName = categoryName;
    _isStreaming = false;
    _streamingTitle = null;
    _videoUrlList.clear();
    _currentVideoIndex = 0;
    _error = null;
    _isLoading = true;
    notifyListeners();

    for (int i = 0; i < _preloadCount; i++) {
      try {
        final url = await _apiService.fetchVideoUrl(categoryId);
        _videoUrlList.add(url);
      } catch (e) {
        if (i == 0) {
          _error = _extractErrorMessage(e);
          _isLoading = false;
          notifyListeners();
          return;
        }
        break;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 进入自定义串流模式：把单条URL塞入播放列表，跳过分类接口
  /// 标记 _isStreaming=true 后，onVideoPageChanged 不会触发分类预加载
  void setStreamingUrl(String url, {String? title}) {
    _currentCategoryId = null;
    _currentCategoryName = title ?? '串流播放';
    _isStreaming = true;
    _streamingTitle = _currentCategoryName;
    _videoUrlList
      ..clear()
      ..add(url);
    _currentVideoIndex = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// 滑动到指定索引，自动预加载更多
  Future<void> onVideoPageChanged(int index) async {
    _currentVideoIndex = index;
    // 记录到会话列表
    if (index < _videoUrlList.length) {
      final url = _videoUrlList[index];
      if (_sessionItems.isEmpty || _sessionItems.last.url != url) {
        _sessionItems.add(SessionItem(url: url, categoryName: _currentCategoryName ?? '', viewedAt: DateTime.now()));
      }
    }
    notifyListeners();

    // 接近末尾时预加载
    if (index >= _videoUrlList.length - 2 && _currentCategoryId != null) {
      for (int i = 0; i < _preloadCount; i++) {
        try {
          final url = await _apiService.fetchVideoUrl(_currentCategoryId!);
          _videoUrlList.add(url);
          notifyListeners();
        } catch (e) {
          break;
        }
      }
    }
  }

  /// 初始化图片水平滑动列表：先出第一张，其余在后台补齐
  Future<void> initImageSwipeList(String categoryId) async {
    _currentImageCategoryId = categoryId;
    _imageUrlList.clear();
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      _imageUrlList.add(await _apiService.fetchAliveImageUrl(categoryId));
    } catch (e) {
      _error = _extractErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = false;
    notifyListeners();

    _loadMoreImages(_imageInitialCount - _imageUrlList.length);
  }

  /// 滑到指定索引，接近末尾时自动补图
  void onImagePageChanged(int index) {
    if (index >= _imageUrlList.length - _imageKeepAhead) {
      _loadMoreImages(_imageFetchBatch);
    }
  }

  Future<void> _loadMoreImages(int count) async {
    final categoryId = _currentImageCategoryId;
    if (categoryId == null || _isLoadingMoreImages || count <= 0) return;
    _isLoadingMoreImages = true;
    for (int i = 0; i < count; i++) {
      try {
        _imageUrlList.add(await _apiService.fetchAliveImageUrl(categoryId));
        notifyListeners();
      } catch (e) {
        break;
      }
    }
    _isLoadingMoreImages = false;
  }

  String _extractErrorMessage(dynamic e) {
    final msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      return msg.substring(11);
    }
    return msg;
  }

  /// 下载在线视频到本地
  Future<String?> downloadVideo(String url, String categoryName) async {
    try {
      final dir = await _getDownloadDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${categoryName}_$timestamp.mp4';
      final savePath = p.join(dir.path, fileName);
      await Dio().download(url, savePath);
      return savePath;
    } catch (e) {
      return null;
    }
  }

  /// 下载在线图片到本地
  Future<String?> downloadImage(String url, String categoryName) async {
    try {
      final dir = await _getDownloadDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${categoryName}_$timestamp.${_imageExtension(url)}';
      final savePath = p.join(dir.path, fileName);
      await Dio().download(url, savePath);
      return savePath;
    } catch (e) {
      return null;
    }
  }

  /// 从图片URL取真实扩展名，取不到则回落 jpg
  String _imageExtension(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final dot = path.lastIndexOf('.');
    if (dot < 0) return 'jpg';
    final ext = path.substring(dot + 1).toLowerCase();
    return AppConstants.imageExtensions.contains('.$ext') ? ext : 'jpg';
  }

  Future<Directory> _getDownloadDir() async {
    final baseDir = await PathUtils.getBaseDir();
    final dir = Directory(p.join(baseDir.path, '在线下载'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

}

class SessionItem {
  final String url;
  final String categoryName;
  final DateTime viewedAt;
  SessionItem({required this.url, required this.categoryName, required this.viewedAt});
}
