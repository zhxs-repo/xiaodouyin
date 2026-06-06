import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/video_player_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/resume_provider.dart';
import '../../data/models/video_item.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/file_service.dart';
import '../../data/services/thumbnail_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/toast_util.dart';
import '../../core/constants/storage_keys.dart';
import '../../data/services/storage_service.dart';
import '../widgets/shimmer_loading.dart';
import 'play_history_page.dart';

class VideoListPage extends StatefulWidget {
  const VideoListPage({super.key});

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  final _searchController = TextEditingController();
  int _columnCount = 3;

  @override
  void initState() {
    super.initState();
    context.read<SearchProvider>().load();
    _loadColumnCount();
  }

  Future<void> _loadColumnCount() async {
    final storage = await StorageService.getInstance();
    final saved = storage.getInt(StorageKeys.videoColumnCount);
    if (saved != null && mounted) setState(() => _columnCount = saved.clamp(2, 6));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 44,
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: '搜索视频...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant, size: 20),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded, color: colorScheme.onSurfaceVariant, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (keyword) => context.read<SearchProvider>().search(keyword),
          ),
        ),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$_columnCount'),
              backgroundColor: colorScheme.primary,
              child: const Icon(Icons.grid_view_rounded),
            ),
            tooltip: '切换列数',
            onPressed: () async {
              setState(() => _columnCount = _columnCount >= 5 ? 2 : _columnCount + 1);
              final storage = await StorageService.getInstance();
              await storage.setInt(StorageKeys.videoColumnCount, _columnCount);
            },
          ),
          Consumer<ResumeProvider>(
            builder: (context, resume, _) => IconButton(
              icon: const Icon(Icons.play_circle_outline_rounded),
              tooltip: '继续播放',
              onPressed: () {
                final vp = context.read<VideoPlayerProvider>();
                if (vp.videoList.isNotEmpty) {
                  Navigator.pop(context);
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.find_in_page_rounded),
            tooltip: '重复检测',
            onPressed: () => _showDuplicateVideos(context),
          ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: '播放历史',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayHistoryPage())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: (blogger) => context.read<SearchProvider>().filterByBlogger(blogger),
            itemBuilder: (_) {
              final groups = context.read<SearchProvider>().bloggerGroups;
              return groups.keys.map((name) => PopupMenuItem(value: name, child: Text(name))).toList();
            },
          ),
        ],
      ),
      body: Consumer<SearchProvider>(
        builder: (context, sp, _) {
          final videos = sp.results.isEmpty && sp.keyword.isEmpty
            ? context.watch<VideoPlayerProvider>().videoList : sp.results;
          if (videos.isEmpty) {
            if (sp.keyword.isNotEmpty) {
              return _buildEmptyState('未找到匹配视频');
            }
            return const ThumbnailShimmerPlaceholder();
          }
          final thumbnailEnabled = context.watch<ConfigProvider>().config.thumbnailLoadEnabled;
          return GridView.builder(
            padding: const EdgeInsets.all(6),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columnCount, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 9 / 13),
            itemCount: videos.length,
            itemBuilder: (context, index) => _buildVideoItem(videos[index], thumbnailEnabled),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildVideoItem(VideoItem video, bool thumbnailEnabled) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        final vp = context.read<VideoPlayerProvider>();
        vp.setDisplayList(context.read<SearchProvider>().results, startIndex: video.index);
        Navigator.pop(context);
      },
      onLongPress: () => _showDeleteConfirm(context, video),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        child: Container(
          color: colorScheme.surfaceContainer,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumbnailEnabled)
                _buildThumbnail(video)
              else
                Center(child: Icon(Icons.videocam_rounded, color: colorScheme.onSurfaceVariant, size: 32)),
              // 底部渐变蒙层
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    video.bloggerName ?? video.fileName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(VideoItem video) {
    final colorScheme = Theme.of(context).colorScheme;
    final thumbnailService = context.read<ThumbnailService>();
    return FutureBuilder<Uint8List?>(
      future: thumbnailService.getThumbnail(video.path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: colorScheme.surfaceContainerHigh,
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover, cacheWidth: 200,
            errorBuilder: (_, _, _) => Icon(Icons.videocam_rounded, color: colorScheme.onSurfaceVariant, size: 32));
        }
        return Center(child: Icon(Icons.videocam_rounded, color: colorScheme.onSurfaceVariant, size: 32));
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, VideoItem video) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除视频'),
        content: Text('确定删除 "${video.fileName}" 吗？\n此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final config = context.read<ConfigProvider>().config;
              final fileService = FileService(customVideoDir: config.customVideoDir, customImageDir: config.customImageDir);
              final videoRepo = VideoRepository(fileService);
              await videoRepo.deleteVideo(video.path);
              if (context.mounted) {
                ToastUtil.show(context, '已删除 ${video.fileName}');
                // 刷新列表
                final vp = context.read<VideoPlayerProvider>();
                final updatedList = vp.videoList.where((v) => v.path != video.path).toList();
                vp.setVideoList(updatedList);
              }
            },
            child: Text('删除', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _showDuplicateVideos(BuildContext context) {
    final vp = context.read<VideoPlayerProvider>();
    final config = context.read<ConfigProvider>().config;
    final videoRepo = VideoRepository(FileService(customVideoDir: config.customVideoDir, customImageDir: config.customImageDir));
    videoRepo.videos = vp.videoList; // 使用当前视频列表
    final duplicates = videoRepo.findDuplicateVideos();
    if (duplicates.isEmpty) {
      ToastUtil.show(context, '未发现重复视频');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DuplicateVideosPage(duplicates: duplicates),
      ),
    );
  }
}

/// 重复视频列表页
class _DuplicateVideosPage extends StatelessWidget {
  final Map<String, List<VideoItem>> duplicates;
  const _DuplicateVideosPage({required this.duplicates});

  @override
  Widget build(BuildContext context) {
    final entries = duplicates.entries.toList();
    return Scaffold(
      appBar: AppBar(title: Text('重复视频 (${entries.length}组)')),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: entries.length,
        itemBuilder: (context, index) => _buildGroup(context, entries[index].key, entries[index].value),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, String name, List<VideoItem> videos) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 14)),
            Divider(color: colorScheme.outlineVariant),
            ...videos.map((v) => Row(
              children: [
                Expanded(
                  child: Text(v.path, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 18),
                  onPressed: () => _deleteVideo(context, v),
                ),
              ],
            )),
          ],
        ),
      ),
    );
  }

  void _deleteVideo(BuildContext context, VideoItem video) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除视频'),
        content: Text('确定删除 "${video.fileName}" 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final config = context.read<ConfigProvider>().config;
              await FileService(customVideoDir: config.customVideoDir).deleteFile(video.path);
              if (context.mounted) {
                ToastUtil.show(context, '已删除 ${video.fileName}');
              }
            },
            child: Text('删除', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
