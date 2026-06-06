import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/models/danmaku_word_lib.dart';
import '../core/constants/bullet_constants.dart';
import '../core/constants/storage_keys.dart';
import '../data/services/storage_service.dart';

enum DanmakuPosition { scroll, top, bottom }

enum DanmakuSize { small, medium, large }

enum DanmakuDensity { low, medium, high }

extension DanmakuConfigX on DanmakuConfig {
  double get fontPx => switch (size) {
    DanmakuSize.small => 18.0,
    DanmakuSize.medium => 22.0,
    DanmakuSize.large => 28.0,
  };
  int get intervalMs => switch (density) {
    DanmakuDensity.low => 3000,
    DanmakuDensity.medium => 2000,
    DanmakuDensity.high => 800,
  };
  int get rows => switch (position) {
    DanmakuPosition.scroll => 8,
    DanmakuPosition.top => 3,
    DanmakuPosition.bottom => 3,
  };
  double get opacityValue => opacity.clamp(0.1, 1.0);
}

class DanmakuConfig {
  final int colorValue; // Color int
  final DanmakuSize size;
  final DanmakuPosition position;
  final double opacity; // 0.0 - 1.0
  final DanmakuDensity density;
  final List<String> blocklist;

  const DanmakuConfig({
    this.colorValue = 0xFFFFFFFF,
    this.size = DanmakuSize.medium,
    this.position = DanmakuPosition.scroll,
    this.opacity = 1.0,
    this.density = DanmakuDensity.medium,
    this.blocklist = const [],
  });

  DanmakuConfig copyWith({
    int? colorValue,
    DanmakuSize? size,
    DanmakuPosition? position,
    double? opacity,
    DanmakuDensity? density,
    List<String>? blocklist,
  }) => DanmakuConfig(
    colorValue: colorValue ?? this.colorValue,
    size: size ?? this.size,
    position: position ?? this.position,
    opacity: opacity ?? this.opacity,
    density: density ?? this.density,
    blocklist: blocklist ?? this.blocklist,
  );

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
    'colorValue': colorValue,
    'size': size.name,
    'position': position.name,
    'opacity': opacity,
    'density': density.name,
    'blocklist': blocklist,
  };

  factory DanmakuConfig.fromJson(Map<String, dynamic> json) => DanmakuConfig(
    colorValue: json['colorValue'] as int? ?? 0xFFFFFFFF,
    size: DanmakuSize.values.firstWhere(
      (e) => e.name == json['size'], orElse: () => DanmakuSize.medium),
    position: DanmakuPosition.values.firstWhere(
      (e) => e.name == json['position'], orElse: () => DanmakuPosition.scroll),
    opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
    density: DanmakuDensity.values.firstWhere(
      (e) => e.name == json['density'], orElse: () => DanmakuDensity.medium),
    blocklist: (json['blocklist'] as List?)?.cast<String>() ?? const [],
  );
}

class DanmakuItem {
  final String text;
  final int row;
  final DateTime startTime;
  final DanmakuPosition position;
  final int colorValue;
  final double fontSize;
  final double opacity;

  DanmakuItem({
    required this.text,
    required this.row,
    required this.startTime,
    required this.position,
    required this.colorValue,
    required this.fontSize,
    required this.opacity,
  });
}

class DanmakuProvider extends ChangeNotifier {
  DanmakuWordLib _wordLib = DanmakuWordLib.defaultLib();
  final List<DanmakuItem> _activeBullets = [];
  bool _isEnabled = false;
  Timer? _generateTimer;
  Timer? _notifyTimer;
  final Random _random = Random();
  bool _needsNotify = false;
  DanmakuConfig _config = const DanmakuConfig();
  bool _loaded = false;

  DanmakuWordLib get wordLib => _wordLib;
  bool get isEnabled => _isEnabled;
  List<DanmakuItem> get activeBullets => List.unmodifiable(_activeBullets);
  DanmakuConfig get config => _config;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final storage = await StorageService.getInstance();
      final raw = storage.getString(StorageKeys.danmakuBlocklist);
      if (raw != null) {
        try {
          final list = (jsonDecode(raw) as List).cast<String>();
          _config = _config.copyWith(blocklist: list);
        } catch (_) {}
      }
      _config = _config.copyWith(
        colorValue: storage.getInt(StorageKeys.danmakuColor) ?? _config.colorValue,
        size: DanmakuSize.values[storage.getInt(StorageKeys.danmakuFontSize) ?? 1],
        position: DanmakuPosition.values[storage.getInt(StorageKeys.danmakuPosition) ?? 0],
        opacity: storage.getDouble(StorageKeys.danmakuOpacity) ?? _config.opacity,
        density: DanmakuDensity.values[storage.getInt(StorageKeys.danmakuDensity) ?? 1],
      );
    } catch (_) {
      // ignore - keep defaults
    }
  }

  Future<void> _saveConfig() async {
    final storage = await StorageService.getInstance();
    await storage.setInt(StorageKeys.danmakuColor, _config.colorValue);
    await storage.setInt(StorageKeys.danmakuFontSize, _config.size.index);
    await storage.setInt(StorageKeys.danmakuPosition, _config.position.index);
    await storage.setDouble(StorageKeys.danmakuOpacity, _config.opacity);
    await storage.setInt(StorageKeys.danmakuDensity, _config.density.index);
    await storage.setString(StorageKeys.danmakuBlocklist, jsonEncode(_config.blocklist));
  }

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
      Duration(milliseconds: _config.intervalMs),
      (_) => _generateBullet(),
    );
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

  void updateConfig(DanmakuConfig config) {
    final wasEnabled = _isEnabled;
    _config = config;
    if (wasEnabled) {
      // 重新启动以应用新密度
      stop();
      start();
    } else {
      notifyListeners();
    }
    _saveConfig();
  }

  void _generateBullet() {
    var text = _generateRandomSentence();
    // 屏蔽词过滤
    for (final word in _config.blocklist) {
      if (word.isEmpty) continue;
      if (text.contains(word)) {
        text = ''; // 整条丢弃
        break;
      }
    }
    if (text.isEmpty) return;
    final row = _random.nextInt(_config.rows);
    final bullet = DanmakuItem(
      text: text,
      row: row,
      startTime: DateTime.now(),
      position: _config.position,
      colorValue: _config.colorValue,
      fontSize: _config.fontPx,
      opacity: _config.opacityValue,
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
