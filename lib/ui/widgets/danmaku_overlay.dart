import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/danmaku_provider.dart';
import '../../core/constants/bullet_constants.dart';

class DanmakuOverlay extends StatelessWidget {
  const DanmakuOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DanmakuProvider>(
      builder: (context, dp, _) {
        if (!dp.isEnabled) return const SizedBox.shrink();
        return CustomPaint(
          painter: _DanmakuPainter(dp.activeBullets, dp.config),
          size: Size.infinite,
        );
      },
    );
  }
}

class _DanmakuPainter extends CustomPainter {
  final List<DanmakuItem> bullets;
  final DanmakuConfig config;
  static const int _maxCacheSize = 200;
  static final Map<String, TextPainter> _textPainterCache = {};

  _DanmakuPainter(this.bullets, this.config);

  @override
  void paint(Canvas canvas, Size size) {
    if (bullets.isEmpty) return;
    final now = DateTime.now();

    for (final bullet in bullets) {
      final elapsed = now.difference(bullet.startTime).inMilliseconds / 1000.0;
      final progress = elapsed / BulletConstants.speed;
      if (progress < 0 || progress > 1) continue;

      final rowHeight = size.height / config.rows;
      double x, y;
      switch (bullet.position) {
        case DanmakuPosition.scroll:
          x = size.width * (1 - progress);
          y = bullet.row * rowHeight + rowHeight / 2;
          break;
        case DanmakuPosition.top:
          x = (size.width - _measureWidth(bullet.text, bullet)) / 2;
          y = bullet.row * rowHeight + rowHeight / 2;
          break;
        case DanmakuPosition.bottom:
          x = (size.width - _measureWidth(bullet.text, bullet)) / 2;
          y = size.height - (bullet.row + 1) * rowHeight + rowHeight / 2;
          break;
      }

      final textPainter = _getOrCreateTextPainter(bullet);
      textPainter.paint(canvas, Offset(x, y - textPainter.height / 2));
    }
  }

  double _measureWidth(String text, DanmakuItem bullet) {
    final tp = _getOrCreateTextPainter(bullet);
    return tp.width;
  }

  TextPainter _getOrCreateTextPainter(DanmakuItem bullet) {
    final key = '${bullet.text}|${bullet.fontSize.toInt()}|${bullet.colorValue}';
    while (_textPainterCache.length > _maxCacheSize) {
      _textPainterCache.remove(_textPainterCache.keys.first);
    }
    final cached = _textPainterCache[key];
    if (cached != null) return cached;
    final textSpan = TextSpan(
      text: bullet.text,
      style: TextStyle(
        color: Color(bullet.colorValue).withValues(alpha: bullet.opacity),
        fontSize: bullet.fontSize,
        fontWeight: FontWeight.w500,
        shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    _textPainterCache[key] = tp;
    return tp;
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) {
    return bullets != oldDelegate.bullets || config != oldDelegate.config;
  }
}
