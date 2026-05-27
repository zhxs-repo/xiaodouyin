import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

/// 视频预览弹窗：自动播放、静音、15秒自动关闭
Future<void> showVideoPreviewDialog(BuildContext context, String videoPath) async {
  final fileName = p.basename(videoPath);
  Player? player;
  VideoController? controller;

  try {
    player = Player(configuration: const PlayerConfiguration());
    controller = VideoController(player);
    await player.open(Media(videoPath));
    await player.setVolume(0); // 静音
    await player.play();

    if (!context.mounted) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) {
        // 15秒后自动关闭（使用Dialog自己的context）
        Future.delayed(const Duration(seconds: 15), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(fileName, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // 视频区域
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Video(controller: controller!, controls: NoVideoControls),
                ),
              ),
            ],
          ),
        );
      },
    );
  } finally {
    await player?.pause();
    player?.dispose();
  }
}
