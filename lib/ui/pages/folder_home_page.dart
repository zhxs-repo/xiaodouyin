import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/folder_viewmodel.dart';
import '../widgets/video_card.dart';
import '../pages/video_player_page.dart';
import '../../models/video_item.dart';

/// 文件夹首页 - 瀑布流展示媒体文件夹
class FolderHomePage extends StatefulWidget {
  const FolderHomePage({Key? key}) : super(key: key);

  @override
  State<FolderHomePage> createState() => _FolderHomePageState();
}

class _FolderHomePageState extends State<FolderHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FolderViewModel>().scanFolders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('我的文件夹'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<FolderViewModel>().scanFolders();
            },
          ),
        ],
      ),
      body: Consumer<FolderViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.error!,
                    style: TextStyle(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新扫描'),
                    onPressed: () {
                      viewModel.scanFolders();
                    },
                  ),
                ],
              ),
            );
          }

          if (viewModel.folders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '暂无视频文件夹',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '将视频文件放入设备存储后刷新',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          // 瀑布流布局
          return RefreshIndicator(
            onRefresh: () => viewModel.scanFolders(),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 300, // 最大宽度 300px
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75, // 高宽比
              ),
              itemCount: viewModel.folders.length,
              itemBuilder: (context, index) {
                final folder = viewModel.folders[index];
                return _FolderCard(
                  folder: folder,
                  onTap: () => _navigateToFolderVideos(folder),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _navigateToFolderVideos(FolderItem folder) {
    // TODO: 跳转到文件夹详情页，展示该文件夹下的所有视频
    // 暂时导航到第一个视频
    if (folder.recentVideos.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerPage(video: folder.recentVideos.first),
        ),
      );
    }
  }
}

/// 文件夹卡片组件
class _FolderCard extends StatelessWidget {
  final FolderItem folder;
  final VoidCallback onTap;

  const _FolderCard({
    Key? key,
    required this.folder,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面区域
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (folder.coverThumbnail != null)
                    Image.memory(
                      folder.coverThumbnail!,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.video_library, size: 48, color: Colors.grey[500]),
                    ),
                  // 渐变遮罩
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 视频数量标签
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${folder.videoCount}个视频',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 信息区域
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 文件夹名称
                  Text(
                    folder.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // 最后播放时间
                  Text(
                    folder.formattedLastPlayedTime,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 视频格式和时长摘要
                  Text(
                    folder.recentInfo,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
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
