import 'package:flutter/foundation.dart';

@immutable
class PlayHistoryRecord {
  final String videoPath;
  final Duration position;
  final Duration duration;
  final DateTime timestamp;

  const PlayHistoryRecord({
    required this.videoPath,
    required this.position,
    required this.duration,
    required this.timestamp,
  });

  bool get isValid => position < duration && duration.inSeconds > 60;

  PlayHistoryRecord copyWith({
    String? videoPath,
    Duration? position,
    Duration? duration,
    DateTime? timestamp,
  }) => PlayHistoryRecord(
    videoPath: videoPath ?? this.videoPath,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    timestamp: timestamp ?? this.timestamp,
  );

  Map<String, dynamic> toJson() => {
    'videoPath': videoPath,
    'position': position.inMilliseconds,
    'duration': duration.inMilliseconds,
    'timestamp': timestamp.toIso8601String(),
  };

  factory PlayHistoryRecord.fromJson(Map<String, dynamic> json) =>
      PlayHistoryRecord(
        videoPath: json['videoPath'] as String,
        position: Duration(milliseconds: json['position'] as int),
        duration: Duration(milliseconds: json['duration'] as int),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
