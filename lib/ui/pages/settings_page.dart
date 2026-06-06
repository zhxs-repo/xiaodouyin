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

  // 主题模式选项
  static const _themeModes = [
    ('system', '跟随系统', Icons.brightness_auto_rounded),
    ('dark', '深色', Icons.dark_mode_rounded),
    ('light', '浅色', Icons.light_mode_rounded),
  ];

  // 循环模式选项
  static const _playModes = [
    (PlayMode.normal, '播完即停', Icons.stop_rounded),
    (PlayMode.loop, '列表循环', Icons.loop_rounded),
    (PlayMode.loopOne, '单视频循环', Icons.repeat_one_rounded),
  ];

  // 启动模式选项
  static const _startupModes = [
    ('none', '无'),
    ('video', '视频'),
    ('beauty', '美图'),
    ('online', '在线'),
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
                  // ==================== 主题 ====================
                  _buildSection(context, '主题', Icons.palette_rounded, [
                    _buildSegmented(
                      label: '主题模式',
                      value: config.themeMode,
                      options: _themeModes,
                      onChanged: (v) => cp.updateField(themeMode: v),
                    ),
                  ]),

                  // ==================== 播放 ====================
                  _buildSection(context, '播放', Icons.play_circle_outline_rounded, [
                    _buildSegmented(
                      label: '循环模式',
                      value: config.playMode.name,
                      options: _playModes.map((e) => (e.$1.name, e.$2, e.$3)).toList(),
                      onChanged: (v) => cp.updateField(
                        playMode: PlayMode.values.firstWhere((e) => e.name == v),
                      ),
                    ),
                    _buildSliderTile(
                      label: '缩放比例',
                      value: config.scale,
                      min: 0.5, max: 3.0,
                      valueText: config.scale.toStringAsFixed(2),
                      onPreview: (v) => cp.updateFieldMemoryOnly(scale: v),
                      onConfirm: (v) => cp.updateField(scale: v),
                    ),
                    _buildSliderTile(
                      label: '旋转角度',
                      value: config.rotation,
                      min: 0, max: 270,
                      divisions: 3,
                      valueText: '${config.rotation.toInt()}°',
                      onPreview: (v) => cp.updateFieldMemoryOnly(rotation: v),
                      onConfirm: (v) => cp.updateField(rotation: v),
                    ),
                    _buildSliderTile(
                      label: '色彩饱和度',
                      value: config.saturation,
                      min: 0, max: 200,
                      valueText: '${config.saturation.toInt()}%',
                      onPreview: (v) => cp.updateFieldMemoryOnly(saturation: v),
                      onConfirm: (v) => cp.updateField(saturation: v),
                    ),
                  ]),

                  // ==================== 显示 ====================
                  _buildSection(context, '显示', Icons.visibility_rounded, [
                    _buildSliderTile(
                      label: 'UI 透明度',
                      value: config.uiOpacity,
                      min: 0, max: 1,
                      valueText: '${(config.uiOpacity * 100).toInt()}%',
                      onPreview: (v) => cp.updateFieldMemoryOnly(uiOpacity: v),
                      onConfirm: (v) => cp.updateField(uiOpacity: v),
                    ),
                    _buildSliderTile(
                      label: '视频名透明度',
                      value: config.nameOpacity,
                      min: 0, max: 1,
                      valueText: '${(config.nameOpacity * 100).toInt()}%',
                      onPreview: (v) => cp.updateFieldMemoryOnly(nameOpacity: v),
                      onConfirm: (v) => cp.updateField(nameOpacity: v),
                    ),
                    _buildSliderTile(
                      label: '字体大小',
                      value: config.fontSize,
                      min: 10, max: 30,
                      divisions: 20,
                      valueText: '${config.fontSize.toInt()}',
                      onPreview: (v) => cp.updateFieldMemoryOnly(fontSize: v),
                      onConfirm: (v) => cp.updateField(fontSize: v),
                    ),
                    _buildColorPickerTile(
                      label: '文字颜色',
                      currentColor: config.textColor,
                      onChanged: (c) => cp.updateField(textColor: c),
                    ),
                    _buildSegmented(
                      label: '文字特效',
                      value: config.textEffect.name,
                      options: const [
                        ('solid', '实色', Icons.format_color_fill_rounded),
                        ('gradient', '渐变', Icons.gradient_rounded),
                        ('colorful', '彩色', Icons.palette_rounded),
                      ],
                      onChanged: (v) => cp.updateField(
                        textEffect: TextEffectType.values.firstWhere((e) => e.name == v),
                      ),
                    ),
                  ]),

                  // ==================== 功能开关 ====================
                  _buildSection(context, '功能开关', Icons.toggle_on_rounded, [
                    if (context.read<DeviceProvider>().canVibrate)
                      _buildSwitchTile(
                        label: '震动反馈',
                        value: config.vibrationEnabled,
                        onChanged: (v) {
                          cp.updateField(vibrationEnabled: v);
                          context.read<DeviceProvider>().setVibrationEnabled(v);
                        },
                      ),
                    _buildSwitchTile(
                      label: '滑动动画',
                      value: config.swipeAnimationEnabled,
                      onChanged: (v) => cp.updateField(swipeAnimationEnabled: v),
                    ),
                    _buildSwitchTile(
                      label: '缩略图载入',
                      value: config.thumbnailLoadEnabled,
                      onChanged: (v) => cp.updateField(thumbnailLoadEnabled: v),
                    ),
                    _buildSwitchTile(
                      label: '全局续播',
                      value: config.globalResumeEnabled,
                      onChanged: (v) {
                        cp.updateField(globalResumeEnabled: v);
                        context.read<ResumeProvider>().setEnabled(v);
                      },
                    ),
                    Consumer<CultivationProvider>(
                      builder: (context, cultivation, _) => _buildSwitchTile(
                        label: '修仙模式',
                        subtitle: cultivation.enabled
                            ? '${cultivation.realmName} | 灵力:${cultivation.currentExp}'
                            : null,
                        subtitleColor: Colors.amber,
                        value: cultivation.enabled,
                        onChanged: (v) => cultivation.setEnabled(v),
                      ),
                    ),
                  ]),

                  // ==================== 数据管理 ====================
                  _buildSection(context, '数据管理', Icons.folder_rounded, [
                    _buildNavTile(
                      label: '播放历史',
                      icon: Icons.history_rounded,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayHistoryPage())),
                    ),
                    _buildNavTile(
                      label: '操作教程',
                      icon: Icons.help_outline_rounded,
                      onTap: () => showTutorialDialog(context),
                    ),
                    _buildNavTile(
                      label: '导出数据',
                      icon: Icons.upload_rounded,
                      enabled: !_isOperating,
                      onTap: () => _exportData(context),
                    ),
                    _buildNavTile(
                      label: '导入数据',
                      icon: Icons.download_rounded,
                      enabled: !_isOperating,
                      onTap: () => _importData(context),
                    ),
                    _buildNavTile(
                      label: '导入视频',
                      icon: Icons.video_call_rounded,
                      enabled: !_isOperating,
                      onTap: () => _importVideo(context),
                    ),
                  ]),

                  // ==================== 自定义目录 ====================
                  _buildSection(context, '自定义目录', Icons.folder_special_rounded, [
                    _buildDirPicker(
                      context,
                      label: '视频目录',
                      currentPath: config.customVideoDir,
                      onSelected: (path) => cp.updateField(customVideoDir: path),
                      onReset: () => cp.updateField(customVideoDir: ''),
                    ),
                    _buildDirPicker(
                      context,
                      label: '图片目录',
                      currentPath: config.customImageDir,
                      onSelected: (path) => cp.updateField(customImageDir: path),
                      onReset: () => cp.updateField(customImageDir: ''),
                    ),
                  ]),

                  // ==================== 启动模式 ====================
                  _buildSection(context, '启动模式', Icons.rocket_launch_rounded, [
                    _buildSegmented(
                      label: '默认启动',
                      value: config.defaultStartupMode,
                      options: _startupModes.map((e) => (e.$1, e.$2, Icons.app_shortcut_rounded)).toList(),
                      onChanged: (v) => cp.updateField(defaultStartupMode: v),
                    ),
                  ]),

                  // ==================== 密码 ====================
                  _buildSection(context, '密码设置', Icons.lock_rounded, [
                    _buildPasswordTile(
                      label: '视频模式密码',
                      currentValue: config.videoModePassword,
                      onChanged: (v) => cp.updateField(videoModePassword: v),
                    ),
                    _buildPasswordTile(
                      label: '美图模式密码',
                      currentValue: config.beautyModePassword,
                      onChanged: (v) => cp.updateField(beautyModePassword: v),
                    ),
                    _buildPasswordTile(
                      label: '在线模式密码',
                      currentValue: config.onlineModePassword,
                      onChanged: (v) => cp.updateField(onlineModePassword: v),
                    ),
                  ]),

                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '小抖音 · v1.0.0',
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

  // ==================== M3 通用组件 ====================

  /// 分组卡片容器
  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
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
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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

  /// 三段式按钮组 (跟随系统/深色/浅色 等)
  Widget _buildSegmented({
    required String label,
    required String value,
    required List<(String, String, IconData)> options,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: options
                .map((o) => ButtonSegment<String>(
                      value: o.$1,
                      icon: Icon(o.$3, size: 16),
                      label: Text(o.$2),
                    ))
                .toList(),
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }

  /// Switch 列表项
  Widget _buildSwitchTile({
    required String label,
    String? subtitle,
    Color? subtitleColor,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(label),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 11))
          : null,
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  /// Slider 列表项
  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    int? divisions,
    required String valueText,
    required ValueChanged<double> onPreview,
    required ValueChanged<double> onConfirm,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text(
                valueText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onPreview,
            onChangeEnd: onConfirm,
          ),
        ],
      ),
    );
  }

  /// 颜色选择列表项
  Widget _buildColorPickerTile({
    required String label,
    required String currentColor,
    required ValueChanged<String> onChanged,
  }) {
    final hex = currentColor.replaceAll('#', '');
    final defaultColor = Theme.of(context).colorScheme.onSurface;
    final displayColor = hex.length == 6 ? Color(int.parse('FF$hex', radix: 16)) : defaultColor;
    return ListTile(
      title: Text(label),
      trailing: GestureDetector(
        onTap: () async {
          final result = await showDialog<String>(
            context: context,
            builder: (_) => ColorPickerDialog(initialColor: currentColor),
          );
          if (result != null) onChanged(result);
        },
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: displayColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  /// 导航列表项
  Widget _buildNavTile({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: enabled ? onTap : null,
    );
  }

  /// 密码列表项
  Widget _buildPasswordTile({
    required String label,
    required String currentValue,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '*' * currentValue.length,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
              letterSpacing: 4,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () {
              final controller = TextEditingController(text: currentValue);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('修改$label'),
                  content: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: '输入新密码'),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                    TextButton(
                      onPressed: () {
                        final newPwd = controller.text.trim();
                        if (newPwd.isNotEmpty) {
                          onChanged(newPwd);
                          Navigator.pop(ctx);
                          ToastUtil.show(context, '密码已更新');
                        }
                      },
                      child: const Text('确认'),
                    ),
                  ],
                ),
              ).then((_) => controller.dispose());
            },
          ),
        ],
      ),
    );
  }

  /// 目录选择列表项
  Widget _buildDirPicker(
    BuildContext context, {
    required String label,
    required String? currentPath,
    required ValueChanged<String> onSelected,
    required VoidCallback onReset,
  }) {
    final displayPath = (currentPath != null && currentPath.isNotEmpty) ? currentPath : '默认目录';
    return ListTile(
      title: Text(label),
      subtitle: Text(
        displayPath,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: () async {
              final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择$label');
              if (dir != null) onSelected(dir);
            },
          ),
          if (currentPath != null && currentPath.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              onPressed: onReset,
            ),
        ],
      ),
    );
  }

  // ==================== 数据导入导出 ====================

  Future<void> _exportData(BuildContext context) async {
    setState(() => _isOperating = true);
    try {
      final favoriteProvider = context.read<FavoriteProvider>();
      final searchProvider = context.read<SearchProvider>();
      final vp = context.read<VideoPlayerProvider>();
      final cp = context.read<ConfigProvider>();
      final cultivation = context.read<CultivationProvider>();
      final storage = await StorageService.getInstance();

      final data = <String, dynamic>{
        'config': cp.config.toJson(),
        'lastVideoIndex': vp.currentIndex,
        'favoriteVideos': favoriteProvider.favorites.map((e) => e.toJson()).toList(),
        'searchHistory': searchProvider.searchHistory,
        'cultivation': {'exp': cultivation.currentExp, 'realmIndex': cultivation.currentRealmIndex},
        'notebook': storage.getStringList(StorageKeys.videoNotebook) ?? [],
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择导出目录');
      if (dir != null && context.mounted) {
        final file = File(p.join(dir, 'xiaodouyin_export.json'));
        await file.writeAsString(jsonStr);
        if (context.mounted) ToastUtil.show(context, '数据已导出');
      }
    } catch (e) {
      if (context.mounted) ToastUtil.show(context, '导出失败: $e');
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }

  Future<void> _importData(BuildContext context) async {
    setState(() => _isOperating = true);
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final jsonStr = await file.readAsString();
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;

        if (data.containsKey('config') && context.mounted) {
          final newConfig = AppConfig.fromJson(data['config'] as Map<String, dynamic>);
          await context.read<ConfigProvider>().updateConfig(newConfig);
          if (!context.mounted) return;
        }

        if (data.containsKey('notebook')) {
          final notebook = (data['notebook'] as List).cast<String>();
          final storage = await StorageService.getInstance();
          await storage.setStringList(StorageKeys.videoNotebook, notebook);
        }

        if (context.mounted) ToastUtil.show(context, '数据已导入');
      } catch (e) {
        if (context.mounted) ToastUtil.show(context, '导入失败: $e');
      }
    }
    if (mounted) setState(() => _isOperating = false);
  }

  Future<void> _importVideo(BuildContext context) async {
    setState(() => _isOperating = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
      if (result != null && result.files.isNotEmpty && context.mounted) {
        final config = context.read<ConfigProvider>().config;
        final fileService = FileService(customVideoDir: config.customVideoDir);
        final videoRepo = VideoRepository(fileService);
        int successCount = 0;
        for (final file in result.files) {
          if (file.path != null) {
            final destPath = await videoRepo.importVideo(file.path!);
            if (destPath != null) successCount++;
          }
        }
        if (context.mounted) {
          ToastUtil.show(context, '已导入 $successCount 个视频');
          final videos = await videoRepo.loadVideos();
          if (videos.isNotEmpty && context.mounted) {
            context.read<VideoPlayerProvider>().setVideoList(videos);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isOperating = false);
    }
  }
}
