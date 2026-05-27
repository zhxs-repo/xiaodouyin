import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/cultivation_provider.dart';
import '../../providers/video_player_provider.dart';

class RealTimeCounter extends StatefulWidget {
  const RealTimeCounter({super.key});

  @override
  State<RealTimeCounter> createState() => _RealTimeCounterState();
}

class _RealTimeCounterState extends State<RealTimeCounter> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Selector<FavoriteProvider, int>(
          selector: (_, fp) => fp.favorites.length,
          builder: (_, favCount, _) => Selector<VideoPlayerProvider, int>(
            selector: (_, vp) => vp.videoList.length,
            builder: (_, totalVideos, _) => Text('$timeStr | 视频:$totalVideos | 收藏:$favCount', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
        Selector<CultivationProvider, (bool, String, int)>(
          selector: (_, cp) => (cp.enabled, cp.realmName, cp.currentExp),
          builder: (_, data, _) {
            if (!data.$1) return const SizedBox.shrink();
            return Text('${data.$2} | 灵力:${_formatExp(data.$3)}', style: const TextStyle(color: Colors.amber, fontSize: 10));
          },
        ),
      ],
    );
  }

  String _formatExp(int exp) {
    if (exp >= 10000) return '${(exp / 10000).toStringAsFixed(1)}w';
    if (exp >= 1000) return '${(exp / 1000).toStringAsFixed(1)}k';
    return '$exp';
  }
}
