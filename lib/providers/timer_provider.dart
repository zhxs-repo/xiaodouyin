import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/utils/platform_utils.dart';
import '../data/services/storage_service.dart';
import '../data/models/timer_state.dart';
import '../core/constants/storage_keys.dart';

class TimerProvider extends ChangeNotifier {
  final StorageService _storage;
  TimerStateModel _state = const TimerStateModel(
    isRunning: false, remainingSeconds: 0, totalSeconds: 0);
  Timer? _timer;

  TimerProvider(this._storage);

  TimerStateModel get state => _state;
  bool get isRunning => _state.isRunning;
  int get remainingSeconds => _state.remainingSeconds;

  Future<void> load() async {
    final json = _storage.getJson(StorageKeys.timerState);
    if (json != null) {
      _state = TimerStateModel.fromJson(json);
      if (_state.isRunning) {
        // 计算应用关闭期间流逝的时间
        if (_state.savedAtEpoch != null) {
          final elapsed = DateTime.now().millisecondsSinceEpoch ~/ 1000 - _state.savedAtEpoch!;
          final adjusted = _state.remainingSeconds - elapsed;
          if (adjusted <= 0) {
            // 定时器已过期，直接取消
            cancelTimer();
            return;
          }
          _state = _state.copyWith(remainingSeconds: adjusted);
        }
        _startCountdown();
      }
    }
  }

  void setTimer(int seconds) {
    _state = TimerStateModel(
      isRunning: true,
      remainingSeconds: seconds,
      totalSeconds: seconds,
    );
    _saveState();
    _startCountdown();
    notifyListeners();
  }

  void cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _state = const TimerStateModel(
      isRunning: false, remainingSeconds: 0, totalSeconds: 0);
    _saveState();
    notifyListeners();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.remainingSeconds > 0) {
        _state = _state.copyWith(
          remainingSeconds: _state.remainingSeconds - 1);
        _saveState();
        notifyListeners();
      } else {
        _timer?.cancel();
        _timer = null;
        _state = const TimerStateModel(
          isRunning: false, remainingSeconds: 0, totalSeconds: 0);
        _saveState();
        notifyListeners();
        // 退出应用
        _exitApp();
      }
    });
  }

  void _exitApp() {
    if (PlatformUtils.isDesktop) {
      exit(0);
    } else if (PlatformUtils.isAndroid) {
      SystemNavigator.pop();
    }
  }

  Future<void> _saveState() async {
    final stateToSave = _state.copyWith(
      savedAtEpoch: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    await _storage.setJson(StorageKeys.timerState, stateToSave.toJson());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
