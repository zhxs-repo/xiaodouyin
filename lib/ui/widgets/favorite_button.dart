import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favorite_provider.dart';
import '../../core/theme/app_theme.dart';

class FavoriteButton extends StatelessWidget {
  final String videoPath;
  final int index;

  const FavoriteButton({super.key, required this.videoPath, required this.index});

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoriteProvider>(
      builder: (context, fp, _) {
        final isFav = fp.isFavorite(videoPath);
        return _HeartbeatIconButton(
          isActive: isFav,
          onPressed: () => fp.toggleFavorite(videoPath, index),
        );
      },
    );
  }
}

class _HeartbeatIconButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onPressed;

  const _HeartbeatIconButton({required this.isActive, required this.onPressed});

  @override
  State<_HeartbeatIconButton> createState() => _HeartbeatIconButtonState();
}

class _HeartbeatIconButtonState extends State<_HeartbeatIconButton> with SingleTickerProviderStateMixin {
  late final AnimationController _heartbeat;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _heartbeat = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.95).chain(CurveTween(curve: Curves.easeIn)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    ]).animate(_heartbeat);
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_heartbeat);
  }

  @override
  void dispose() {
    _heartbeat.dispose();
    super.dispose();
  }

  void _onTap() {
    _heartbeat.forward(from: 0.0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: GlassContainer(
          decoration: GlassDecoration.subtle.copyWith(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          padding: const EdgeInsets.all(10),
          child: AnimatedBuilder(
            animation: _heartbeat,
            builder: (context, child) {
              return Transform.scale(
                scale: _scale.value,
                child: Opacity(opacity: _fade.value, child: child),
              );
            },
            child: AnimatedSwitcher(
              duration: AppTheme.durFast,
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
              child: Icon(
                widget.isActive ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                key: ValueKey(widget.isActive),
                color: widget.isActive ? Colors.redAccent : (isDark ? Colors.white : colorScheme.onSurface),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
