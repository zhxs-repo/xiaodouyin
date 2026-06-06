import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 桌面端播放器快捷键回调
abstract class PlayerShortcutHandler {
  void togglePlayPause();
  void seek(Duration delta);
  void seekToFraction(double fraction);
  void setVolume(double volume);
  void toggleMute();
  void toggleFullscreen();
  void next();
  void previous();
  void exitFullscreen();
  void showUi();
}

/// 快捷键集合 - 桌面端用 Shortcuts/Actions 包裹播放器
class PlayerShortcuts {
  /// Space / k: 播放暂停
  static const togglePlayPause = SingleActivator(LogicalKeyboardKey.space);
  static const togglePlayPauseK = SingleActivator(LogicalKeyboardKey.keyK);

  /// ← / J: 后退 5s/10s
  static const seekBackward5 = SingleActivator(LogicalKeyboardKey.arrowLeft);
  static const seekBackward10 = SingleActivator(LogicalKeyboardKey.keyJ);

  /// → / L: 前进 5s/10s
  static const seekForward5 = SingleActivator(LogicalKeyboardKey.arrowRight);
  static const seekForward10 = SingleActivator(LogicalKeyboardKey.keyL);

  /// ↑: 音量 +5
  static const volumeUp = SingleActivator(LogicalKeyboardKey.arrowUp);
  /// ↓: 音量 -5
  static const volumeDown = SingleActivator(LogicalKeyboardKey.arrowDown);

  /// M: 静音切换
  static const toggleMute = SingleActivator(LogicalKeyboardKey.keyM);
  /// F: 全屏
  static const toggleFullscreen = SingleActivator(LogicalKeyboardKey.keyF);
  /// Esc: 退出全屏
  static const exitFullscreen = SingleActivator(LogicalKeyboardKey.escape);
  /// N: 下一个
  static const nextVideo = SingleActivator(LogicalKeyboardKey.keyN);
  /// P: 上一个
  static const previousVideo = SingleActivator(LogicalKeyboardKey.keyP);

  /// 0-9 跳转到时长百分比
  static final List<SingleActivator> jumpToFraction = List.generate(
    10,
    (i) => SingleActivator(_digitKey(i)),
  );

  static LogicalKeyboardKey _digitKey(int i) {
    switch (i) {
      case 0: return LogicalKeyboardKey.digit0;
      case 1: return LogicalKeyboardKey.digit1;
      case 2: return LogicalKeyboardKey.digit2;
      case 3: return LogicalKeyboardKey.digit3;
      case 4: return LogicalKeyboardKey.digit4;
      case 5: return LogicalKeyboardKey.digit5;
      case 6: return LogicalKeyboardKey.digit6;
      case 7: return LogicalKeyboardKey.digit7;
      case 8: return LogicalKeyboardKey.digit8;
      case 9: return LogicalKeyboardKey.digit9;
    }
    return LogicalKeyboardKey.digit0;
  }
}

/// 桌面端快捷键监听包装
/// 在播放页 build 顶层用 Shortcuts + Actions 包裹
class PlayerShortcutScope extends StatelessWidget {
  final PlayerShortcutHandler handler;
  final Widget child;
  final bool isFullscreen;
  final VoidCallback? onShowUi;

  const PlayerShortcutScope({
    super.key,
    required this.handler,
    required this.child,
    this.isFullscreen = false,
    this.onShowUi,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        PlayerShortcuts.togglePlayPause: const _TogglePlayPauseIntent(),
        PlayerShortcuts.togglePlayPauseK: const _TogglePlayPauseIntent(),
        PlayerShortcuts.seekBackward5: const _SeekIntent(Duration(seconds: -5)),
        PlayerShortcuts.seekBackward10: const _SeekIntent(Duration(seconds: -10)),
        PlayerShortcuts.seekForward5: const _SeekIntent(Duration(seconds: 5)),
        PlayerShortcuts.seekForward10: const _SeekIntent(Duration(seconds: 10)),
        PlayerShortcuts.volumeUp: const _VolumeIntent(5),
        PlayerShortcuts.volumeDown: const _VolumeIntent(-5),
        PlayerShortcuts.toggleMute: const _ToggleMuteIntent(),
        PlayerShortcuts.toggleFullscreen: const _ToggleFullscreenIntent(),
        PlayerShortcuts.nextVideo: const _NextIntent(),
        PlayerShortcuts.previousVideo: const _PreviousIntent(),
        for (var i = 0; i < 10; i++)
          PlayerShortcuts.jumpToFraction[i]: _JumpToFractionIntent(i / 10.0),
        if (isFullscreen)
          PlayerShortcuts.exitFullscreen: const _ExitFullscreenIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TogglePlayPauseIntent: CallbackAction<_TogglePlayPauseIntent>(onInvoke: (_) {
            handler.togglePlayPause();
            onShowUi?.call();
            return null;
          }),
          _SeekIntent: CallbackAction<_SeekIntent>(onInvoke: (intent) {
            handler.seek(intent.delta);
            onShowUi?.call();
            return null;
          }),
          _VolumeIntent: CallbackAction<_VolumeIntent>(onInvoke: (intent) {
            handler.setVolume(intent.delta);
            onShowUi?.call();
            return null;
          }),
          _ToggleMuteIntent: CallbackAction<_ToggleMuteIntent>(onInvoke: (_) {
            handler.toggleMute();
            onShowUi?.call();
            return null;
          }),
          _ToggleFullscreenIntent: CallbackAction<_ToggleFullscreenIntent>(onInvoke: (_) {
            handler.toggleFullscreen();
            return null;
          }),
          _NextIntent: CallbackAction<_NextIntent>(onInvoke: (_) {
            handler.next();
            return null;
          }),
          _PreviousIntent: CallbackAction<_PreviousIntent>(onInvoke: (_) {
            handler.previous();
            return null;
          }),
          _JumpToFractionIntent: CallbackAction<_JumpToFractionIntent>(onInvoke: (intent) {
            handler.seekToFraction(intent.fraction);
            onShowUi?.call();
            return null;
          }),
          _ExitFullscreenIntent: CallbackAction<_ExitFullscreenIntent>(onInvoke: (_) {
            handler.exitFullscreen();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

// ==================== Intents ====================

class _TogglePlayPauseIntent extends Intent {
  const _TogglePlayPauseIntent();
}

class _SeekIntent extends Intent {
  final Duration delta;
  const _SeekIntent(this.delta);
}

class _VolumeIntent extends Intent {
  final double delta;
  const _VolumeIntent(this.delta);
}

class _ToggleMuteIntent extends Intent {
  const _ToggleMuteIntent();
}

class _ToggleFullscreenIntent extends Intent {
  const _ToggleFullscreenIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _PreviousIntent extends Intent {
  const _PreviousIntent();
}

class _JumpToFractionIntent extends Intent {
  final double fraction;
  const _JumpToFractionIntent(this.fraction);
}

class _ExitFullscreenIntent extends Intent {
  const _ExitFullscreenIntent();
}
