import 'dart:async';
import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';
import '../core/constants/storage_keys.dart';

/// 修仙境界定义
class CultivationRealm {
  final String name;
  final int expRequired;
  const CultivationRealm(this.name, this.expRequired);

  static const List<CultivationRealm> realms = [
    CultivationRealm('凡人', 0),
    CultivationRealm('练气', 100),
    CultivationRealm('筑基', 500),
    CultivationRealm('金丹', 2000),
    CultivationRealm('元婴', 8000),
    CultivationRealm('化神', 30000),
    CultivationRealm('合体', 100000),
    CultivationRealm('大乘', 300000),
    CultivationRealm('渡劫', 1000000),
    CultivationRealm('仙人', 3000000),
  ];
}

class CultivationProvider extends ChangeNotifier {
  int _currentExp = 0;
  int _currentRealmIndex = 0;
  bool _enabled = false;
  Timer? _expTimer;
  Timer? _saveTimer;
  bool _dirty = false;

  int get currentExp => _currentExp;
  int get currentRealmIndex => _currentRealmIndex;
  bool get enabled => _enabled;
  String get realmName => CultivationRealm.realms[_currentRealmIndex].name;
  double get expProgress {
    if (_currentRealmIndex >= CultivationRealm.realms.length - 1) return 1.0;
    final current = CultivationRealm.realms[_currentRealmIndex].expRequired;
    final next = CultivationRealm.realms[_currentRealmIndex + 1].expRequired;
    if (next == current) return 1.0;
    return ((_currentExp - current) / (next - current)).clamp(0.0, 1.0);
  }

  Future<void> load() async {
    final storage = await StorageService.getInstance();
    _enabled = storage.getBool(StorageKeys.cultivationEnabled) ?? false;
    final stateJson = storage.getJson(StorageKeys.cultivationState);
    if (stateJson != null) {
      _currentExp = stateJson['exp'] as int? ?? 0;
      _currentRealmIndex = stateJson['realmIndex'] as int? ?? 0;
    }
    if (_enabled) _startExpTimer();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final storage = await StorageService.getInstance();
    await storage.setBool(StorageKeys.cultivationEnabled, value);
    if (value) {
      _startExpTimer();
    } else {
      _expTimer?.cancel();
      _expTimer = null;
    }
    notifyListeners();
  }

  void _startExpTimer() {
    _expTimer?.cancel();
    // 每秒增加1点灵力
    _expTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _addExp(1);
    });
    // 节流保存：每10秒检查一次
    _saveTimer?.cancel();
    _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_dirty) {
        _dirty = false;
        _saveState();
      }
    });
  }

  void _addExp(int amount) {
    _currentExp += amount;
    // 检查是否突破
    while (_currentRealmIndex < CultivationRealm.realms.length - 1) {
      final nextRealm = CultivationRealm.realms[_currentRealmIndex + 1];
      if (_currentExp >= nextRealm.expRequired) {
        _currentRealmIndex++;
      } else {
        break;
      }
    }
    _dirty = true;
    notifyListeners();
  }

  Future<void> _saveState() async {
    final storage = await StorageService.getInstance();
    await storage.setJson(StorageKeys.cultivationState, {
      'exp': _currentExp,
      'realmIndex': _currentRealmIndex,
    });
  }

  @override
  void dispose() {
    _expTimer?.cancel();
    _saveTimer?.cancel();
    // 退出时确保保存
    if (_dirty) _saveState();
    super.dispose();
  }
}
