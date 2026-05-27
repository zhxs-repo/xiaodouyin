import 'package:flutter/material.dart';

class ToastUtil {
  static final List<_ToastEntry> _queue = [];
  static const int maxVisible = 5;
  static const Duration displayDuration = Duration(seconds: 3);
  static const Duration debounceDuration = Duration(milliseconds: 300);
  static String? _lastMessage;
  static DateTime? _lastShowTime;
  
  static void show(BuildContext context, String message, {VoidCallback? onWriteNotebook}) {
    // 防抖检查
    final now = DateTime.now();
    if (_lastMessage == message && _lastShowTime != null &&
        now.difference(_lastShowTime!) < debounceDuration) {
      return;
    }
    _lastMessage = message;
    _lastShowTime = now;
    
    // 队列管理
    if (_queue.length >= maxVisible) {
      final oldest = _queue.removeAt(0);
      oldest.overlayEntry.remove();
    }
    
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _buildToastWidget(context, message),
    );
    
    final toastEntry = _ToastEntry(
      overlayEntry: entry,
      message: message,
      createdAt: now,
    );
    
    _queue.add(toastEntry);
    overlay.insert(entry);
    
    // 写入笔记本
    onWriteNotebook?.call();
    
    // 自动消失
    Future.delayed(displayDuration, () {
      if (_queue.contains(toastEntry)) {
        _queue.remove(toastEntry);
        entry.remove();
      }
    });
  }
  
  static Widget _buildToastWidget(BuildContext context, String message) {
    final index = _queue.length - 1;
    return Positioned(
      top: 80.0 + (index * 50.0),
      left: 20.0,
      right: 20.0,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _ToastEntry {
  final OverlayEntry overlayEntry;
  final String message;
  final DateTime createdAt;
  
  _ToastEntry({
    required this.overlayEntry,
    required this.message,
    required this.createdAt,
  });
}
