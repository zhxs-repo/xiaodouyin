import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Material 3 风格页面过渡
class PageTransitions {
  /// Fade Through - M3 推荐用于不强调层级关系的页面切换
  /// 适合:列表→详情/弹窗→下级
  static PageRouteBuilder<T> fadeThrough<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: AppTheme.durMedium,
      reverseTransitionDuration: AppTheme.durFast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeIn = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.35, 1.0, curve: AppTheme.curveEmphasized),
        );
        final scaleOut = Tween<double>(begin: 1.0, end: 0.92).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.35, curve: AppTheme.curveEmphasized),
          ),
        );
        return FadeTransition(
          opacity: fadeIn,
          child: ScaleTransition(scale: scaleOut, child: child),
        );
      },
    );
  }

  /// Slide Up - 适合模态弹出 (设置/详情)
  static PageRouteBuilder<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: AppTheme.durMedium,
      reverseTransitionDuration: AppTheme.durFast,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero);
        return SlideTransition(
          position: animation.drive(tween.chain(CurveTween(curve: AppTheme.curveEmphasized))),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  /// Container Transform - 适合缩略图展开到详情
  static PageRouteBuilder<T> containerTransform<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: AppTheme.durSlow,
      reverseTransitionDuration: AppTheme.durMedium,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scale = Tween<double>(begin: 0.85, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: AppTheme.curveEmphasized),
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }
}
