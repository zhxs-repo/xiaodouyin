import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ToastType { info, success, warning, error }

class ToastUtil {
  static final List<_ToastEntry> _queue = [];
  static const int maxVisible = 4;
  static const Duration displayDuration = Duration(milliseconds: 2400);
  static const Duration debounceDuration = Duration(milliseconds: 300);
  static String? _lastMessage;
  static DateTime? _lastShowTime;

  static void show(
    BuildContext context,
    String message, {
    VoidCallback? onWriteNotebook,
    ToastType type = ToastType.info,
  }) {
    final now = DateTime.now();
    if (_lastMessage == message && _lastShowTime != null &&
        now.difference(_lastShowTime!) < debounceDuration) {
      return;
    }
    _lastMessage = message;
    _lastShowTime = now;

    if (_queue.length >= maxVisible) {
      final oldest = _queue.removeAt(0);
      oldest.overlayEntry.remove();
    }

    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => _buildToastWidget(context, message, type),
    );

    final toastEntry = _ToastEntry(
      overlayEntry: entry,
      message: message,
      createdAt: now,
    );

    _queue.add(toastEntry);
    overlay.insert(entry);

    onWriteNotebook?.call();

    Future.delayed(displayDuration, () {
      if (_queue.contains(toastEntry)) {
        _queue.remove(toastEntry);
        entry.remove();
      }
    });
  }

  static Widget _buildToastWidget(BuildContext context, String message, ToastType type) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final accent = switch (type) {
      ToastType.success => Colors.green,
      ToastType.warning => Colors.orange,
      ToastType.error => colorScheme.error,
      ToastType.info => colorScheme.primary,
    };
    final icon = switch (type) {
      ToastType.success => Icons.check_circle_rounded,
      ToastType.warning => Icons.warning_rounded,
      ToastType.error => Icons.error_rounded,
      ToastType.info => Icons.info_rounded,
    };
    final index = _queue.length - 1;
    final bgColor = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : colorScheme.inverseSurface.withValues(alpha: 0.88);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : colorScheme.onInverseSurface.withValues(alpha: 0.08);
    final textColor = isDark ? Colors.white : colorScheme.onInverseSurface;

    return Positioned(
      top: 60.0 + (index * 56.0),
      left: 16.0,
      right: 16.0,
      child: IgnorePointer(
        child: AnimatedToastEntry(
          onDismiss: () {},
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    left: BorderSide(color: accent, width: 3),
                    top: BorderSide(color: borderColor, width: 0.5),
                    right: BorderSide(color: borderColor, width: 0.5),
                    bottom: BorderSide(color: borderColor, width: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: accent, size: 20),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedToastEntry extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  const AnimatedToastEntry({super.key, required this.child, required this.onDismiss});

  @override
  State<AnimatedToastEntry> createState() => _AnimatedToastEntryState();
}

class _AnimatedToastEntryState extends State<AnimatedToastEntry> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppTheme.durMedium);
    _offset = Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: AppTheme.curveEmphasized),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: AppTheme.curveEmphasized);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(opacity: _opacity, child: widget.child),
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
