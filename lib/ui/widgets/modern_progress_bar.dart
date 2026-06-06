import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import '../../core/theme/app_theme.dart';

/// 现代播放器进度条
/// 特性:
/// 1. 缓冲条 (订阅 player.stream.buffer)
/// 2. 拖动时高度动画 (4px → 6px)
/// 3. 拖动 / hover 时时间气泡预览
/// 4. 桌面端 hover 显示气泡 (通过 MouseRegion)
/// 5. 移动端触摸时显示气泡
/// 6. 拖动时长视频 (≥ 30s) 显示缩略图预览 (Phase 4)
class ModernProgressBar extends StatefulWidget {
  final Player? player;
  final double? width;
  final bool showTimeBubble;
  final String? videoPath; // 缩略图需要视频路径

  const ModernProgressBar({
    super.key,
    required this.player,
    this.width,
    this.showTimeBubble = true,
    this.videoPath,
  });

  @override
  State<ModernProgressBar> createState() => _ModernProgressBarState();
}

class _ModernProgressBarState extends State<ModernProgressBar> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  bool _isDragging = false;
  bool _isHovering = false;
  double? _dragValue; // 0.0 - 1.0
  double? _hoverValue; // 0.0 - 1.0
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _bufferSub;
  Player? _currentPlayer;

  // 缩略图 LRU 缓存 (Phase 4)
  static const int _maxThumbnailCache = 8;
  static const int _thumbnailSize = 160;
  final LinkedHashMap<int, Uint8List> _thumbCache = LinkedHashMap();
  int? _thumbnailRequestKey; // 当前正在请求的 key
  Uint8List? _currentThumbnail;
  bool _isLoadingThumbnail = false;
  String? _currentVideoPath;

  // 静态缓存,跨 widget 实例复用 (避免重复解码同一帧)
  static final LinkedHashMap<String, LinkedHashMap<int, Uint8List>> _globalCache = LinkedHashMap();

  @override
  void initState() {
    super.initState();
    _listenToPlayer();
    _currentVideoPath = widget.videoPath;
  }

  @override
  void didUpdateWidget(ModernProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player != _currentPlayer) {
      _positionSub?.cancel();
      _durationSub?.cancel();
      _bufferSub?.cancel();
      _listenToPlayer();
    }
    if (widget.videoPath != _currentVideoPath) {
      _currentVideoPath = widget.videoPath;
      _currentThumbnail = null;
      _thumbCache.clear();
    }
  }

  void _listenToPlayer() {
    _currentPlayer = widget.player;
    if (widget.player == null) return;
    final p = widget.player!;
    _position = p.state.position;
    _duration = p.state.duration;
    _buffer = p.state.buffer;
    _positionSub = p.stream.position.listen((pos) {
      if (!_isDragging && mounted) setState(() => _position = pos);
    });
    _durationSub = p.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _bufferSub = p.stream.buffer.listen((buf) {
      if (mounted) setState(() => _buffer = buf);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferSub?.cancel();
    super.dispose();
  }

  double get _progress => _duration.inMilliseconds > 0
      ? (_isDragging ? (_dragValue ?? 0) : _position.inMilliseconds / _duration.inMilliseconds)
      : 0.0;

  double get _bufferProgress {
    if (_duration.inMilliseconds <= 0) return 0.0;
    return (_buffer.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
  }

  Duration _targetDuration(double v) =>
      Duration(milliseconds: (v.clamp(0.0, 1.0) * _duration.inMilliseconds).round());

  /// 自动生成章节 (时长 ≥ 10 min 时,按 5 min 等分)
  List<Duration> get _chapters {
    if (_duration < const Duration(minutes: 10)) return const [];
    final interval = const Duration(minutes: 5);
    final chapters = <Duration>[];
    var t = interval;
    while (t < _duration) {
      chapters.add(t);
      t += interval;
    }
    return chapters;
  }

  void _onPointerMove(PointerEvent e, double trackWidth) {
    final v = (e.localPosition.dx / trackWidth).clamp(0.0, 1.0);
    if (_isDragging) {
      setState(() => _dragValue = v);
      _maybeLoadThumbnail(_targetDuration(v));
    } else {
      setState(() => _hoverValue = v);
    }
  }

  /// 缩略图懒加载: 长视频 + 拖动时,按需生成
  void _maybeLoadThumbnail(Duration position) {
    final path = _currentVideoPath;
    if (path == null || path.isEmpty) return;
    if (_duration < const Duration(seconds: 30)) return; // 短视频不显示

    // 1) 命中本地/全局缓存
    final key = position.inSeconds;
    final local = _globalCache[path];
    if (local != null && local.containsKey(key)) {
      _currentThumbnail = local[key];
      _thumbnailRequestKey = key;
      return;
    }
    if (_thumbCache.containsKey(key)) {
      _currentThumbnail = _thumbCache[key];
      _thumbnailRequestKey = key;
      return;
    }

    // 2) 避免重复请求同一帧
    if (_thumbnailRequestKey == key && _isLoadingThumbnail) return;
    _thumbnailRequestKey = key;
    _isLoadingThumbnail = true;

    // 3) 异步生成缩略图
    _loadThumbnail(path, key, position.inMilliseconds);
  }

  Future<void> _loadThumbnail(String path, int key, int timeMs) async {
    try {
      final data = await vt.VideoThumbnail.thumbnailData(
        video: path,
        imageFormat: vt.ImageFormat.JPEG,
        maxWidth: _thumbnailSize,
        maxHeight: (_thumbnailSize * 9 / 16).round(),
        timeMs: timeMs,
        quality: 50,
      );
      if (!mounted) return;
      if (data != null) {
        _globalCache.putIfAbsent(path, () => LinkedHashMap());
        final cache = _globalCache[path]!;
        cache[key] = data;
        // LRU 淘汰
        while (cache.length > _maxThumbnailCache) {
          cache.remove(cache.keys.first);
        }
        if (_thumbnailRequestKey == key) {
          setState(() {
            _currentThumbnail = data;
            _isLoadingThumbnail = false;
          });
        }
      } else {
        setState(() => _isLoadingThumbnail = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingThumbnail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showBubble = widget.showTimeBubble && (_isDragging || _isHovering);
    final bubbleValue = _isDragging ? (_dragValue ?? 0.0) : (_hoverValue ?? 0.0);
    final showFullTrack = _isDragging || _isHovering;
    final isWide = widget.width != null && widget.width! > 480;
    final showThumbnail = _isDragging && _currentThumbnail != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovering = true),
          onExit: (_) => setState(() => _isHovering = false),
          onHover: (e) => _onPointerMove(e, trackWidth),
          child: Listener(
            onPointerDown: (e) {
              setState(() {
                _isDragging = true;
                _dragValue = (e.localPosition.dx / trackWidth).clamp(0.0, 1.0);
              });
              _maybeLoadThumbnail(_targetDuration(_dragValue ?? 0));
            },
            onPointerMove: (e) => _onPointerMove(e, trackWidth),
            onPointerUp: (e) {
              if (_isDragging) {
                final v = (e.localPosition.dx / trackWidth).clamp(0.0, 1.0);
                widget.player?.seek(_targetDuration(v));
                setState(() {
                  _isDragging = false;
                  _dragValue = null;
                  _currentThumbnail = null;
                  _thumbnailRequestKey = null;
                });
              }
            },
            onPointerCancel: (e) => setState(() {
              _isDragging = false;
              _dragValue = null;
              _currentThumbnail = null;
              _thumbnailRequestKey = null;
            }),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isWide) ...[
                  _TopRow(
                    position: _position,
                    duration: _duration,
                    showTarget: _isDragging,
                    target: _targetDuration(bubbleValue),
                  ),
                  const SizedBox(height: 6),
                ],
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    // 缓冲条
                    Container(
                      height: showFullTrack ? 6 : 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: _bufferProgress,
                      child: AnimatedContainer(
                        duration: AppTheme.durFast,
                        height: showFullTrack ? 6 : 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // 已播放
                    FractionallySizedBox(
                      widthFactor: _progress.clamp(0.0, 1.0),
                      child: AnimatedContainer(
                        duration: AppTheme.durFast,
                        height: showFullTrack ? 6 : 4,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // Thumb
                    if (showFullTrack)
                      Positioned(
                        left: (_progress.clamp(0.0, 1.0) * trackWidth) - 7,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 章节标记 (Phase 4)
                    ..._chapters.map((c) {
                      final ratio = _duration.inMilliseconds > 0
                          ? c.inMilliseconds / _duration.inMilliseconds
                          : 0.0;
                      return Positioned(
                        left: (ratio.clamp(0.0, 1.0) * trackWidth) - 1,
                        top: -3,
                        bottom: -3,
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      );
                    }),
                    // 时间气泡 / 缩略图气泡
                    if (showBubble)
                      Positioned(
                        left: (bubbleValue.clamp(0.0, 1.0) * trackWidth).clamp(0.0, trackWidth - 60) - 28,
                        top: showThumbnail ? -110 : -36,
                        child: showThumbnail
                            ? _ThumbnailBubble(
                                imageData: _currentThumbnail!,
                                duration: _targetDuration(bubbleValue),
                                isLoading: _isLoadingThumbnail,
                              )
                            : _TimeBubble(duration: _targetDuration(bubbleValue)),
                      ),
                  ],
                ),
                if (!isWide) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(_position), style: _labelStyle(colorScheme)),
                      Text(_format(_duration), style: _labelStyle(colorScheme)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  TextStyle _labelStyle(ColorScheme cs) => TextStyle(
    color: Colors.white.withValues(alpha: 0.75),
    fontSize: 11,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}

class _TopRow extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final bool showTarget;
  final Duration target;

  const _TopRow({
    required this.position,
    required this.duration,
    required this.showTarget,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.85),
      fontSize: 12,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(_format(showTarget ? target : position), style: style),
        Text(
          showTarget ? '${_format(duration - target)} 剩余' : _format(duration),
          style: style.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }
}

class _TimeBubble extends StatelessWidget {
  final Duration duration;
  const _TimeBubble({required this.duration});

  @override
  Widget build(BuildContext context) {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = duration.inHours > 0 ? '${duration.inHours}:$m:$s' : '$m:$s';
    return IgnorePointer(
      child: GlassContainer(
        decoration: GlassDecoration.strong.copyWith(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// 缩略图气泡 (拖动时长视频时显示)
class _ThumbnailBubble extends StatelessWidget {
  final Uint8List imageData;
  final Duration duration;
  final bool isLoading;

  const _ThumbnailBubble({
    required this.imageData,
    required this.duration,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final text = duration.inHours > 0 ? '${duration.inHours}:$m:$s' : '$m:$s';
    return IgnorePointer(
      child: GlassContainer(
        decoration: GlassDecoration.strong.copyWith(
          borderRadius: BorderRadius.circular(AppTheme.radiusS),
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.memory(
                    imageData,
                    width: 160,
                    height: 90,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                  if (isLoading)
                    const Positioned.fill(
                      child: ColoredBox(
                        color: Color(0x66000000),
                        child: Center(
                          child: SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
