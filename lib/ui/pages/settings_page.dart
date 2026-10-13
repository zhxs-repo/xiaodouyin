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
import '../widgets/settings_controls.dart';
import 'play_history_page.dart';
import 'video_settings_page.dart';

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
    ('video', '短视频'),
    ('longvideo', '长视频'),
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
                  SettingsSection(
                    title: '主题',
                    icon: Icons.palette_rounded,
                    children: [
                      SettingsSegmented(
                        label: '主题模式',
                        value: config.themeMode,
                        options: _themeModes,
                        onChanged: (v) => cp.updateField(themeMode: v),
                      ),
                    ],
                  ),

                  // ==================== 播放 ====================
                  SettingsSection(
                    title: '播放',
                    icon: Icons.play_circle_outline_rounded,
                    children: [
                      SettingsSegmented(
                        label: '循环模式',
                        value: config.playMode.name,
                        options: _playModes.map((e) => (e.$1.name, e.$2, e.$3)).toList(),
                        onChanged: (v) => cp.updateField(
                          playMode: PlayMode.values.firstWhere((e) => e.name == v),
                        ),
                      ),
                      SettingsNavTile(
                        label: '视频画面与文字',
                        icon: Icons.straighten_rounded,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const VideoSettingsPage()),
                        ),
                      ),
                    ],
                  ),

                  // ==================== 功能开关 ====================
                  SettingsSection(
                    title: '功能开关',
                    icon: Icons.toggle_on_rounded,
                    children: [
                      if (context.read<DeviceProvider>().canVibrate)
                        SettingsSwitchTile(
                          label: '震动反馈',
                          value: config.vibrationEnabled,
                          onChanged: (v) {
                            cp.updateField(vibrationEnabled: v);
                            context.read<DeviceProvider>().setVibrationEnabled(v);
                          },
                        ),
                      SettingsSwitchTile(
                        label: '滑动动画',
                        value: config.swipeAnimationEnabled,
                        onChanged: (v) => cp.updateField(swipeAnimationEnabled: v),
                      ),
                      SettingsSwitchTile(
                        label: '缩略图载入',
                        value: config.thumbnailLoadEnabled,
                        onChanged: (v) => cp.updateField(thumbnailLoadEnabled: v),
                      ),
                      SettingsSwitchTile(
                        label: '全局续播',
                        value: config.globalResumeEnabled,
                        onChanged: (v) {
                          cp.updateField(globalResumeEnabled: v);
                          context.read<ResumeProvider>().setEnabled(v);
                        },
                      ),
                      Consumer<CultivationProvider>(
                        builder: (context, cultivation, _) => SettingsSwitchTile(
                          label: '修仙模式',
                          subtitle: cultivation.enabled
                              ? '${cultivation.realmName} | 灵力:${cultivation.currentExp}'
                              : null,
                          subtitleColor: Colors.amber,
                          value: cultivation.enabled,
                          onChanged: (v) => cultivation.setEnabled(v),
                        ),
                      ),
                    ],
                  ),

                  // ==================== 数据管理 ====================
                  SettingsSection(
                    title: '数据管理',
                    icon: Icons.folder_rounded,
                    children: [
                      SettingsNavTile(
                        label: '播放历史',
                        icon: Icons.history_rounded,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayHistoryPage())),
                      ),
                      SettingsNavTile(
                        label: '操作教程',
                        icon: Icons.help_outline_rounded,
                        onTap: () => showTutorialDialog(context),
                      ),
                      SettingsNavTile(
                        label: '导出数据',
                        icon: Icons.upload_rounded,
                        enabled: !_isOperating,
                        onTap: () => _exportData(context),
                      ),
                      SettingsNavTile(
                        label: '导入数据',
                        icon: Icons.download_rounded,
                        enabled: !_isOperating,
                        onTap: () => _importData(context),
                      ),
                      SettingsNavTile(
                        label: '导入视频',
                        icon: Icons.video_call_rounded,
                        enabled: !_isOperating,
                        onTap: () => _importVideo(context),
                      ),
                    ],
                  ),

                  // ==================== 自定义目录 ====================
                  SettingsSection(
                    title: '自定义目录',
                    icon: Icons.folder_special_rounded,
                    children: [
                      SettingsDirTile(
                        label: '视频目录',
                        currentPath: config.customVideoDir,
                        onSelected: (path) => cp.updateField(customVideoDir: path),
                        onReset: () => cp.updateField(customVideoDir: ''),
                      ),
                      SettingsDirTile(
                        label: '图片目录',
                        currentPath: config.customImageDir,
                        onSelected: (path) => cp.updateField(customImageDir: path),
                        onReset: () => cp.updateField(customImageDir: ''),
                      ),
                    ],
                  ),

                  // ==================== 启动模式 ====================
                  SettingsSection(
                    title: '启动模式',
                    icon: Icons.rocket_launch_rounded,
                    children: [
                      SettingsSegmented(
                        label: '默认启动',
                        value: config.defaultStartupMode,
                        options: _startupModes.map((e) => (e.$1, e.$2, Icons.app_shortcut_rounded)).toList(),
                        onChanged: (v) => cp.updateField(defaultStartupMode: v),
                      ),
                    ],
                  ),

                  // ==================== 密码 ====================
                  SettingsSection(
                    title: '密码设置',
                    icon: Icons.lock_rounded,
                    children: [
                      SettingsPasswordTile(
                        label: '短视频/长视频密码',
                        currentValue: config.videoModePassword,
                        onChanged: (v) => cp.updateField(videoModePassword: v),
                      ),
                      SettingsPasswordTile(
                        label: '美图模式密码',
                        currentValue: config.beautyModePassword,
                        onChanged: (v) => cp.updateField(beautyModePassword: v),
                      ),
                      SettingsPasswordTile(
                        label: '在线模式密码',
                        currentValue: config.onlineModePassword,
                        onChanged: (v) => cp.updateField(onlineModePassword: v),
                      ),
                    ],
                  ),

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
