import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/app_config.dart';
import '../../providers/config_provider.dart';
import 'settings_page.dart';
import '../widgets/settings_controls.dart';

/// 播放画面与信息层相关设置（数据仍存于全局 AppConfig，对所有视频生效）
class VideoSettingsPage extends StatelessWidget {
  const VideoSettingsPage({super.key});

  static const _videoFits = [
    (VideoFitMode.contain, '完整显示', Icons.fit_screen_rounded),
    (VideoFitMode.cover, '裁满全屏', Icons.crop_free_rounded),
    (VideoFitMode.fitWidth, '适应宽度', Icons.align_horizontal_center_rounded),
    (VideoFitMode.fitHeight, '适应高度', Icons.align_vertical_center_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频设置'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'App 设置',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: Consumer<ConfigProvider>(
        builder: (context, cp, _) {
          final config = cp.config;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // ==================== 画面 ====================
              SettingsSection(
                title: '画面',
                icon: Icons.straighten_rounded,
                children: [
                  SettingsSegmented(
                    label: '画面填充',
                    value: config.videoFit.name,
                    options: _videoFits.map((e) => (e.$1.name, e.$2, e.$3)).toList(),
                    onChanged: (v) => cp.updateField(
                      videoFit: VideoFitMode.values.firstWhere((e) => e.name == v),
                    ),
                  ),
                  SettingsSliderTile(
                    label: '缩放比例',
                    value: config.scale,
                    min: 0.5, max: 3.0,
                    valueText: config.scale.toStringAsFixed(2),
                    onPreview: (v) => cp.updateFieldMemoryOnly(scale: v),
                    onConfirm: (v) => cp.updateField(scale: v),
                  ),
                  SettingsSliderTile(
                    label: '旋转角度',
                    value: config.rotation,
                    min: 0, max: 270,
                    divisions: 3,
                    valueText: '${config.rotation.toInt()}°',
                    onPreview: (v) => cp.updateFieldMemoryOnly(rotation: v),
                    onConfirm: (v) => cp.updateField(rotation: v),
                  ),
                  SettingsSliderTile(
                    label: '色彩饱和度',
                    value: config.saturation,
                    min: 0, max: 200,
                    valueText: '${config.saturation.toInt()}%',
                    onPreview: (v) => cp.updateFieldMemoryOnly(saturation: v),
                    onConfirm: (v) => cp.updateField(saturation: v),
                  ),
                ],
              ),

              // ==================== 文字与信息层 ====================
              SettingsSection(
                title: '文字与信息层',
                icon: Icons.text_format_rounded,
                children: [
                  SettingsSliderTile(
                    label: 'UI 透明度',
                    value: config.uiOpacity,
                    min: 0, max: 1,
                    valueText: '${(config.uiOpacity * 100).toInt()}%',
                    onPreview: (v) => cp.updateFieldMemoryOnly(uiOpacity: v),
                    onConfirm: (v) => cp.updateField(uiOpacity: v),
                  ),
                  SettingsSliderTile(
                    label: '视频名透明度',
                    value: config.nameOpacity,
                    min: 0, max: 1,
                    valueText: '${(config.nameOpacity * 100).toInt()}%',
                    onPreview: (v) => cp.updateFieldMemoryOnly(nameOpacity: v),
                    onConfirm: (v) => cp.updateField(nameOpacity: v),
                  ),
                  SettingsSliderTile(
                    label: '字体大小',
                    value: config.fontSize,
                    min: 10, max: 30,
                    divisions: 20,
                    valueText: '${config.fontSize.toInt()}',
                    onPreview: (v) => cp.updateFieldMemoryOnly(fontSize: v),
                    onConfirm: (v) => cp.updateField(fontSize: v),
                  ),
                  SettingsColorTile(
                    label: '文字颜色',
                    currentColor: config.textColor,
                    onChanged: (c) => cp.updateField(textColor: c),
                  ),
                  SettingsSegmented(
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
                ],
              ),

              const Padding(
                padding: EdgeInsets.only(left: 4, top: 4),
                child: Text(
                  '以上参数对所有视频生效，返回播放页可实时预览',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
