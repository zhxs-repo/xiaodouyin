import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../data/models/danmaku_word_lib.dart';
import '../data/models/xml_danmaku.dart';
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

  List<XmlDanmaku> _timeline = const [];
  int _timelineCursor = 0;
  double _timelineLastSec = -1;
  String? _timelineSource;

  DanmakuWordLib get wordLib => _wordLib;
  bool get isEnabled => _isEnabled;
  List<DanmakuItem> get activeBullets => List.unmodifiable(_activeBullets);
  DanmakuConfig get config => _config;

  /// 当前时间轴弹幕来源（文件名），未加载时为 null
  String? get timelineSource => _timelineSource;
  int get timelineCount => _timeline.length;

  /// 加载按视频时间轴排布的弹幕，[sourcePath] 为弹幕文件路径
  void loadTimeline(List<XmlDanmaku> danmakus, {required String sourcePath}) {
    _timeline = List.unmodifiable(danmakus);
    _timelineSource = p.basename(sourcePath);
    _timelineCursor = 0;
    _timelineLastSec = -1;
    notifyListeners();
  }

  void clearTimeline() {
    if (_timeline.isEmpty && _timelineSource == null) return;
    _timeline = const [];
    _timelineSource = null;
    _timelineCursor = 0;
    _timelineLastSec = -1;
    notifyListeners();
  }

  /// 由播放器进度驱动：到达时间点的弹幕进入显示队列，跳过的不补发。
  /// 播放中关闭弹幕时仍然推进游标，避免重新开启时瞬间倾泻历史弹幕。
  void syncTimeline(double seconds) {
    if (_timeline.isEmpty) return;
    if (seconds < _timelineLastSec - 1.5) {
      _activeBullets.clear();
      _timelineCursor = _lowerBound(seconds);
    }
    _timelineLastSec = seconds;

    while (_timelineCursor < _timeline.length &&
        _timeline[_timelineCursor].timeSec <= seconds) {
      final item = _timeline[_timelineCursor++];
      if (!isEnabled) continue;
      if (seconds - item.timeSec > BulletConstants.speed) continue;
      if (_isBlocked(item.text)) continue;
      _activeBullets.add(_fromXml(item));
      _needsNotify = true;
    }
  }

  int _lowerBound(double seconds) {
    var low = 0;
    var high = _timeline.length;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (_timeline[mid].timeSec < seconds) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  DanmakuItem _fromXml(XmlDanmaku item) {
    // 固定弹幕只在顶部/底部的少数几行内取行，否则按全局位置取行
    final rows = item.mode == XmlDanmakuMode.scroll
        ? _config.rows
        : min(3, _config.rows);
    return DanmakuItem(
      text: item.text,
      row: _random.nextInt(rows),
      startTime: DateTime.now(),
      position: switch (item.mode) {
        XmlDanmakuMode.scroll => DanmakuPosition.scroll,
        XmlDanmakuMode.top => DanmakuPosition.top,
        XmlDanmakuMode.bottom => DanmakuPosition.bottom,
      },
      colorValue: item.colorValue,
      fontSize: item.fontSize.clamp(12.0, 40.0),
      opacity: _config.opacityValue,
    );
  }

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
    final text = _generateRandomSentence();
    if (text.isEmpty || _isBlocked(text)) return;
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

  bool _isBlocked(String text) {
    for (final word in _config.blocklist) {
      if (word.isNotEmpty && text.contains(word)) return true;
    }
    return false;
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
