import 'package:flutter/material.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onConfirm;

  const ConfirmDialog({super.key, required this.title, required this.message, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Text(message, style: TextStyle(color: colorScheme.onSurfaceVariant)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        TextButton(onPressed: () { Navigator.pop(context); onConfirm(); }, child: Text('确认', style: TextStyle(color: colorScheme.error))),
      ],
    );
  }
}
