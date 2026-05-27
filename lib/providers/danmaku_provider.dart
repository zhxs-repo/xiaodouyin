import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/danmaku_word_lib.dart';
import '../core/constants/bullet_constants.dart';

class DanmakuItem {
  final String text;
  final int row;
  final DateTime startTime;
  DanmakuItem({required this.text, required this.row, required this.startTime});
}

class DanmakuProvider extends ChangeNotifier {
  DanmakuWordLib _wordLib = DanmakuWordLib.defaultLib();
  final List<DanmakuItem> _activeBullets = [];
  bool _isEnabled = false;
  Timer? _generateTimer;
  Timer? _notifyTimer;
  final Random _random = Random();
  bool _needsNotify = false;

  DanmakuWordLib get wordLib => _wordLib;
  bool get isEnabled => _isEnabled;
  List<DanmakuItem> get activeBullets => List.unmodifiable(_activeBullets);

  void loadWordLib(DanmakuWordLib lib) {
    _wordLib = lib;
    notifyListeners();
  }

  void toggle() {
    if (_isEnabled) {
      stop();
    } else {
      start();
    }
  }

  void start() {
    _isEnabled = true;
    _generateTimer?.cancel();
    _generateTimer = Timer.periodic(
      Duration(milliseconds: BulletConstants.intervalMs),
      (_) => _generateBullet(),
    );
    // 通知频率限制：每200ms最多通知一次
    _notifyTimer?.cancel();
    _notifyTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_needsNotify) {
        _needsNotify = false;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void stop() {
    _isEnabled = false;
    _generateTimer?.cancel();
    _generateTimer = null;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _activeBullets.clear();
    notifyListeners();
  }

  void _generateBullet() {
    final text = _generateRandomSentence();
    final row = _random.nextInt(BulletConstants.rows);
    final bullet = DanmakuItem(
      text: text,
      row: row,
      startTime: DateTime.now(),
    );
    _activeBullets.add(bullet);

    // 清理过期弹幕
    final now = DateTime.now();
    _activeBullets.removeWhere((b) =>
      now.difference(b.startTime).inSeconds > BulletConstants.speed + 1);

    _needsNotify = true;
  }

  String _generateRandomSentence() {
    final template = _wordLib.templates[_random.nextInt(_wordLib.templates.length)];
    
    var result = template;
    result = result.replaceAll('{感叹}', _randomFrom(_wordLib.exclamations));
    result = result.replaceAll('{形容词}', _randomFrom(_wordLib.adjectives));
    result = result.replaceAll('{主语}', _randomFrom(_wordLib.subjects));
    result = result.replaceAll('{动词}', _randomFrom(_wordLib.verbs));
    result = result.replaceAll('{后缀}', _randomFrom(_wordLib.suffixes));
    result = result.replaceAll('{主}', _randomFrom(_wordLib.subjects));
    
    return result;
  }

  String _randomFrom(List<String> list) {
    if (list.isEmpty) return '';
    return list[_random.nextInt(list.length)];
  }

  @override
  void dispose() {
    _generateTimer?.cancel();
    _notifyTimer?.cancel();
    super.dispose();
  }
}
