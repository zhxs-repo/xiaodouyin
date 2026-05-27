import '../services/storage_service.dart';
import '../models/play_history.dart';
import '../../core/constants/storage_keys.dart';

class PlayHistoryRepository {
  final StorageService _storage;
  Map<String, PlayHistoryRecord> _history = {};

  PlayHistoryRepository(this._storage);

  Map<String, PlayHistoryRecord> get history => _history;

  Future<void> load() async {
    final json = _storage.getJson(StorageKeys.globalVideoPlayHistory);
    if (json != null) {
      _history = json.map((k, v) => MapEntry(
        k, PlayHistoryRecord.fromJson(v as Map<String, dynamic>)));
    }
  }

  Future<void> _save() async {
    await _storage.setJson(StorageKeys.globalVideoPlayHistory,
      _history.map((k, v) => MapEntry(k, v.toJson())));
  }

  Future<void> saveRecord(PlayHistoryRecord record) async {
    if (!record.isValid) return;
    _history[record.videoPath] = record;
    await _save();
  }

  PlayHistoryRecord? getRecord(String videoPath) => _history[videoPath];

  Future<void> clearRecord(String videoPath) async {
    _history.remove(videoPath);
    await _save();
  }

  Future<void> clearAll() async {
    _history.clear();
    await _save();
  }
}
