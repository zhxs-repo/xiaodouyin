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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<ConfigProvider>(
        builder: (context, cp, _) {
          final config = cp.config;
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
              _sectionTitle('播放设置'),
              _buildSwitch('连播模式', config.playMode == PlayMode.normal, (v) => cp.updateField(playMode: v ? PlayMode.normal : PlayMode.loop)),
              _buildSlider('缩放比例', config.scale, 0.5, 3.0, onPreview: (v) => cp.updateFieldMemoryOnly(scale: v), onConfirm: (v) => cp.updateField(scale: v)),
              _buildSlider('旋转角度', config.rotation, 0, 270, onPreview: (v) => cp.updateFieldMemoryOnly(rotation: v), onConfirm: (v) => cp.updateField(rotation: v), divisions: 3),
              _buildSlider('色彩饱和度', config.saturation, 0, 200, onPreview: (v) => cp.updateFieldMemoryOnly(saturation: v), onConfirm: (v) => cp.updateField(saturation: v)),
              _sectionTitle('显示设置'),
              _buildSlider('UI透明度', config.uiOpacity, 0, 1, onPreview: (v) => cp.updateFieldMemoryOnly(uiOpacity: v), onConfirm: (v) => cp.updateField(uiOpacity: v)),
              _buildSlider('视频名透明度', config.nameOpacity, 0, 1, onPreview: (v) => cp.updateFieldMemoryOnly(nameOpacity: v), onConfirm: (v) => cp.updateField(nameOpacity: v)),
              _buildSlider('字体大小', config.fontSize, 10, 30, onPreview: (v) => cp.updateFieldMemoryOnly(fontSize: v), onConfirm: (v) => cp.updateField(fontSize: v)),
              _buildColorPicker('文字颜色', config.textColor, (color) => cp.updateField(textColor: color)),
              _buildDropdown('文字特效', config.textEffect.name, ['solid', 'gradient', 'colorful'], (v) => cp.updateField(textEffect: TextEffectType.values.firstWhere((e) => e.name == v))),
              _sectionTitle('功能开关'),
              if (context.read<DeviceProvider>().canVibrate)
                _buildSwitch('震动反馈', config.vibrationEnabled, (v) { cp.updateField(vibrationEnabled: v); context.read<DeviceProvider>().setVibrationEnabled(v); }),
              _buildSwitch('滑动动画', config.swipeAnimationEnabled, (v) => cp.updateField(swipeAnimationEnabled: v)),
              _buildSwitch('缩略图载入', config.thumbnailLoadEnabled, (v) => cp.updateField(thumbnailLoadEnabled: v)),
              _buildSwitch('全局续播', config.globalResumeEnabled, (v) { cp.updateField(globalResumeEnabled: v); context.read<ResumeProvider>().setEnabled(v); }),
              // 修仙开关
              Consumer<CultivationProvider>(
                builder: (context, cultivation, _) => SwitchListTile(
                  title: const Text('修仙模式'),
                  subtitle: cultivation.enabled ? Text('${cultivation.realmName} | 灵力:${cultivation.currentExp}', style: const TextStyle(color: Colors.amber, fontSize: 11)) : null,
                  value: cultivation.enabled,
                  onChanged: (v) => cultivation.setEnabled(v),
                ),
              ),
              _sectionTitle('数据管理'),
              ListTile(title: const Text('播放历史'), trailing: const Icon(Icons.history), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayHistoryPage()))),
              ListTile(title: const Text('操作教程'), trailing: const Icon(Icons.help_outline), onTap: () => showTutorialDialog(context)),
              ListTile(title: const Text('导出数据'), trailing: const Icon(Icons.upload), onTap: _isOperating ? null : () => _exportData(context)),
              ListTile(title: const Text('导入数据'), trailing: const Icon(Icons.download), onTap: _isOperating ? null : () => _importData(context)),
              ListTile(title: const Text('导入视频'), trailing: const Icon(Icons.video_call), onTap: _isOperating ? null : () => _importVideo(context)),
              _sectionTitle('自定义目录'),
              _buildDirPicker(context, '视频目录', config.customVideoDir, (path) => cp.updateField(customVideoDir: path), () => cp.updateField(customVideoDir: '')),
              _buildDirPicker(context, '图片目录', config.customImageDir, (path) => cp.updateField(customImageDir: path), () => cp.updateField(customImageDir: '')),
              _sectionTitle('默认启动模式'),
              _buildDropdown('启动模式', config.defaultStartupMode, ['none', 'video', 'beauty', 'online'], (v) => cp.updateField(defaultStartupMode: v)),
              _sectionTitle('密码设置'),
              _buildPasswordField('视频模式密码', config.videoModePassword, (v) => cp.updateField(videoModePassword: v)),
              _buildPasswordField('美图模式密码', config.beautyModePassword, (v) => cp.updateField(beautyModePassword: v)),
              _buildPasswordField('在线模式密码', config.onlineModePassword, (v) => cp.updateField(onlineModePassword: v)),
            ],
          ),
              if (_isOperating)
                const Center(child: CircularProgressIndicator()),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)));

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(title: Text(label), value: value, onChanged: onChanged);

  Widget _buildSlider(String label, double value, double min, double max, {required ValueChanged<double> onPreview, required ValueChanged<double> onConfirm, int? divisions}) => ListTile(
    title: Text(label),
    subtitle: Slider(value: value, min: min, max: max, divisions: divisions ?? (max - min > 10 ? null : (max - min).toInt()), onChanged: onPreview, onChangeEnd: onConfirm),
    trailing: Text(value.toStringAsFixed(2), style: const TextStyle(color: Colors.white54)),
  );

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String> onChanged) => ListTile(
    title: Text(label),
    trailing: DropdownButton<String>(value: value, items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: (v) { if (v != null) onChanged(v); }),
  );

  Widget _buildColorPicker(String label, String currentColor, ValueChanged<String> onChanged) {
    final hex = currentColor.replaceAll('#', '');
    final displayColor = hex.length == 6 ? Color(int.parse('FF$hex', radix: 16)) : Colors.white;
    return ListTile(
      title: Text(label),
      trailing: GestureDetector(
        onTap: () async {
          final result = await showDialog<String>(context: context, builder: (_) => ColorPickerDialog(initialColor: currentColor));
          if (result != null) onChanged(result);
        },
        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle, border: Border.all(color: Colors.white54))),
      ),
    );
  }

  Widget _buildPasswordField(String label, String currentValue, ValueChanged<String> onChanged) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(currentValue, style: const TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 4)),
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

  Widget _buildDirPicker(BuildContext context, String label, String? currentPath, ValueChanged<String> onSelected, VoidCallback onReset) {
    final displayPath = (currentPath != null && currentPath.isNotEmpty) ? currentPath : '默认';
    return ListTile(
      title: Text(label),
      subtitle: Text(displayPath, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.folder_open), onPressed: () async {
            final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择$label');
            if (dir != null) onSelected(dir);
          }),
          if (currentPath != null && currentPath.isNotEmpty)
            IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onReset),
        ],
      ),
    );
  }

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

        // 恢复笔记本数据
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
          // 刷新视频列表
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
