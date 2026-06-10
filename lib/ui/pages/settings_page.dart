import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';
import 'dart:io';
import '../../providers/config_provider.dart';
import '../../providers/video_player_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/search_provider.dart';
import '../../providers/cultivation_provider.dart';
import '../../data/services/storage_service.dart';
import '../../core/constants/storage_keys.dart';
import '../../providers/device_provider.dart';
import '../../providers/resume_provider.dart';
import '../../data/models/app_config.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/file_service.dart';
import '../../core/utils/toast_util.dart';
import '../../core/utils/tutorial_util.dart';
import '../widgets/color_picker_dialog.dart';
import 'play_history_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isOperating = false;

  static const _themeModes = [
    ('system', '跟随系统', Icons.brightness_auto_rounded),
    ('dark', '深色', Icons.dark_mode_rounded),
    ('light', '浅色', Icons.light_mode_rounded),
  ];

  static const _playModes = [
    (PlayMode.normal, '播完即停', Icons.stop_rounded),
    (PlayMode.loop, '列表循环', Icons.loop_rounded),
    (PlayMode.loopOne, '单视频循环', Icons.repeat_one_rounded),
  ];

  static const _startupModes = [
    ('none', '无'),
    ('video', '视频'),
    ('beauty', '美图'),
    ('online', '在线'),
  ];

  static const _performanceLevels = [
    ('low', '低端设备', Icons.phone_android_rounded),
    ('medium', '中端设备', Icons.devices_rounded),
    ('high', '高端设备', Icons.speed_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<ConfigProvider>(
        builder: (context, cp, _) {
          final config = cp.config;
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: [
                  _buildSection(context, '播放策略', Icons.smart_display_rounded, [
                    _buildSwitchTile(
                      label: '智能播放模式',
                      subtitle: '根据视频时长自动切换短视频/长视频布局（默认关闭）',
                      value: config.smartPlayModeEnabled,
                      onChanged: (v) => cp.toggleSmartPlayMode(v),
                    ),
                    _buildSegmented(
                      label: '设备性能等级',
                      value: config.devicePerformanceLevel,
                      options: _performanceLevels,
                      onChanged: (v) => cp.updatePerformanceLevel(v),
                    ),
                    _buildSwitchTile(
                      label: '高级特效',
                      subtitle: '玻璃拟态、缩略图预览等视觉效果',
                      value: config.advancedEffectsEnabled,
                      onChanged: (v) => cp.toggleAdvancedEffects(v),
                    ),
                  ]),
                  _buildSection(context, '主题', Icons.palette_rounded, [
                    _buildSegmented(
                      label: '主题模式',
                      value: config.themeMode,
                      options: _themeModes,
                      onChanged: (v) => cp.updateField(themeMode: v),
                    ),
                  ]),
                  _buildSection(context, '播放', Icons.play_circle_outline_rounded, [
                    _buildSegmented(
                      label: '循环模式',
                      value: config.playMode.name,
                      options: _playModes.map((e) => (e.$1.name, e.$2, e.$3)).toList(),
                      onChanged: (v) => cp.updateField(
                        playMode: PlayMode.values.firstWhere((e) => e.name == v),
                      ),
                    ),
                  ]),
                  _buildSection(context, '数据管理', Icons.folder_rounded, [
                    _buildNavTile(
                      label: '播放历史',
                      icon: Icons.history_rounded,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayHistoryPage())),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '小抖音 · v2.0.0-beta',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isOperating)
                ColoredBox(
                  color: colorScheme.scrim.withValues(alpha: 0.32),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, IconData icon, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainer,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: TextStyle(color: colorScheme.onSurface, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            ...children,
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmented({
    required String label,
    required String value,
    required List<(String, String, IconData)> options,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: options.map((o) => ButtonSegment<String>(value: o.$1, icon: Icon(o.$3, size: 16), label: Text(o.$2))).toList(),
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ]),
    );
  }

  Widget _buildSwitchTile({
    required String label,
    String? subtitle,
    Color? subtitleColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(label),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 11)) : null,
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildNavTile({required String label, required IconData icon, bool enabled = true, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      trailing: enabled ? const Icon(Icons.chevron_right_rounded) : null,
      onTap: enabled ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      enabled: enabled,
    );
  }
}
