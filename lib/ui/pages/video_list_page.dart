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
import '../../core/utils/toast_util.dart';
import '../../core/constants/storage_keys.dart';
import '../../data/services/storage_service.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: '搜索视频...', hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none),
          onSubmitted: (keyword) => context.read<SearchProvider>().search(keyword),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => context.read<SearchProvider>().search(_searchController.text)),
          // 列数切换
          IconButton(
            icon: Badge(label: Text('$_columnCount'), child: const Icon(Icons.grid_view)),
            tooltip: '切换列数',
            onPressed: () async {
              setState(() => _columnCount = _columnCount >= 5 ? 2 : _columnCount + 1);
              final storage = await StorageService.getInstance();
              await storage.setInt(StorageKeys.videoColumnCount, _columnCount);
            },
          ),
          // 继续播放
          Consumer<ResumeProvider>(
            builder: (context, resume, _) => IconButton(
              icon: const Icon(Icons.play_circle_outline),
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
            icon: const Icon(Icons.cleaning_services),
            tooltip: '重复检测',
            onPressed: () => _showDuplicateVideos(context),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '播放历史',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayHistoryPage())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
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
          if (videos.isEmpty) return const Center(child: Text('未找到匹配视频', style: TextStyle(color: Colors.white54)));
          final thumbnailEnabled = context.watch<ConfigProvider>().config.thumbnailLoadEnabled;
          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columnCount, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemCount: videos.length,
            itemBuilder: (context, index) => _buildVideoItem(videos[index], thumbnailEnabled),
          );
        },
      ),
    );
  }

  Widget _buildVideoItem(VideoItem video, bool thumbnailEnabled) {
    return GestureDetector(
      onTap: () {
        final vp = context.read<VideoPlayerProvider>();
        vp.setDisplayList(context.read<SearchProvider>().results, startIndex: video.index);
        Navigator.pop(context);
      },
      onLongPress: () => _showDeleteConfirm(context, video),
      child: Container(
        color: Colors.grey.shade900,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbnailEnabled)
              _buildThumbnail(video)
            else
              const Center(child: Icon(Icons.videocam, color: Colors.white24)),
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                color: Colors.black54,
                child: Text(video.bloggerName ?? video.fileName, style: const TextStyle(color: Colors.white, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(VideoItem video) {
    final thumbnailService = context.read<ThumbnailService>();
    return FutureBuilder<Uint8List?>(
      future: thumbnailService.getThumbnail(video.path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey.shade800,
            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24))),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover, cacheWidth: 200,
            errorBuilder: (_, _, _) => const Icon(Icons.videocam, color: Colors.white24));
        }
        return const Center(child: Icon(Icons.videocam, color: Colors.white24));
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
            child: const Text('删除', style: TextStyle(color: Colors.red)),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Divider(color: Colors.white24),
            ...videos.map((v) => Row(
              children: [
                Expanded(
                  child: Text(v.path, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
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
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
