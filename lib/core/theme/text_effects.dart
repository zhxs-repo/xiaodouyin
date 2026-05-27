import 'package:flutter/material.dart';
import '../../data/models/app_config.dart';

class TextEffects {
  static Widget build({
    required String text,
    required TextEffectType effectType,
    required String textColor,
    required double fontSize,
    AnimationController? colorfulController,
  }) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );

    switch (effectType) {
      case TextEffectType.solid:
        return Text(
          text,
          style: baseStyle.copyWith(color: _parseColor(textColor)),
        );

      case TextEffectType.gradient:
        return ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              Colors.red, Colors.orange, Colors.yellow,
              Colors.green, Colors.blue, Colors.purple,
              Colors.red,
            ],
          ).createShader(bounds),
          child: Text(text, style: baseStyle.copyWith(color: Colors.white)),
        );

      case TextEffectType.colorful:
        if (colorfulController != null) {
          return AnimatedBuilder(
            animation: colorfulController,
            builder: (context, child) {
              final hue = (colorfulController.value * 360) % 360;
              return ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    HSLColor.fromAHSL(1, hue, 1, 0.5).toColor(),
                    HSLColor.fromAHSL(1, (hue + 120) % 360, 1, 0.5).toColor(),
                    HSLColor.fromAHSL(1, (hue + 240) % 360, 1, 0.5).toColor(),
                  ],
                ).createShader(bounds),
                child: Text(text, style: baseStyle.copyWith(color: Colors.white)),
              );
            },
          );
        }
        return Text(text, style: baseStyle.copyWith(color: _parseColor(textColor)));
    }
  }

  static Color _parseColor(String hex) {
    final hexStr = hex.replaceAll('#', '');
    if (hexStr.length == 6) {
      return Color(int.parse('FF$hexStr', radix: 16));
    }
    return Colors.white;
  }
}
