import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      appBar: AppBar(
        title: const Text('在线模式'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast_connected),
            tooltip: '串流播放（输入链接）',
            onPressed: _showStreamingDialog,
          ),
        ],
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    if (op.isLoading && categories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (op.error != null && categories.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(op.error!, style: TextStyle(color: colorScheme.error)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => op.loadCategories(), child: const Text('重试')),
        ],
      ));
    }
    if (categories.isEmpty) {
      return Center(child: Text('暂无分类', style: TextStyle(color: colorScheme.onSurfaceVariant)));
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
              color: colorScheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text(cat.name, style: TextStyle(color: colorScheme.onSurface, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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

  void _showStreamingDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _StreamingDialog(
        onSubmit: (url, title) {
          Navigator.of(ctx).pop();
          _startStreaming(url, title);
        },
      ),
    );
  }

  void _startStreaming(String url, String? title) {
    final provider = context.read<OnlineProvider>();
    provider.setStreamingUrl(url, title: title);
    final displayTitle = title ?? '串流播放';
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => OnlineVideoSwipePage(categoryName: displayTitle)));
  }
}

class _StreamingDialog extends StatefulWidget {
  final void Function(String url, String? title) onSubmit;
  const _StreamingDialog({required this.onSubmit});

  @override
  State<_StreamingDialog> createState() => _StreamingDialogState();
}

class _StreamingDialogState extends State<_StreamingDialog> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final url = _urlController.text.trim();
    final rawTitle = _titleController.text.trim();
    widget.onSubmit(url, rawTitle.isEmpty ? null : rawTitle);
  }

  String? _validateUrl(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '请输入播放链接';
    final isHttp = v.startsWith('http://') || v.startsWith('https://');
    final isRtmp = v.startsWith('rtmp://') || v.startsWith('rtsp://');
    final isFile = v.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(v) ||
        v.startsWith('file://');
    if (!isHttp && !isRtmp && !isFile) {
      return '仅支持 http(s)/rtmp/rtsp 链接或本地文件路径';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.cast_connected, color: colorScheme.primary),
          const SizedBox(width: 8),
          const Text('串流播放'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _urlController,
              autofocus: true,
              keyboardType: TextInputType.url,
              maxLines: 3,
              minLines: 1,
              inputFormatters: [
                LengthLimitingTextInputFormatter(2048),
              ],
              decoration: const InputDecoration(
                labelText: '播放链接',
                hintText: 'http(s)://... 或本地文件路径',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              validator: _validateUrl,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              maxLength: 30,
              inputFormatters: [
                LengthLimitingTextInputFormatter(30),
              ],
              decoration: const InputDecoration(
                labelText: '标题（可选）',
                hintText: '串流播放',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('开始播放'),
          onPressed: _submit,
        ),
      ],
    );
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
    final colorScheme = Theme.of(context).colorScheme;
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
                Text(op.error!, style: TextStyle(color: colorScheme.error)),
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
                  : Center(child: CircularProgressIndicator(color: colorScheme.primary)),
              ),
            );
          }
          return Center(
            child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain,
              memCacheWidth: 1080,
              placeholder: (_, _) => Center(child: CircularProgressIndicator(color: colorScheme.primary)),
              errorWidget: (_, _, _) => Icon(Icons.broken_image, size: 100, color: colorScheme.onSurfaceVariant)),
          );
        },
      ),
    );
  }
}
