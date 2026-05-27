import 'package:flutter/material.dart';
import '../../data/models/video_item.dart';

class ThumbnailGrid extends StatelessWidget {
  final List<VideoItem> videos;
  final void Function(VideoItem) onTap;
  final int crossAxisCount;

  const ThumbnailGrid({super.key, required this.videos, required this.onTap, this.crossAxisCount = 3});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () => onTap(video),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (video.thumbnailPath != null)
                Image.asset(video.thumbnailPath!, fit: BoxFit.cover, cacheWidth: 200, errorBuilder: (_, _, _) => _placeholder())
              else
                _placeholder(),
              Positioned(bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4), color: Colors.black54,
                  child: Text(video.bloggerName ?? video.fileName, style: const TextStyle(color: Colors.white, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _placeholder() => Container(color: Colors.grey.shade900, child: const Icon(Icons.videocam, color: Colors.white24));
}
