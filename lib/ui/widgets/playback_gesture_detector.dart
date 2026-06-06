import 'dart:async';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:media_kit/media_kit.dart';
import '../../core/theme/app_theme.dart';

/// 移动端播放手势: 左侧竖向拖动 → 系统亮度 / 右侧竖向拖动 → 音量
/// 桌面端不启用 (走 MouseRegion 唤出 UI 流程)
class PlaybackGestureDetector extends StatefulWidget {
  final Widget child;
  final Player? player;
  final ValueChanged<double>? onVolumeChanged; // 0-100
  final VoidCallback? onSingleTap;
  final VoidCallback? onDoubleTap;
  final ValueChanged<DragEndDetails>? onHorizontalDragEnd;

  const PlaybackGestureDetector({
    super.key,
    required this.child,
    this.player,
    this.onVolumeChanged,
    this.onSingleTap,
    this.onDoubleTap,
    this.onHorizontalDragEnd,
  });

  @override
  State<PlaybackGestureDetector> createState() => _PlaybackGestureDetectorState();
}

enum _GestureType { none, brightness, volume }

class _PlaybackGestureDetectorState extends State<PlaybackGestureDetector>
    with WidgetsBindingObserver {
  _GestureType _activeGesture = _GestureType.none;
  double? _startBrightness;
  double? _startVolume;
  double _currentValue = 0; // 0-1 范围
  bool _showOverlay = false;
  Timer? _hideTimer;

  // 防止对 player 的频繁 setVolume
  int _lastVolumeApplied = 0;

  // 用户上次设置的亮度 (用于屏幕旋转后重设)
  double? _userSetBrightness;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // 屏幕方向/尺寸变化后,重新应用用户设置的亮度
    if (_userSetBrightness != null) {
      ScreenBrightness().setScreenBrightness(_userSetBrightness!);
    }
  }

  void _startOverlay() {
    _hideTimer?.cancel();
    if (!_showOverlay) setState(() => _showOverlay = true);
    _hideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  void _onVerticalDragStart(DragStartDetails details, Size size) {
    final isLeft = details.localPosition.dx < size.width / 2;
    _activeGesture = isLeft ? _GestureType.brightness : _GestureType.volume;

    if (_activeGesture == _GestureType.brightness) {
      // 读取当前应用屏幕亮度作为起点
      ScreenBrightness()
          .current
          .then((v) {
            if (!mounted) return;
            _startBrightness = v.clamp(0.0, 1.0);
            _currentValue = _startBrightness!;
            setState(() => _showOverlay = true);
          })
          .catchError((_) {
            if (!mounted) return;
            _startBrightness = 0.5;
            _currentValue = 0.5;
            setState(() => _showOverlay = true);
          });
    } else {
      final current = widget.player?.state.volume ?? 0.0;
      _startVolume = current / 100.0;
      _currentValue = _startVolume!;
      _lastVolumeApplied = current.round();
      setState(() => _showOverlay = true);
    }
  }

  void _onVerticalDragUpdate(DragUpdateDetails details, Size size) {
    if (_activeGesture == _GestureType.none) return;
    // 屏幕高度的 1/3 拖动对应 1.0 变化量 (更灵敏)
    final sensitivity = size.height / 3 / 100.0; // 每像素对应的值变化
    final delta = -details.primaryDelta! * sensitivity;
    final newValue = (_currentValue + delta).clamp(0.0, 1.0);
    if ((newValue - _currentValue).abs() < 0.001) return;
    _currentValue = newValue;
    setState(() {});

    if (_activeGesture == _GestureType.brightness) {
      _userSetBrightness = _currentValue;
      ScreenBrightness().setScreenBrightness(_currentValue);
    } else if (_activeGesture == _GestureType.volume) {
      final newVol = (_currentValue * 100).round();
      if (newVol != _lastVolumeApplied) {
        _lastVolumeApplied = newVol;
        widget.player?.setVolume(newVol.toDouble());
        widget.onVolumeChanged?.call(newVol.toDouble());
      }
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_activeGesture == _GestureType.brightness) {
      _userSetBrightness = _currentValue;
      ScreenBrightness().setScreenBrightness(_currentValue);
    }
    _activeGesture = _GestureType.none;
    _startBrightness = null;
    _startVolume = null;
    _startOverlay();
  }

  void _onDoubleTap() {
    widget.onDoubleTap?.call();
  }

  void _onSingleTap() {
    widget.onSingleTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            // 左侧亮度手势
            Positioned.fill(
              left: 0,
              right: size.width / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onSingleTap,
                onDoubleTap: _onDoubleTap,
                onHorizontalDragEnd: widget.onHorizontalDragEnd,
                onVerticalDragStart: (d) => _onVerticalDragStart(d, size),
                onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, size),
                onVerticalDragEnd: _onVerticalDragEnd,
              ),
            ),
            // 右侧音量手势
            Positioned.fill(
              left: size.width / 2,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _onSingleTap,
                onDoubleTap: _onDoubleTap,
                onHorizontalDragEnd: widget.onHorizontalDragEnd,
                onVerticalDragStart: (d) => _onVerticalDragStart(d, size),
                onVerticalDragUpdate: (d) => _onVerticalDragUpdate(d, size),
                onVerticalDragEnd: _onVerticalDragEnd,
              ),
            ),
            // 内容
            widget.child,
            // 浮层
            if (_showOverlay && _activeGesture != _GestureType.none)
              Center(child: _buildOverlay()),
          ],
        );
      },
    );
  }

  Widget _buildOverlay() {
    final isBrightness = _activeGesture == _GestureType.brightness;
    final icon = isBrightness
        ? (_currentValue < 0.33
            ? Icons.brightness_low_rounded
            : (_currentValue < 0.66 ? Icons.brightness_medium_rounded : Icons.brightness_high_rounded))
        : (_currentValue <= 0
            ? Icons.volume_off_rounded
            : (_currentValue < 0.33
                ? Icons.volume_mute_rounded
                : (_currentValue < 0.66 ? Icons.volume_down_rounded : Icons.volume_up_rounded)));
    final percent = (_currentValue * 100).round();
    return GlassContainer(
      decoration: GlassDecoration.strong.copyWith(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 36),
          const SizedBox(height: 8),
          Text(
            isBrightness ? '亮度' : '音量',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '$percent%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              value: _currentValue,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
