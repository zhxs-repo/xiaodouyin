import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:preload_page_view/preload_page_view.dart';
import '../../providers/online_provider.dart';
import '../../core/utils/toast_util.dart';

/// 在线图片水平滑动页
class OnlineImageSwipePage extends StatefulWidget {
  final String categoryName;

  const OnlineImageSwipePage({super.key, required this.categoryName});

  @override
  State<OnlineImageSwipePage> createState() => _OnlineImageSwipePageState();
}

class _OnlineImageSwipePageState extends State<OnlineImageSwipePage> {
  /// 桌面端默认 dragDevices 不含 mouse，这里补上（其余保持与默认一致）
  static const Set<PointerDeviceKind> _dragDevices = {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };

  final PreloadPageController _pageController = PreloadPageController();
  final Map<String, int> _reloadTicks = {};
  int _currentPageIndex = 0;
  bool _isDownloading = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int newIndex) {
    if (newIndex == _currentPageIndex) return;
    setState(() => _currentPageIndex = newIndex);
    context.read<OnlineProvider>().onImagePageChanged(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<OnlineProvider>(
        builder: (context, op, _) {
          if (op.isLoading && op.imageUrlList.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('加载图片中...', style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            );
          }

          if (op.error != null && op.imageUrlList.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(op.error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () =>
                          op.initImageSwipeList(op.currentImageCategoryId ?? ''),
                      icon: const Icon(Icons.refresh),
                      label: const Text('重试'),
                    ),
                  ],
                ),
              ),
            );
          }

          final imageList = op.imageUrlList;
          if (imageList.isEmpty) return const SizedBox();

          return Stack(
            children: [
              _buildPageView(imageList),
              _buildTopBar(imageList.length),
              _buildRightActionBar(imageList),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageView(List<String> imageList) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(dragDevices: _dragDevices),
      child: PreloadPageView.builder(
        controller: _pageController,
        scrollDirection: Axis.horizontal,
        itemCount: imageList.length,
        // 预构建前后2页，新补的图一进列表就开始下载
        preloadPagesCount: 2,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) => _buildImagePage(imageList[index]),
      ),
    );
  }

  Widget _buildImagePage(String url) {
    final tick = _reloadTicks[url] ?? 0;
    return SizedBox.expand(
      child: Center(
        child: KeyedSubtree(
          key: ValueKey('$url#$tick'),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            memCacheWidth: 1080,
            placeholder: (_, _) =>
                const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorWidget: (_, _, _) => GestureDetector(
              onTap: () => setState(() => _reloadTicks[url] = tick + 1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 80, color: Colors.white38),
                  const SizedBox(height: 8),
                  const Text('加载失败',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('点击重试',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(int totalCount) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: IgnorePointer(
                  child: Text(
                    widget.categoryName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IgnorePointer(
                child: Text(
                  '${_currentPageIndex + 1}/$totalCount',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightActionBar(List<String> imageList) {
    return Positioned(
      right: 12,
      bottom: MediaQuery.of(context).size.height * 0.32,
      child: GestureDetector(
        onTap: _isDownloading ? null : () => _downloadCurrentImage(imageList),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(10),
              child: _isDownloading
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.download, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 4),
            const Text('下载', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadCurrentImage(List<String> imageList) async {
    if (_currentPageIndex >= imageList.length) return;
    final url = imageList[_currentPageIndex];
    setState(() => _isDownloading = true);
    final op = context.read<OnlineProvider>();
    final savedPath = await op.downloadImage(url, widget.categoryName);
    if (!mounted) return;
    setState(() => _isDownloading = false);
    if (savedPath != null) {
      ToastUtil.show(context, '已保存到 $savedPath', type: ToastType.success);
    } else {
      ToastUtil.show(context, '下载失败', type: ToastType.error);
    }
  }
}
