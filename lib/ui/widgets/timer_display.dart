import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/timer_provider.dart';

class TimerDisplay extends StatelessWidget {
  const TimerDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerProvider>(
      builder: (context, tp, _) {
        if (!tp.isRunning) return const SizedBox();
        final m = tp.remainingSeconds ~/ 60;
        final s = tp.remainingSeconds % 60;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
          child: Text('定时: ${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontSize: 12)),
        );
      },
    );
  }
}
