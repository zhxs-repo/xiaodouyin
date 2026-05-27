import 'package:flutter/foundation.dart';

@immutable
class FavoriteItem {
  final String filePath;
  final int index;

  const FavoriteItem({
    required this.filePath,
    required this.index,
  });

  FavoriteItem copyWith({String? filePath, int? index}) => FavoriteItem(
    filePath: filePath ?? this.filePath,
    index: index ?? this.index,
  );

  Map<String, dynamic> toJson() => {'filePath': filePath, 'index': index};

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    filePath: json['filePath'] as String,
    index: json['index'] as int,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteItem && other.filePath == filePath;

  @override
  int get hashCode => filePath.hashCode;
}
