import 'package:flutter/material.dart';
import '../data/repositories/search_repository.dart';
import '../data/models/video_item.dart';
import '../data/repositories/video_repository.dart';

class SearchProvider extends ChangeNotifier {
  final SearchRepository _searchRepo;
  final VideoRepository _videoRepo;
  String _keyword = '';
  String? _selectedBlogger;
  List<VideoItem> _results = [];

  SearchProvider(this._searchRepo, this._videoRepo);

  String get keyword => _keyword;
  String? get selectedBlogger => _selectedBlogger;
  List<VideoItem> get results => _results;
  List<String> get searchHistory => _searchRepo.history;
  Map<String, List<VideoItem>> get bloggerGroups => _videoRepo.groupByBlogger();

  Future<void> load() async {
    await _searchRepo.load();
    notifyListeners();
  }

  void search(String keyword) {
    _keyword = keyword;
    _selectedBlogger = null;
    if (keyword.isEmpty) {
      _results = _videoRepo.videos;
    } else {
      _results = _videoRepo.search(keyword);
    }
    _searchRepo.addKeyword(keyword);
    notifyListeners();
  }

  void filterByBlogger(String bloggerName) {
    _selectedBlogger = bloggerName;
    _keyword = '';
    _results = _videoRepo.videos.where((v) =>
      v.bloggerName == bloggerName).toList();
    notifyListeners();
  }

  void clearFilter() {
    _keyword = '';
    _selectedBlogger = null;
    _results = _videoRepo.videos;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _searchRepo.clearHistory();
    notifyListeners();
  }

}
