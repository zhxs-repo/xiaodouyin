import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/repositories/favorite_repository.dart';
import '../data/models/favorite_item.dart';
import '../core/constants/app_constants.dart';

class FavoriteProvider extends ChangeNotifier {
  final FavoriteRepository _repository;
  bool _isFavoriteMode = false;
  int _lastAutoSaveCount = 0; // 上次自动导出时的收藏数

  FavoriteProvider(this._repository);

  List<FavoriteItem> get favorites => _repository.favorites;
  bool get isFavoriteMode => _isFavoriteMode;

  Future<void> load() async {
    await _repository.load();
    _lastAutoSaveCount = favorites.length;
    notifyListeners();
  }

  Future<bool> toggleFavorite(String filePath, int index) async {
    final added = await _repository.toggle(filePath, index);
    notifyListeners();
    // 自动导出检查：收藏数是3的倍数且不等于上次导出时的数量
    _checkAutoExport();
    return added;
  }

  /// 自动导出：收藏数达到阈值时自动保存存档
  Future<void> _checkAutoExport() async {
    final count = favorites.length;
    if (count > 0 && count % AppConstants.favoriteAutoExportThreshold == 0 && count != _lastAutoSaveCount) {
      _lastAutoSaveCount = count;
      try {
        final exportData = <String, dynamic>{
          'favoriteVideos': favorites.map((e) => e.toJson()).toList(),
          'timestamp': DateTime.now().toIso8601String(),
        };
        final dir = await getApplicationSupportDirectory();
        final dataDir = Directory(p.join(dir.path, AppConstants.dataDirName));
        if (!await dataDir.exists()) await dataDir.create(recursive: true);
        final fileName = '自动存档_收藏${count}个_${DateTime.now().millisecondsSinceEpoch}.json';
        final file = File(p.join(dataDir.path, fileName));
        await file.writeAsString(jsonEncode(exportData));
      } catch (_) {
        // 静默失败，不影响收藏操作
      }
    }
  }

  bool isFavorite(String filePath) => _repository.isFavorite(filePath);

  void enterFavoriteMode() {
    _isFavoriteMode = true;
    notifyListeners();
  }

  void exitFavoriteMode() {
    _isFavoriteMode = false;
    notifyListeners();
  }

  Future<void> calibrate(List<String> existingPaths) async {
    await _repository.calibrate(existingPaths);
    notifyListeners();
  }

}
