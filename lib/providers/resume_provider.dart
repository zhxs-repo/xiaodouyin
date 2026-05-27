import 'dart:async';
import 'package:flutter/material.dart';
import '../data/repositories/play_history_repository.dart';
import '../data/models/play_history.dart';

class ResumeProvider extends ChangeNotifier {
  final PlayHistoryRepository _repository;
  bool _isEnabled = true;
  Timer? _saveTimer;

  ResumeProvider(this._repository);

  bool get isEnabled => _isEnabled;
  Map<String, PlayHistoryRecord> get history => _repository.history;

  Future<void> load() async {
    await _repository.load();
  }

  void setEnabled(bool enabled) {
    _isEnabled = enabled;
    notifyListeners();
  }

  Duration? getResumePosition(String videoPath) {
    if (!_isEnabled) return null;
    final record = _repository.getRecord(videoPath);
    if (record == null) return null;
    // 如果记录位置超出视频时长，返回null(从头播放)
    if (record.position >= record.duration) return null;
    return record.position;
  }

  void startAutoSave(String videoPath, Duration Function() getPosition, Duration Function() getDuration) {
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final position = getPosition();
      final duration = getDuration();
      if (duration.inSeconds > 60) {
        _repository.saveRecord(PlayHistoryRecord(
          videoPath: videoPath,
          position: position,
          duration: duration,
          timestamp: DateTime.now(),
        ));
      }
    });
  }

  void stopAutoSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  Future<void> clearRecord(String videoPath) async {
    await _repository.clearRecord(videoPath);
  }

  Future<void> clearAll() async {
    await _repository.clearAll();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
