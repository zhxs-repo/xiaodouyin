import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/danmaku_provider.dart';
import '../../core/theme/app_theme.dart';

/// 弹幕设置底部弹窗
class DanmakuSettingsSheet extends StatefulWidget {
  const DanmakuSettingsSheet({super.key});

  @override
  State<DanmakuSettingsSheet> createState() => _DanmakuSettingsSheetState();
}

class _DanmakuSettingsSheetState extends State<DanmakuSettingsSheet> {
  final _blocklistController = TextEditingController();
  static const _presetColors = <int>[
    0xFFFFFFFF, // 白
    0xFFFF4444, // 红
    0xFF2196F3, // 蓝
    0xFF4CAF50, // 绿
    0xFFFFEB3B, // 黄
    0xFFFF80AB, // 粉
  ];

  @override
  void initState() {
    super.initState();
    final cfg = context.read<DanmakuProvider>().config;
    _blocklistController.text = cfg.blocklist.join(',');
  }

  @override
  void dispose() {
    _blocklistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<DanmakuProvider>(
      builder: (context, dp, _) {
        final cfg = dp.config;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('弹幕设置', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Switch(
                      value: dp.isEnabled,
                      onChanged: (_) => dp.toggle(),
                    ),
                    Text(dp.isEnabled ? '开' : '关', style: Theme.of(context).textTheme.labelLarge),
                  ],
                ),
                const SizedBox(height: 20),
                _SectionLabel('颜色'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: _presetColors.map((c) => GestureDetector(
                    onTap: () => dp.updateConfig(cfg.copyWith(colorValue: c)),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cfg.colorValue == c ? colorScheme.primary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
                const SizedBox(height: 20),
                _SectionLabel('字号'),
                const SizedBox(height: 4),
                _SegmentRow<DanmakuSize>(
                  value: cfg.size,
                  options: DanmakuSize.values,
                  labelOf: (s) => switch (s) {
                    DanmakuSize.small => '小',
                    DanmakuSize.medium => '中',
                    DanmakuSize.large => '大',
                  },
                  onChanged: (v) => dp.updateConfig(cfg.copyWith(size: v)),
                ),
                const SizedBox(height: 20),
                _SectionLabel('位置'),
                const SizedBox(height: 4),
                _SegmentRow<DanmakuPosition>(
                  value: cfg.position,
                  options: DanmakuPosition.values,
                  labelOf: (p) => switch (p) {
                    DanmakuPosition.scroll => '滚动',
                    DanmakuPosition.top => '顶部',
                    DanmakuPosition.bottom => '底部',
                  },
                  onChanged: (v) => dp.updateConfig(cfg.copyWith(position: v)),
                ),
                const SizedBox(height: 20),
                _SectionLabel('透明度'),
                Slider(
                  value: cfg.opacity,
                  min: 0.2, max: 1.0,
                  onChanged: (v) => dp.updateConfig(cfg.copyWith(opacity: v)),
                ),
                const SizedBox(height: 20),
                _SectionLabel('密度'),
                const SizedBox(height: 4),
                _SegmentRow<DanmakuDensity>(
                  value: cfg.density,
                  options: DanmakuDensity.values,
                  labelOf: (d) => switch (d) {
                    DanmakuDensity.low => '稀疏',
                    DanmakuDensity.medium => '正常',
                    DanmakuDensity.high => '密集',
                  },
                  onChanged: (v) => dp.updateConfig(cfg.copyWith(density: v)),
                ),
                const SizedBox(height: 20),
                _SectionLabel('屏蔽词 (逗号分隔)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _blocklistController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '例如: 广告, 链接',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusS),
                    ),
                  ),
                  onSubmitted: (v) {
                    final words = v.split(RegExp(r'[,，]')).map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
                    dp.updateConfig(cfg.copyWith(blocklist: words));
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Spacer(),
                    FilledButton(
                      onPressed: () {
                        final words = _blocklistController.text
                          .split(RegExp(r'[,，]'))
                          .map((w) => w.trim())
                          .where((w) => w.isNotEmpty)
                          .toList();
                        dp.updateConfig(cfg.copyWith(blocklist: words));
                        Navigator.pop(context);
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}

class _SegmentRow<T> extends StatelessWidget {
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _SegmentRow({
    required this.value,
    required this.options,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SegmentedButton<T>(
      segments: options.map((o) => ButtonSegment<T>(
        value: o,
        label: Text(labelOf(o), style: const TextStyle(fontSize: 13)),
      )).toList(),
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        side: WidgetStateProperty.all(BorderSide(color: colorScheme.outlineVariant)),
      ),
    );
  }
}
