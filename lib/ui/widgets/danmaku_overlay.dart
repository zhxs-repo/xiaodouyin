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
        if (!dp.isEnabled) return const SizedBox();
        return CustomPaint(
          painter: _DanmakuPainter(dp.activeBullets),
          size: Size.infinite,
        );
      },
    );
  }
}

class _DanmakuPainter extends CustomPainter {
  final List<DanmakuItem> bullets;
  static const int _maxCacheSize = 100;
  static final Map<String, TextPainter> _textPainterCache = {};

  _DanmakuPainter(this.bullets);

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now();
    final rowHeight = size.height / BulletConstants.rows;

    for (final bullet in bullets) {
      final elapsed = now.difference(bullet.startTime).inMilliseconds / 1000.0;
      final progress = elapsed / BulletConstants.speed;
      if (progress < 0 || progress > 1) continue;

      final x = size.width * (1 - progress);
      final y = bullet.row * rowHeight + rowHeight / 2;

      final textPainter = _getOrCreateTextPainter(bullet.text);
      textPainter.paint(canvas, Offset(x, y - textPainter.height / 2));
    }
  }

  TextPainter _getOrCreateTextPainter(String text) {
    // 清理超限缓存
    while (_textPainterCache.length > _maxCacheSize) {
      _textPainterCache.remove(_textPainterCache.keys.first);
    }
    if (_textPainterCache.containsKey(text)) {
      return _textPainterCache[text]!;
    }
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: Colors.white,
        fontSize: BulletConstants.fontSize * 0.5,
        shadows: const [Shadow(blurRadius: 2, color: Colors.black87)],
      ),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    _textPainterCache[text] = textPainter;
    return textPainter;
  }

  @override
  bool shouldRepaint(covariant _DanmakuPainter oldDelegate) {
    return bullets != oldDelegate.bullets;
  }
}
