import 'package:flutter/material.dart';
import '../data/models/video_item.dart';

enum VideoPlayMode { normal, loop, favorite, random, list, online }

class VideoPlayerProvider extends ChangeNotifier {
  VideoPlayMode _playMode = VideoPlayMode.normal;
  int _currentIndex = 0;
  bool _isPlaying = false;
  double _playbackRate = 1.0;
  bool _isGestureMode = false;
  List<VideoItem> _videoList = [];
  List<VideoItem> _displayList = [];
  List<VideoItem> _originalList = []; // 进入列表/收藏模式前的原始列表
  bool _isListMode = false;
  bool _isFavoriteMode = false;

  VideoPlayMode get playMode => _playMode;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _isPlaying;
  double get playbackRate => _playbackRate;
  bool get isGestureMode => _isGestureMode;
  bool get isListMode => _isListMode;
  bool get isFavoriteMode => _isFavoriteMode;
  List<VideoItem> get videoList => _videoList;
  List<VideoItem> get displayList => _displayList;
  List<String> get displayPathList => _displayList.map((v) => v.path).toList();
  VideoItem? get currentVideo =>
      _displayList.isNotEmpty && _currentIndex < _displayList.length
          ? _displayList[_currentIndex] : null;

  void setVideoList(List<VideoItem> videos) {
    _videoList = videos;
    _displayList = List.from(videos);
    _currentIndex = 0;
    notifyListeners();
  }

  void setDisplayList(List<VideoItem> videos, {int? startIndex}) {
    _originalList = List.from(_displayList); // 保存当前列表以便退出时恢复
    _displayList = videos;
    _currentIndex = startIndex ?? 0;
    _isListMode = true;
    _isFavoriteMode = false;
    notifyListeners();
  }

  /// 进入收藏模式播放
  void enterFavoritePlayMode(List<VideoItem> favoriteVideos, {int? startIndex}) {
    _originalList = List.from(_displayList);
    _displayList = favoriteVideos;
    _currentIndex = startIndex ?? 0;
    _isFavoriteMode = true;
    _isListMode = false;
    notifyListeners();
  }

  /// 退出列表/收藏模式，恢复原始列表
  void exitSubMode() {
    if (_isListMode || _isFavoriteMode) {
      _displayList = _originalList.isNotEmpty ? _originalList : List.from(_videoList);
      _currentIndex = _currentIndex.clamp(0, _displayList.length - 1);
      _isListMode = false;
      _isFavoriteMode = false;
      _originalList = [];
      notifyListeners();
    }
  }

  /// 仅更新当前索引，不操作player（页面自行管理播放器时使用）
  void updateCurrentIndex(int index) {
    if (index < 0 || index >= _displayList.length) return;
    _currentIndex = index;
    notifyListeners();
  }

  void setPlaying(bool playing) {
    _isPlaying = playing;
    notifyListeners();
  }

  void setPlaybackRate(double rate) {
    _playbackRate = rate;
    notifyListeners();
  }

  void setPlayMode(VideoPlayMode mode) {
    _playMode = mode;
    notifyListeners();
  }

  void enterGestureMode() {
    _isGestureMode = true;
    notifyListeners();
  }

  void exitGestureMode() {
    _isGestureMode = false;
    notifyListeners();
  }
}
