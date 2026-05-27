import '../services/storage_service.dart';
import '../../core/constants/storage_keys.dart';

class SearchRepository {
  final StorageService _storage;
  List<String> _history = [];

  SearchRepository(this._storage);

  List<String> get history => _history;

  Future<void> load() async {
    _history = _storage.getStringList(StorageKeys.videoSearchHistory) ?? [];
  }

  Future<void> _save() async {
    await _storage.setStringList(StorageKeys.videoSearchHistory, _history);
  }

  Future<void> addKeyword(String keyword) async {
    if (keyword.trim().isEmpty) return;
    _history.remove(keyword);
    _history.insert(0, keyword);
    if (_history.length > 20) _history = _history.sublist(0, 20);
    await _save();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _save();
  }
}
