import 'package:flutter/foundation.dart';

@immutable
class TimerStateModel {
  final bool isRunning;
  final int remainingSeconds;
  final int totalSeconds;
  final int? savedAtEpoch; // 保存时的秒级时间戳

  const TimerStateModel({
    required this.isRunning,
    required this.remainingSeconds,
    required this.totalSeconds,
    this.savedAtEpoch,
  });

  TimerStateModel copyWith({bool? isRunning, int? remainingSeconds, int? totalSeconds, int? savedAtEpoch}) =>
      TimerStateModel(
        isRunning: isRunning ?? this.isRunning,
        remainingSeconds: remainingSeconds ?? this.remainingSeconds,
        totalSeconds: totalSeconds ?? this.totalSeconds,
        savedAtEpoch: savedAtEpoch ?? this.savedAtEpoch,
      );

  Map<String, dynamic> toJson() => {
    'isRunning': isRunning,
    'remainingSeconds': remainingSeconds,
    'totalSeconds': totalSeconds,
    'savedAtEpoch': savedAtEpoch,
  };

  factory TimerStateModel.fromJson(Map<String, dynamic> json) => TimerStateModel(
    isRunning: json['isRunning'] as bool,
    remainingSeconds: json['remainingSeconds'] as int,
    totalSeconds: json['totalSeconds'] as int,
    savedAtEpoch: json['savedAtEpoch'] as int?,
  );
}
