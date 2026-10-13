import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/toast_util.dart';
import 'color_picker_dialog.dart';

/// 设置页通用控件（App 全局设置与视频设置共用一套）
class SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
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
}

class SettingsSegmented extends StatelessWidget {
  final String label;
  final String value;
  final List<(String, String, IconData)> options;
  final ValueChanged<String> onChanged;

  const SettingsSegmented({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
}

class SettingsSwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.label,
    this.subtitle,
    this.subtitleColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      subtitle: subtitle != null
          ? Text(subtitle!, style: TextStyle(color: subtitleColor, fontSize: 11))
          : null,
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

class SettingsSliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String valueText;
  final ValueChanged<double> onPreview;
  final ValueChanged<double> onConfirm;

  const SettingsSliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.valueText,
    required this.onPreview,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
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
}

class SettingsColorTile extends StatelessWidget {
  final String label;
  final String currentColor;
  final ValueChanged<String> onChanged;

  const SettingsColorTile({
    super.key,
    required this.label,
    required this.currentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
}

class SettingsNavTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const SettingsNavTile({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: enabled ? onTap : null,
    );
  }
}

class SettingsPasswordTile extends StatelessWidget {
  final String label;
  final String currentValue;
  final ValueChanged<String> onChanged;

  const SettingsPasswordTile({
    super.key,
    required this.label,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
}

class SettingsDirTile extends StatelessWidget {
  final String label;
  final String? currentPath;
  final ValueChanged<String> onSelected;
  final VoidCallback onReset;

  const SettingsDirTile({
    super.key,
    required this.label,
    required this.currentPath,
    required this.onSelected,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final displayPath = (currentPath != null && currentPath!.isNotEmpty) ? currentPath! : '默认目录';
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
          if (currentPath != null && currentPath!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              onPressed: onReset,
            ),
        ],
      ),
    );
  }
}
