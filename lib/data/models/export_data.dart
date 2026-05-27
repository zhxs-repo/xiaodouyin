import 'package:flutter/foundation.dart';
import 'app_config.dart';
import 'favorite_item.dart';
import 'play_history.dart';

@immutable
class ExportData {
  final AppConfig config;
  final int lastVideoIndex;
  final int lastFavoriteIndex;
  final List<FavoriteItem> favoriteVideos;
  final List<String> searchHistory;
  final List<String> notebook;
  final Map<String, PlayHistoryRecord> globalPlayHistory;

  const ExportData({
    required this.config,
    required this.lastVideoIndex,
    required this.lastFavoriteIndex,
    required this.favoriteVideos,
    required this.searchHistory,
    required this.notebook,
    required this.globalPlayHistory,
  });

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'lastVideoIndex': lastVideoIndex,
    'lastFavoriteIndex': lastFavoriteIndex,
    'favoriteVideos': favoriteVideos.map((e) => e.toJson()).toList(),
    'searchHistory': searchHistory,
    'notebook': notebook,
    'globalPlayHistory': globalPlayHistory.map(
      (k, v) => MapEntry(k, v.toJson())),
  };

  factory ExportData.fromJson(Map<String, dynamic> json) => ExportData(
    config: AppConfig.fromJson(json['config'] as Map<String, dynamic>),
    lastVideoIndex: json['lastVideoIndex'] as int? ?? 0,
    lastFavoriteIndex: json['lastFavoriteIndex'] as int? ?? 0,
    favoriteVideos: (json['favoriteVideos'] as List?)
        ?.map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    searchHistory: (json['searchHistory'] as List?)?.cast<String>() ?? [],
    notebook: (json['notebook'] as List?)?.cast<String>() ?? [],
    globalPlayHistory: (json['globalPlayHistory'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(
          k, PlayHistoryRecord.fromJson(v as Map<String, dynamic>))) ?? {},
  );
}
