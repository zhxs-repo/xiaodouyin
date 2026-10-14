import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/video_folder.dart';
import '../../data/models/video_item.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/file_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/thumbnail_service.dart';
import '../../providers/config_provider.dart';
import 'long_video_player_page.dart';

/// 文件夹浏览：列出视频目录树里装着视频的文件夹（递归、限定深度），点击进入后按集连播
class FolderHomePage extends StatefulWidget {
  const FolderHomePage({super.key});

  @override
  State<FolderHomePage> createState() => _FolderHomePageState();
}

/// 按可用宽度给出可循环的列数档位：手机 1/2/3，平板 3/5/7，桌面 5/7/9
List<int> folderColumnSteps(double width) {
  if (width < 600) return const [1, 2, 3];
  if (width < 1000) return const [3, 5, 7];
  return const [5, 7, 9];
}

/// 把偏好值吸附到当前档位里最近的一档，跨设备复用同一份设置时不会溢出
int folderColumnSnap(List<int> steps, int? preferred) {
  if (preferred == null) return steps[0];
  var best = steps[0];
  for (final s in steps) {
    if ((s - preferred).abs() < (best - preferred).abs()) best = s;
  }
  return best;
}

/// 海报墙列数：手机端保持窄屏可读，宽屏按 360dp 一列递增
int posterColumnCount(double width) => (width / 360).floor().clamp(3, 8);

class _FolderHomePageState extends State<FolderHomePage> {
  List<VideoFolder> _folders = const [];
  bool _loading = true;
  int? _preferredColumns;

  @override
  void initState() {
    super.initState();
    _restoreColumnCount();
    _load();
  }

  Future<void> _restoreColumnCount() async {
    final storage = await StorageService.getInstance();
    final saved = storage.getInt(StorageKeys.folderColumnCount);
    if (saved != null && mounted) setState(() => _preferredColumns = saved);
  }

  Future<void> _load() async {
    final config = context.read<ConfigProvider>().config;
    final folders = await VideoRepository(
      FileService(customVideoDir: config.customVideoDir),
    ).loadFolders();
    if (!mounted) return;
    setState(() {
      _folders = folders;
      _loading = false;
    });
  }

  Future<void> _cycleColumnCount(List<int> steps, int current) async {
    final next = steps[(steps.indexOf(current) + 1) % steps.length];
    setState(() => _preferredColumns = next);
    final storage = await StorageService.getInstance();
    await storage.setInt(StorageKeys.folderColumnCount, next);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = folderColumnSteps(MediaQuery.sizeOf(context).width);
    final columnCount = folderColumnSnap(steps, _preferredColumns);
    return Scaffold(
      appBar: AppBar(
        title: _loading
            ? const Text('文件夹')
            : Text('文件夹 (${_folders.length})'),
        actions: [
          IconButton(
            icon: Badge(
              label: Text('$columnCount'),
              backgroundColor: colorScheme.primary,
              child: const Icon(Icons.grid_view_rounded),
            ),
            tooltip: '切换列数 (${steps.join('/')})',
            onPressed: () => _cycleColumnCount(steps, columnCount),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新扫描',
            onPressed: () {
              setState(() => _loading = true);
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _folders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_off_rounded,
                        size: 64,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '没有找到含视频的文件夹',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '扫描会跳过隐藏目录和 .nomedia 标记目录，最深向下 ${FileService.folderScanMaxDepth} 层',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columnCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: columnCount <= 3 ? 3.2 : 2.0,
                  ),
                  itemCount: _folders.length,
                  itemBuilder: (context, index) {
                    final folder = _folders[index];
                    return _FolderRow(
                      folder: folder,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FolderVideosPage(folder: folder),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

/// 单个文件夹里的视频，点任意一集以长视频模式从该集开始连播整个文件夹
class FolderVideosPage extends StatelessWidget {
  const FolderVideosPage({super.key, required this.folder});

  final VideoFolder folder;

  void _play(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LongVideoPlayerPage(
          initialVideos: folder.videos,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final thumbnailEnabled =
        context.watch<ConfigProvider>().config.thumbnailLoadEnabled;
    return Scaffold(
      appBar: AppBar(
        title: Text(folder.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline_rounded),
            tooltip: '从第一集播放',
            onPressed: () => _play(context, 0),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(6),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: posterColumnCount(MediaQuery.sizeOf(context).width),
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 9 / 13,
        ),
        itemCount: folder.videos.length,
        itemBuilder: (context, index) {
          final video = folder.videos[index];
          return GestureDetector(
            onTap: () => _play(context, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              child: Container(
                color: colorScheme.surfaceContainer,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailEnabled)
                      _Thumbnail(video: video)
                    else
                      Icon(Icons.videocam_rounded,
                          color: colorScheme.onSurfaceVariant, size: 32),
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
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          video.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4)
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.folder, required this.onTap});

  final VideoFolder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 标题只用最末一级目录名，上级路径放副标题，避免多列时整条路径被截断
    final segments = p.split(folder.name);
    final parent = segments.length > 1
        ? '${segments.sublist(0, segments.length - 1).join(' / ')} · '
        : '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
        ),
        child: Row(
          children: [
            Icon(
              Icons.folder_rounded,
              color: colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    segments.last,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$parent${folder.videoCount} 个视频',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.video});

  final VideoItem video;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<Uint8List?>(
      future: context.read<ThumbnailService>().getThumbnail(video.path),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: colorScheme.surfaceContainerHigh,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return Icon(Icons.videocam_rounded,
              color: colorScheme.onSurfaceVariant, size: 32);
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: 200,
          errorBuilder: (_, _, _) => Icon(Icons.videocam_rounded,
              color: colorScheme.onSurfaceVariant, size: 32),
        );
      },
    );
  }
}
