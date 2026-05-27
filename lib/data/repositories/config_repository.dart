import '../services/storage_service.dart';
import '../models/app_config.dart';
import '../models/export_data.dart';
import '../models/favorite_item.dart';
import '../models/play_history.dart';

class ConfigRepository {
  final StorageService _storage;
  AppConfig _config = const AppConfig();

  ConfigRepository(this._storage);

  AppConfig get config => _config;

  Future<void> load() async {
    final json = _storage.getJson('appConfig');
    if (json != null) {
      _config = AppConfig.fromJson(json);
    }
  }

  Future<void> _save() async {
    await _storage.setJson('appConfig', _config.toJson());
  }

  Future<void> updateConfig(AppConfig config) async {
    _config = config;
    await _save();
  }

  Future<Map<String, dynamic>> exportAll({
    required int lastVideoIndex,
    required int lastFavoriteIndex,
    required List<FavoriteItem> favoriteVideos,
    required List<String> searchHistory,
    required List<String> notebook,
    required Map<String, PlayHistoryRecord> globalPlayHistory,
  }) async {
    final data = ExportData(
      config: _config,
      lastVideoIndex: lastVideoIndex,
      lastFavoriteIndex: lastFavoriteIndex,
      favoriteVideos: favoriteVideos,
      searchHistory: searchHistory,
      notebook: notebook,
      globalPlayHistory: globalPlayHistory,
    );
    return data.toJson();
  }

  Future<AppConfig> importConfig(Map<String, dynamic> data) async {
    _config = AppConfig.fromJson(data['config'] as Map<String, dynamic>);
    await _save();
    return _config;
  }
}
