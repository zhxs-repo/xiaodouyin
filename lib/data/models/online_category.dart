import 'package:flutter/foundation.dart';

enum CategoryType { video, image }

@immutable
class OnlineCategory {
  final String id;
  final String name;
  final CategoryType type;

  const OnlineCategory({
    required this.id,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
  };

  factory OnlineCategory.fromJson(Map<String, dynamic> json) => OnlineCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    type: CategoryType.values.firstWhere((e) => e.name == json['type']),
  );
}
