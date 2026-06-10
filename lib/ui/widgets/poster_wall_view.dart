import 'dart:io';
import 'package:flutter/material.dart';
import '../models/video_metadata.dart';

/// 海报墙预览组件
/// 用于播放前展示视频缩略图瀑布流
class PosterWallView extends StatelessWidget {
  final List<VideoMetadata> videos;
  final bool isShortVideoMode; // true=瀑布流 (短视频), false=双列 (长视频)
  final Function(VideoMetadata)? onTap;

  const PosterWallView({
    super.key,
    required this.videos,
    this.isShortVideoMode = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) {
      return const Center(
        child: Text('暂无视频'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isShortVideoMode ? 3 : 2,
        childAspectRatio: isShortVideoMode ? 0.56 : 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        return _VideoCard(
          video: videos[index],
          isShortVideoMode: isShortVideoMode,
          onTap: onTap,
        );
      },
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoMetadata video;
  final bool isShortVideoMode;
  final Function(VideoMetadata)? onTap;

  const _VideoCard({
    required this.video,
    required this.isShortVideoMode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap?.call(video),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 缩略图
            video.thumbnailPath != null && File(video.thumbnailPath!).existsSync()
                ? Image.file(
                    File(video.thumbnailPath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholder(),
                  )
                : _buildPlaceholder(),

            // 渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

            // 信息区域
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    video.title,
                    maxLines: isShortVideoMode ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isShortVideoMode ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  if (!isShortVideoMode) ...[
                    const SizedBox(height: 4),
                    // 元数据行
                    Row(
                      children: [
                        // 格式标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            video.format.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                        
                        const SizedBox(width: 6),
                        
                        // 时长
                        Icon(Icons.access_time, size: 12, color: Colors.white70),
                        const SizedBox(width: 2),
                        Text(
                          _formatDuration(video.duration),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 短视频模式：右上角显示时长
            if (isShortVideoMode)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatDuration(video.duration),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.video_library, size: 40, color: Colors.grey[500]),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
