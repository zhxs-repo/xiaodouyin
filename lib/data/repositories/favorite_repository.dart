import '../services/storage_service.dart';
import '../models/favorite_item.dart';
import '../../core/constants/storage_keys.dart';

class FavoriteRepository {
  final StorageService _storage;
  List<FavoriteItem> _favorites = [];

  FavoriteRepository(this._storage);

  List<FavoriteItem> get favorites => _favorites;

  Future<void> load() async {
    final json = _storage.getJson(StorageKeys.favoriteVideos);
    if (json != null) {
      final list = json['items'] as List? ?? [];
      _favorites = list.map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _save() async {
    await _storage.setJson(StorageKeys.favoriteVideos, {
      'items': _favorites.map((e) => e.toJson()).toList(),
    });
  }

  Future<bool> toggle(String filePath, int index) async {
    final existing = _favorites.indexWhere((f) => f.filePath == filePath);
    if (existing >= 0) {
      _favorites.removeAt(existing);
    } else {
      _favorites.add(FavoriteItem(filePath: filePath, index: index));
    }
    await _save();
    return existing < 0;
  }

  bool isFavorite(String filePath) =>
      _favorites.any((f) => f.filePath == filePath);

  Future<void> calibrate(List<String> existingPaths) async {
    final pathSet = existingPaths.toSet();
    _favorites.removeWhere((f) => !pathSet.contains(f.filePath));
    await _save();
  }
}
