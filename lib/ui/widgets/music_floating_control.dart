import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/beauty_provider.dart';

class MusicFloatingControl extends StatelessWidget {
  const MusicFloatingControl({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<BeautyProvider>(
      builder: (context, bp, _) => Positioned(
        bottom: 80, right: 16,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: colorScheme.shadow.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.skip_previous, size: 20), onPressed: () => bp.prevMusic(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              IconButton(icon: Icon(bp.isMusicPlaying ? Icons.pause : Icons.play_arrow, size: 24), onPressed: () => bp.toggleMusic(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              IconButton(icon: const Icon(Icons.skip_next, size: 20), onPressed: () => bp.nextMusic(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          ),
        ),
      ),
    );
  }
}
