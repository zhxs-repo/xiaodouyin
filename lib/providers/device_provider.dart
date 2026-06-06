import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:vibration/vibration.dart';
import '../core/utils/platform_utils.dart';

class DeviceProvider extends ChangeNotifier {
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _batterySubscription;
  int _batteryLevel = 100;
  bool _vibrationEnabled = true;

  int get batteryLevel => _batteryLevel;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get canVibrate => PlatformUtils.isMobile;

  Future<void> initBattery() async {
    if (PlatformUtils.isDesktop) return;
    _batteryLevel = await _battery.batteryLevel;
    _batterySubscription = _battery.onBatteryStateChanged.listen((_) async {
      _batteryLevel = await _battery.batteryLevel;
      notifyListeners();
    });
  }

  void setVibrationEnabled(bool enabled) {
    _vibrationEnabled = enabled;
    notifyListeners();
  }

  Future<void> vibrate({int duration = 50}) async {
    if (!_vibrationEnabled || !PlatformUtils.isMobile) return;
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(duration: duration);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    super.dispose();
  }
}
