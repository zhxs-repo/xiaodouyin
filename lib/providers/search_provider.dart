import 'package:flutter/foundation.dart';
import '../data/repositories/search_repository.dart';
import '../data/models/video_item.dart';

/// 搜索结果是一次性的过滤产物，数据源由调用方（当前播放列表）传入，
/// 避免持有一份与播放页不同步的仓库副本。
class SearchProvider extends ChangeNotifier {
  final SearchRepository _searchRepo;
  String _keyword = '';
  String? _selectedBlogger;
  List<VideoItem> _results = const [];

  SearchProvider(this._searchRepo);

  String get keyword => _keyword;
  String? get selectedBlogger => _selectedBlogger;
  List<VideoItem> get results => _results;
  List<String> get searchHistory => _searchRepo.history;
  bool get hasActiveFilter => _keyword.isNotEmpty || _selectedBlogger != null;

  Future<void> load() async {
    await _searchRepo.load();
    notifyListeners();
  }

  bool _matches(VideoItem v) {
    if (_selectedBlogger != null) return v.bloggerName == _selectedBlogger;
    final lower = _keyword.toLowerCase();
    return v.fileName.toLowerCase().contains(lower) ||
        (v.bloggerName?.toLowerCase().contains(lower) ?? false) ||
        (v.douyinId?.contains(lower) ?? false);
  }

  void search(List<VideoItem> source, String keyword) {
    _keyword = keyword;
    _selectedBlogger = null;
    _results = keyword.isEmpty ? const [] : source.where(_matches).toList();
    _searchRepo.addKeyword(keyword);
    notifyListeners();
  }

  void filterByBlogger(List<VideoItem> source, String bloggerName) {
    _selectedBlogger = bloggerName;
    _keyword = '';
    _results = source.where(_matches).toList();
    notifyListeners();
  }

  /// 数据源发生变化（如删除视频）后，按当前条件重新过滤，避免结果里残留失效项
  void reapply(List<VideoItem> source) {
    if (!hasActiveFilter) return;
    _results = source.where(_matches).toList();
    notifyListeners();
  }

  Map<String, List<VideoItem>> bloggerGroups(List<VideoItem> source) {
    final map = <String, List<VideoItem>>{};
    for (final v in source) {
      map.putIfAbsent(v.bloggerName ?? '未知', () => []).add(v);
    }
    return map;
  }

  void clearFilter() {
    _keyword = '';
    _selectedBlogger = null;
    _results = const [];
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _searchRepo.clearHistory();
    notifyListeners();
  }
}
