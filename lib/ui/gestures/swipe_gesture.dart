import 'package:flutter/material.dart';

enum SwipeDirection { up, down, left, right }

class SwipeGesture extends StatelessWidget {
  final Widget child;
  final void Function(SwipeDirection)? onSwipe;

  const SwipeGesture({super.key, required this.child, this.onSwipe});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -300) onSwipe?.call(SwipeDirection.up);
        if (v > 300) onSwipe?.call(SwipeDirection.down);
      },
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -300) onSwipe?.call(SwipeDirection.left);
        if (v > 300) onSwipe?.call(SwipeDirection.right);
      },
      child: child,
    );
  }
}
