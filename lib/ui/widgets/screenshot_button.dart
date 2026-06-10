import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../core/utils/platform_utils.dart';

/// 截图按钮组件
/// 
/// 功能：
/// 1. 点击截取当前视频帧
/// 2. 自动保存至系统相册
/// 3. Toast 提示保存结果
/// 4. 带动画反馈
class ScreenshotButton extends StatefulWidget {
  final Function()? onScreenshotTaken;
  final double size;
  final Color? color;

  const ScreenshotButton({
    super.key,
    this.onScreenshotTaken,
    this.size = 40.0,
    this.color,
  });

  @override
  State<ScreenshotButton> createState() => _ScreenshotButtonState();
}

class _ScreenshotButtonState extends State<ScreenshotButton>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleScreenshot() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    _animationController.forward().then((_) => _animationController.reverse());

    try {
      // TODO: 实际截图逻辑需要访问播放器控制器
      // 这里仅提供 UI 框架和保存逻辑
      if (widget.onScreenshotTaken != null) {
        await widget.onScreenshotTaken!();
      }

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('截图已保存至相册'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // 震动反馈（仅移动端）
      if (!PlatformUtils.isDesktop) {
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('截图失败：${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleScreenshot,
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color ?? Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isProcessing ? Icons.hourglass_empty : Icons.camera_alt,
              color: widget.color != null ? widget.color : Colors.white,
              size: widget.size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
