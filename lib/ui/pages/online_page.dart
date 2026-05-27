import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../providers/online_provider.dart';
import '../../data/models/online_category.dart';
import 'online_video_swipe_page.dart';

class OnlinePage extends StatefulWidget {
  const OnlinePage({super.key});

  @override
  State<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends State<OnlinePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OnlineProvider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('在线模式')),
      body: DefaultTabController(
        length: 2,
        child: Consumer<OnlineProvider>(
          builder: (context, op, _) {
            return Column(
              children: [
                const TabBar(tabs: [Tab(text: '视频'), Tab(text: '图片')]),
                Expanded(
                  child: TabBarView(children: [
                    _buildCategoryGrid(op.videoCategories, CategoryType.video, op),
                    _buildCategoryGrid(op.imageCategories, CategoryType.image, op),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(List<OnlineCategory> categories, CategoryType type, OnlineProvider op) {
    if (op.isLoading && categories.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (op.error != null && categories.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(op.error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => op.loadCategories(), child: const Text('重试')),
        ],
      ));
    }
    if (categories.isEmpty) {
      return const Center(child: Text('暂无分类', style: TextStyle(color: Colors.white54)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.2),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return GestureDetector(
          onTap: () => _onCategoryTap(cat),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text(cat.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ),
        );
      },
    );
  }

  void _onCategoryTap(OnlineCategory category) {
    final provider = context.read<OnlineProvider>();
    if (category.type == CategoryType.video) {
      provider.initVideoSwipeList(category.id, categoryName: category.name);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => OnlineVideoSwipePage(categoryName: category.name)));
    } else {
      provider.fetchImage(category.id);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _OnlineContentPage(category: category)));
    }
  }
}

class _OnlineContentPage extends StatefulWidget {
  final OnlineCategory category;
  const _OnlineContentPage({required this.category});

  @override
  State<_OnlineContentPage> createState() => _OnlineContentPageState();
}

class _OnlineContentPageState extends State<_OnlineContentPage> {
  Player? _player;
  VideoController? _controller;
  String? _currentUrl;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  void _initPlayer(String url) {
    // URL变化时重新初始化播放器
    if (_player != null && _currentUrl == url) return;
    _player?.dispose();
    _player = Player(configuration: const PlayerConfiguration());
    _controller = VideoController(_player!);
    _player!.open(Media(url));
    _currentUrl = url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: Consumer<OnlineProvider>(
        builder: (context, op, _) {
          if (op.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (op.error != null) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(op.error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () {
                  if (widget.category.type == CategoryType.video) {
                    op.fetchVideo(widget.category.id);
                  } else {
                    op.fetchImage(widget.category.id);
                  }
                }, child: const Text('重试')),
              ],
            ));
          }
          final url = widget.category.type == CategoryType.video ? op.currentVideoUrl : op.currentImageUrl;
          if (url == null || url.isEmpty) return const SizedBox();
          if (widget.category.type == CategoryType.video) {
            _initPlayer(url);
            return Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: _controller != null
                  ? Video(controller: _controller!, controls: NoVideoControls)
                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            );
          }
          return Center(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain,
              memCacheWidth: 1080,
              placeholder: (_, _) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (_, _, _) => const Icon(Icons.broken_image, size: 100, color: Colors.white24)),
          );
        },
      ),
    );
  }
}
