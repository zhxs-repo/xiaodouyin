import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/beauty_provider.dart';

class BeautyPreviewPage extends StatefulWidget {
  final int initialIndex;
  const BeautyPreviewPage({super.key, this.initialIndex = 0});

  @override
  State<BeautyPreviewPage> createState() => _BeautyPreviewPageState();
}

class _BeautyPreviewPageState extends State<BeautyPreviewPage> {
  late PageController _pageController;
  int _currentPageIndex = 0;
  bool _isZoomed = false;
  final TransformationController _transformController = TransformationController();
  Matrix4? _originalMatrix;
  Offset? _doubleTapLocalPosition;
  int _lastPreloadIndex = -1;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformController.addListener(_onTransformChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadAdjacentImages();
      _showGestureHintIfNeeded();
    });
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  /// 首次进入时显示手势操作提示
  Future<void> _showGestureHintIfNeeded() async {
    const key = 'beautyGestureHintShown';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('双击放大/缩小 | 双指缩放 | 上下滑动切换 | 左滑返回'),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await prefs.setBool(key, true);
    }
  }

  /// 监听TransformationController变化，检测缩放状态
  void _onTransformChanged() {
    final scale = _transformController.value.entry(0, 0);
    final wasZoomed = _isZoomed;
    _isZoomed = scale > 1.05;
    if (wasZoomed != _isZoomed) {
      setState(() {});
    }
    if (!_isZoomed) {
      _originalMatrix = null;
    }
  }

  void _preloadAdjacentImages() {
    final bp = context.read<BeautyProvider>();
    if (bp.images.isEmpty) return;
    final index = _currentPageIndex;
    if (index == _lastPreloadIndex) return;
    _lastPreloadIndex = index;
    if (index > 0) {
      precacheImage(FileImage(File(bp.images[index - 1])), context);
    }
    if (index < bp.images.length - 1) {
      precacheImage(FileImage(File(bp.images[index + 1])), context);
    }
  }

  /// 双击切换缩放：以双击位置为中心放大2.5x，再次双击还原
  void _onDoubleTapDown(TapDownDetails details) {
    _doubleTapLocalPosition = details.localPosition;
  }

  void _onDoubleTap() {
    if (_isZoomed) {
      _transformController.value = _originalMatrix ?? Matrix4.identity();
    } else {
      final position = _doubleTapLocalPosition ?? Offset.zero;
      const targetScale = 2.5;
      _originalMatrix = _transformController.value.clone();
      final matrix = Matrix4.identity()
        ..translateByDouble(position.dx, position.dy, 0.0, 1.0)
        ..scaleByDouble(targetScale, targetScale, targetScale, 1.0)
        ..translateByDouble(-position.dx, -position.dy, 0.0, 1.0);
      _transformController.value = matrix;
    }
  }

  /// 切换图片时重置缩放状态
  void _resetZoom() {
    _isZoomed = false;
    _originalMatrix = null;
    _transformController.value = Matrix4.identity();
  }

  void _onPageChanged(int index) {
    if (index == _currentPageIndex) return;
    _resetZoom();
    setState(() => _currentPageIndex = index);
    final bp = context.read<BeautyProvider>();
    bp.setPreviewIndex(index);
    WidgetsBinding.instance.addPostFrameCallback((_) => _preloadAdjacentImages());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<BeautyProvider>(
        builder: (context, bp, _) {
          if (bp.images.isEmpty) return const SizedBox();
          final images = bp.images;
          final totalCount = images.length;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 垂直滑动 PageView 实现跟手切换
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                // 缩放时禁用PageView滚动，让InteractiveViewer接管手势
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: totalCount,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final isCurrentPage = index == _currentPageIndex;
                  return _buildImagePage(
                    images[index],
                    isCurrentPage,
                    bp.rotation,
                  );
                },
              ),

              // 顶部：序号指示器 + 旋转按钮 + 返回按钮
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent]),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 返回按钮（替代左滑返回，避免手势冲突）
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white70, size: 22),
                          onPressed: () => Navigator.pop(context),
                          tooltip: '返回',
                        ),
                        Text('${_currentPageIndex + 1} / $totalCount',
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        IconButton(
                          icon: const Icon(Icons.rotate_right, color: Colors.white70, size: 22),
                          onPressed: () => bp.rotate90(),
                          tooltip: '旋转',
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 底部：边界提示
              if (_currentPageIndex == 0 && !_isZoomed)
                Positioned(
                  bottom: 80, left: 0, right: 0,
                  child: Center(
                    child: Text('已是第一张', style: TextStyle(color: Colors.white24.withValues(alpha: 0.5), fontSize: 12)),
                  ),
                ),
              if (_currentPageIndex == totalCount - 1 && !_isZoomed)
                Positioned(
                  bottom: 80, left: 0, right: 0,
                  child: Center(
                    child: Text('已是最后一张', style: TextStyle(color: Colors.white24.withValues(alpha: 0.5), fontSize: 12)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 构建单个图片页面
  Widget _buildImagePage(String imagePath, bool isCurrentPage, double rotation) {
    // 非当前页：仅渲染黑屏占位，不创建InteractiveViewer
    if (!isCurrentPage) {
      return const SizedBox.expand();
    }

    return GestureDetector(
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTap: _onDoubleTap,
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 5.0,
          // 缩放时启用平移（拖动查看放大后的图片），未缩放时禁用平移
          // panEnabled=false 时 InteractiveViewer 不参与单指拖动竞争，PageView可正常滑动
          // 双指缩放不受 panEnabled 影响，始终可用
          panEnabled: _isZoomed,
          child: RotatedBox(
            quarterTurns: (rotation / 90).round(),
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              cacheWidth: 1080,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 100, color: Colors.white24),
            ),
          ),
        ),
      ),
    );
  }
}
