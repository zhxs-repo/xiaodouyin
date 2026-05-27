import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../core/utils/path_utils.dart';
import '../data/services/online_api_service.dart';
import '../data/models/online_category.dart';

class OnlineProvider extends ChangeNotifier {
  final OnlineApiService _apiService;
  List<OnlineCategory> _videoCategories = [];
  List<OnlineCategory> _imageCategories = [];
  String? _currentVideoUrl;
  String? _currentImageUrl;
  bool _isLoading = false;
  String? _error;

  // 视频滑动列表
  final List<String> _videoUrlList = [];
  int _currentVideoIndex = 0;
  String? _currentCategoryId;
  String? _currentCategoryName;
  static const int _preloadCount = 3;

  // 会话列表：记录当前会话浏览过的视频URL
  final List<SessionItem> _sessionItems = [];

  OnlineProvider(this._apiService);

  List<OnlineCategory> get videoCategories => _videoCategories;
  List<OnlineCategory> get imageCategories => _imageCategories;
  String? get currentVideoUrl => _currentVideoUrl;
  String? get currentImageUrl => _currentImageUrl;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get videoUrlList => _videoUrlList;
  int get currentVideoIndex => _currentVideoIndex;
  String? get currentCategoryId => _currentCategoryId;
  List<SessionItem> get sessionItems => List.unmodifiable(_sessionItems);

  void loadCategories() {
    _videoCategories = _apiService.getVideoCategories();
    _imageCategories = _apiService.getImageCategories();
    notifyListeners();
  }

  Future<void> fetchVideo(String categoryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _currentVideoUrl = await _apiService.fetchVideoUrl(categoryId);
    } catch (e) {
      _error = _extractErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchImage(String categoryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _currentImageUrl = await _apiService.fetchImageUrl(categoryId);
    } catch (e) {
      _error = _extractErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 初始化视频滑动列表，预加载若干条
  Future<void> initVideoSwipeList(String categoryId, {String categoryName = ''}) async {
    _currentCategoryId = categoryId;
    _currentCategoryName = categoryName;
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
      final fileName = '${categoryName}_$timestamp.jpg';
      final savePath = p.join(dir.path, fileName);
      await Dio().download(url, savePath);
      return savePath;
    } catch (e) {
      return null;
    }
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
