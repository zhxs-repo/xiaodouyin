import 'package:flutter/material.dart';

class ColorPickerDialog extends StatefulWidget {
  final String initialColor;
  const ColorPickerDialog({super.key, required this.initialColor});

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    final hex = widget.initialColor.replaceAll('#', '');
    _selectedColor = hex.length == 6 ? Color(int.parse('FF$hex', radix: 16)) : Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('选择颜色'),
      content: Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          Colors.white, Colors.red, Colors.orange, Colors.yellow,
          Colors.green, Colors.cyan, Colors.blue, Colors.purple,
          Colors.pink, Colors.amber, Colors.lime, Colors.teal,
        ].map((c) => GestureDetector(
          onTap: () => setState(() => _selectedColor = c),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: c, shape: BoxShape.circle,
              border: _selectedColor == c ? Border.all(color: colorScheme.onSurface, width: 3) : null),
          ),
        )).toList(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: () {
          final hex = '#${(_selectedColor.r * 255.0).round().toRadixString(16).padLeft(2, '0')}${(_selectedColor.g * 255.0).round().toRadixString(16).padLeft(2, '0')}${(_selectedColor.b * 255.0).round().toRadixString(16).padLeft(2, '0')}';
          Navigator.pop(context, hex);
        }, child: const Text('确认')),
      ],
    );
  }
}
