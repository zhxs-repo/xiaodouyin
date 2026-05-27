import 'package:flutter/foundation.dart';

@immutable
class DanmakuWordLib {
  final List<String> exclamations;
  final List<String> adjectives;
  final List<String> subjects;
  final List<String> verbs;
  final List<String> suffixes;
  final List<String> templates;

  const DanmakuWordLib({
    required this.exclamations,
    required this.adjectives,
    required this.subjects,
    required this.verbs,
    required this.suffixes,
    required this.templates,
  });

  factory DanmakuWordLib.defaultLib() => const DanmakuWordLib(
    exclamations: ['哇', '啊', '天哪', '好棒', '厉害', '绝了', '太强了', '我的天'],
    adjectives: ['漂亮的', '可爱的', '迷人的', '优雅的', '甜美的', '温柔的', '惊艳的', '完美的'],
    subjects: ['小姐姐', '仙女', '女神', '宝贝', '公主', '美人', '佳人', '萝莉'],
    verbs: ['跳舞', '微笑', '转身', '回眸', '走秀', '表演', '展示', '亮相'],
    suffixes: ['呢', '啊', '呀', '啦', '嘛', '哦', '哈', '呗'],
    templates: [
      '{感叹}{形容词}{主语}{动词}{后缀}',
      '{感叹}！{主}{动词}太{形容词}',
      '{形容词}{主语}，{感叹}！',
      '{主语}{动词}，{感叹}{后缀}',
    ],
  );

  factory DanmakuWordLib.fromJson(Map<String, dynamic> json) => DanmakuWordLib(
    exclamations: (json['exclamations'] as List).cast<String>(),
    adjectives: (json['adjectives'] as List).cast<String>(),
    subjects: (json['subjects'] as List).cast<String>(),
    verbs: (json['verbs'] as List).cast<String>(),
    suffixes: (json['suffixes'] as List).cast<String>(),
    templates: (json['templates'] as List).cast<String>(),
  );

  Map<String, dynamic> toJson() => {
    'exclamations': exclamations,
    'adjectives': adjectives,
    'subjects': subjects,
    'verbs': verbs,
    'suffixes': suffixes,
    'templates': templates,
  };
}
