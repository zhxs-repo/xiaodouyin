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
    // player切换时，重新订阅流
    if (widget.player != _currentPlayer) {
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _listenToPlayer();
    }
  }

  void _listenToPlayer() {
    _currentPlayer = widget.player;
    if (widget.player == null) return;

    // 先读取player当前状态作为初始值（避免错过stream已发出的事件）
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
    final progress = _duration.inMilliseconds > 0
      ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

    return Row(
      children: [
        Text(_formatDuration(_position), style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              showValueIndicator: ShowValueIndicator.onlyForDiscrete,
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              label: _isDragging ? _formatDuration(_position) : null,
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
                setState(() => _isDragging = false);
              },
            ),
          ),
        ),
        Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    // 短视频(<1小时)显示 MM:SS，长视频显示 H:MM:SS
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }
}
