import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/platform_utils.dart';

/// 手势解析器 - 解决滑动冲突
/// 
/// 功能：
/// 1. 普通竖向滑动：快速切换视频（列表滚动）
/// 2. 长按 (>500ms) + 竖向滑动：精细调节（亮度/音量）
/// 3. 横向滑动：快进/快退
/// 4. 单击：播放/暂停
/// 5. 双击：点赞
class GestureResolver extends StatefulWidget {
  final Widget child;
  final Function()? onTap;
  final Function()? onDoubleTap;
  final Function(double)? onHorizontalDragUpdate; // 快进/快退
  final Function(double)? onVerticalDragUpdate;   // 亮度/音量调节
  final Function()? onVerticalDragStartForScroll; // 普通滚动（切换视频）
  final Duration longPressDuration;

  const GestureResolver({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onHorizontalDragUpdate,
    this.onVerticalDragUpdate,
    this.onVerticalDragStartForScroll,
    this.longPressDuration = const Duration(milliseconds: 500),
  });

  @override
  State<GestureResolver> createState() => _GestureResolverState();
}

class _GestureResolverState extends State<GestureResolver> {
  bool _isLongPressing = false;
  Timer? _longPressTimer;
  Offset _startPosition = Offset.zero;

  void _handlePanStart(DragStartDetails details) {
    _startPosition = details.globalPosition;
    _isLongPressing = false;
    
    // 启动长按计时器
    _longPressTimer?.cancel();
    _longPressTimer = Timer(widget.longPressDuration, () {
      if (mounted) {
        setState(() => _isLongPressing = true);
        // 震动反馈（仅移动端）
        if (!PlatformUtils.isDesktop) {
          // TODO: 调用 HapticFeedback.mediumImpact()
        }
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (_longPressTimer != null && _longPressTimer!.isActive) {
      return; // 长按尚未触发，忽略移动
    }

    final delta = details.delta;
    
    if (_isLongPressing) {
      // 长按模式：精细调节（亮度/音量）
      // 根据起始位置判断是左侧（亮度）还是右侧（音量）
      final isLeftSide = _startPosition.dx < MediaQuery.of(context).size.width / 2;
      final sensitivity = 0.005; // 灵敏度
      
      if (widget.onVerticalDragUpdate != null) {
        widget.onVerticalDragUpdate!(delta.dy * sensitivity);
      }
    } else {
      // 普通模式：判断横向或纵向
      if (delta.dx.abs() > delta.dy.abs()) {
        // 横向滑动：快进/快退
        if (widget.onHorizontalDragUpdate != null) {
          widget.onHorizontalDragUpdate!(delta.dx);
        }
      } else {
        // 纵向滑动：触发列表滚动（切换视频）
        if (widget.onVerticalDragStartForScroll != null) {
          widget.onVerticalDragStartForScroll!();
        }
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    setState(() => _isLongPressing = false);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          widget.child,
          // 长按视觉反馈
          if (_isLongPressing)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.1),
                  child: Center(
                    child: Icon(
                      Icons.touch_app,
                      size: 64,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
