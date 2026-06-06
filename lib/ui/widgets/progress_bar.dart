import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

class ProgressBar extends StatefulWidget {
  final Player? player;
  const ProgressBar({super.key, this.player});

  @override
  State<ProgressBar> createState() => _ProgressBarState();
}

class _ProgressBarState extends State<ProgressBar> {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isDragging = false;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  Player? _currentPlayer;

  @override
  void initState() {
    super.initState();
    _listenToPlayer();
  }

  @override
  void didUpdateWidget(ProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player != _currentPlayer) {
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _listenToPlayer();
    }
  }

  void _listenToPlayer() {
    _currentPlayer = widget.player;
    if (widget.player == null) return;
    _position = widget.player!.state.position;
    _duration = widget.player!.state.duration;
    _positionSubscription = widget.player!.stream.position.listen((pos) {
      if (!_isDragging && mounted) setState(() => _position = pos);
    });
    _durationSubscription = widget.player!.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.75),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      children: [
        Text(_formatDuration(_position), style: textStyle),
        const SizedBox(width: 8),
        Expanded(
          child: AnimatedScale(
            scale: _isDragging ? 1.0 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.20),
                thumbColor: colorScheme.primary,
                overlayColor: colorScheme.primary.withValues(alpha: 0.16),
                trackHeight: 4,
                thumbShape: RoundSliderThumbShape(
                  enabledThumbRadius: _isDragging ? 9 : 6,
                  elevation: 0,
                  pressedElevation: 0,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                value: clampedProgress,
                onChanged: (v) {
                  final newPos = Duration(milliseconds: (v * _duration.inMilliseconds).round());
                  setState(() {
                    _isDragging = true;
                    _position = newPos;
                  });
                },
                onChangeEnd: (v) {
                  final newPos = Duration(milliseconds: (v * _duration.inMilliseconds).round());
                  widget.player?.seek(newPos);
                  if (mounted) setState(() => _isDragging = false);
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatDuration(_duration), style: textStyle),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }
}
