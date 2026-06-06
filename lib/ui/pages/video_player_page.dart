import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import '../../core/utils/path_utils.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/theme/app_theme.dart';
import '../gestures/desktop_shortcuts.dart';
import '../widgets/modern_progress_bar.dart' as modern;
import '../widgets/danmaku_settings_sheet.dart';
import '../../providers/video_player_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/danmaku_provider.dart';
import '../../providers/timer_provider.dart';
import '../../providers/resume_provider.dart';
import '../../providers/device_provider.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/file_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/models/video_item.dart';
import '../../data/models/app_config.dart';
import '../../core/utils/toast_util.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/storage_keys.dart';
import '../widgets/danmaku_overlay.dart';
import '../widgets/favorite_button.dart';
import '../widgets/real_time_counter.dart';
import '../widgets/timer_display.dart';
import '../widgets/progress_bar.dart' as custom;
import '../widgets/playback_gesture_detector.dart';
import 'video_list_page.dart';
import 'notebook_page.dart';
import 'settings_page.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with WidgetsBindingObserver, WindowListener implements PlayerShortcutHandler {
  // --- LRU 播放器缓存 ---
  static const int _maxCacheSize = 3;
  final Map<int, _VideoPlayerEntry> _playerCache = {};
  final List<int> _accessOrder = [];
  final Set<int> _disposingPlayers = {};

  // --- 控制器 ---
  final PreloadPageController _pageController = PreloadPageController();

  // --- 状态 ---
  int _currentPageIndex = 0;
  bool _isPlaying = true;
  bool _isAppActive = true;
  int _rotationState = 0; // 0=正常, 1=横屏1.8x, 2=横屏2.24x
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _completedSubscription;
  late final ResumeProvider _resumeProvider;

  // --- 双击红心动画 ---
  final List<_LikeAnimation> _likeAnimations = [];
  int _likeAnimationIdCounter = 0;

  // --- UI自动隐藏 ---
  bool _isUiVisible = true;
  Timer? _uiHideTimer;
  bool _isMenuOpen = false; // PopupMenu 打开期间暂停 UI 自动隐藏
  // 鼠标位置 (用于桌面端检测)
  Offset? _lastMousePos;

  // --- 长视频模式 ---
  // _isLongVideoMode: 当前 UI 显示状态
  // _longVideoOverride: 用户手动选择 (true=强制开, false=强制关, null=自动检测)
  //                      持久化到 SharedPreferences,关闭 App 后保留
  bool _isLongVideoMode = false;
  bool? _longVideoOverride;
  static const Duration _longVideoThreshold = Duration(minutes: 5);

  // --- 音量 (桌面端) ---
  double _volume = 100;
  double _lastNonZeroVolume = 100;
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _resumeProvider = context.read<ResumeProvider>();
    WidgetsBinding.instance.addObserver(this);
    if (PlatformUtils.isDesktop) {
      windowManager.addListener(this);
    }
    _loadVideos();
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted && !_isFullscreen) {
      setState(() => _isFullscreen = true);
    }
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted && _isFullscreen) {
      setState(() => _isFullscreen = false);
      // 恢复原窗口尺寸 (用户按 Esc 退出全屏时)
      if (_preFullscreenSize != null) {
        windowManager.setSize(_preFullscreenSize!);
        if (_preFullscreenPosition != null) {
          windowManager.setPosition(_preFullscreenPosition!);
        }
      }
    }
  }

  /// 异步加载用户长视频模式偏好 (在 _loadVideos 开头调用,确保首屏渲染前完成)
  Future<void> _loadLongVideoOverrideAsync() async {
    final storage = await StorageService.getInstance();
    if (!storage.containsKey(StorageKeys.longVideoModeOverride)) {
      _longVideoOverride = null;
      return;
    }
    _longVideoOverride = storage.getBool(StorageKeys.longVideoModeOverride);
  }

  /// 保存用户长视频模式偏好
  Future<void> _saveLongVideoOverride(bool value) async {
    _longVideoOverride = value;
    final storage = await StorageService.getInstance();
    await storage.setBool(StorageKeys.longVideoModeOverride, value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (PlatformUtils.isDesktop) {
      windowManager.removeListener(this);
    }
    _playingSubscription?.cancel();
    _completedSubscription?.cancel();
    _uiHideTimer?.cancel();
    _pageController.dispose();
    _disposeAllPlayers();
    _resumeProvider.stopAutoSave();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasActive = _isAppActive;
    _isAppActive = state == AppLifecycleState.resumed;

    if (!_isAppActive && wasActive) {
      _pauseAllPlayers();
    } else if (_isAppActive && !wasActive) {
      _playPlayer(_currentPageIndex);
    }
  }

  // ==================== 视频加载 ====================

  Future<void> _loadVideos() async {
    // 先加载长视频模式用户偏好,避免首屏闪烁
    await _loadLongVideoOverrideAsync();
    if (!mounted) return;
    final config = context.read<ConfigProvider>().config;
    final fileService = FileService(customVideoDir: config.customVideoDir);
    final videoRepo = VideoRepository(fileService);
    final videos = await videoRepo.loadVideos();
    if (!mounted) return;
    final provider = context.read<VideoPlayerProvider>();
    if (videos.isNotEmpty) {
      provider.setVideoList(videos);
      // 初始化第一个视频的播放器
      await _initAndPlayVideo(0, videos[0].path);
    } else {
      // 确保清空空列表状态
      provider.setVideoList([]);
    }
  }

  // ==================== 播放器管理 ====================

  _VideoPlayerEntry? _getOrCreatePlayer(int index, String path) {
    if (_playerCache.containsKey(index)) {
      _touchPlayer(index);
      return _playerCache[index]!;
    }

    try {
      final player = Player(configuration: const PlayerConfiguration());
      final controller = VideoController(player);
      _playerCache[index] = _VideoPlayerEntry(player, controller);
      _touchPlayer(index);
      player.open(Media(path));
      // 关键：open后立即暂停，防止预加载页自动播放产生多音频
      player.pause();
      // 加载字幕：同目录同名字幕 + 内封字幕
      _loadSubtitles(player, path);
      _enforceCacheLimit();
      return _playerCache[index]!;
    } catch (e) {
      return null;
    }
  }

  /// 加载字幕：1) 同目录同名字幕文件  2) 内封字幕自动选择
  Future<void> _loadSubtitles(Player player, String videoPath) async {
    // 1. 查找同目录同名字幕文件（.srt, .ass, .vtt, .ssa, .sub）
    final videoFile = File(videoPath);
    final videoDir = videoFile.parent.path;
    final baseName = p.basenameWithoutExtension(videoFile.path);
    const subtitleExts = ['.srt', '.ass', '.ssa', '.vtt', '.sub'];

    for (final ext in subtitleExts) {
      final subtitlePath = p.join(videoDir, '$baseName$ext');
      final subtitleFile = File(subtitlePath);
      if (await subtitleFile.exists()) {
        player.setSubtitleTrack(SubtitleTrack.uri(subtitlePath));
        return; // 找到第一个就使用
      }
    }

    // 2. 没有外挂字幕时，尝试选择内封字幕的第一个轨道
    // media_kit的libmpv后端会自动检测内封字幕轨道
    // 等待播放器就绪后检查可用轨道（5秒超时保护）
    try {
      await player.stream.playing.firstWhere((p) => p).timeout(const Duration(seconds: 5));
    } catch (_) { return; }
    if (!mounted) return;
    final tracks = player.state.tracks.subtitle;
    // 排除 'auto' 和 'no' 这两个特殊轨道，找真实的内封字幕
    final realTracks = tracks.where((t) => t.id != 'auto' && t.id != 'no').toList();
    if (realTracks.isNotEmpty) {
      // 优先选择 isDefault == true 的轨道，否则选第一个
      final defaultTrack = realTracks.firstWhere(
        (t) => t.isDefault == true,
        orElse: () => realTracks.first,
      );
      player.setSubtitleTrack(defaultTrack);
    }
  }

  void _touchPlayer(int index) {
    _accessOrder
      ..remove(index)
      ..add(index);
  }

  void _enforceCacheLimit() {
    while (_playerCache.length > _maxCacheSize && _accessOrder.isNotEmpty) {
      final oldestIndex = _accessOrder.first;
      _removePlayer(oldestIndex);
    }
  }

  Future<void> _managePlayerWindow(int currentPage, List<String> pathList) async {
    final windowStart = (currentPage - 1).clamp(0, pathList.length - 1);
    final windowEnd = (currentPage + 1).clamp(0, pathList.length - 1);

    final indicesToRemove = _playerCache.keys
        .where((i) => i < windowStart || i > windowEnd)
        .toList();
    for (final i in indicesToRemove) {
      _removePlayer(i);
    }

    if (currentPage < pathList.length) {
      _getOrCreatePlayer(currentPage, pathList[currentPage]);
      if (windowStart < currentPage) {
        _getOrCreatePlayer(windowStart, pathList[windowStart]);
      }
      if (windowEnd > currentPage) {
        _getOrCreatePlayer(windowEnd, pathList[windowEnd]);
      }
    }
  }

  void _removePlayer(int index) {
    if (_disposingPlayers.contains(index)) return;
    _disposingPlayers.add(index);

    try {
      final entry = _playerCache.remove(index);
      _accessOrder.remove(index);
      if (entry != null) {
        try { entry.player.pause(); } catch (_) {}
        entry.player.dispose();
      }
    } finally {
      _disposingPlayers.remove(index);
    }
  }

  void _disposeAllPlayers() {
    for (final entry in _playerCache.values) {
      try { entry.player.dispose(); } catch (_) {}
    }
    _playerCache.clear();
    _accessOrder.clear();
    _disposingPlayers.clear();
  }

  void _pauseAllPlayers() {
    for (final entry in _playerCache.values) {
      try { entry.player.pause(); } catch (_) {}
    }
  }

  void _playPlayer(int index) {
    final entry = _playerCache[index];
    if (entry != null) {
      try {
        entry.player.play();
        // 监听当前player的播放状态流，同步_isPlaying
        _playingSubscription?.cancel();
        _playingSubscription = entry.player.stream.playing.listen((playing) {
          if (mounted && _isPlaying != playing) {
            _isPlaying = playing;
            setState(() {});
          }
        });
        // 监听视频结束事件，根据 PlayMode 决定行为
        _completedSubscription?.cancel();
        _completedSubscription = entry.player.stream.completed.listen((completed) {
          if (!mounted || !completed) return;
          _handleVideoCompleted(entry.player);
        });
      } catch (_) {}
      // 应用音量
      entry.player.setVolume(_volume);
    }
    // 异步检测长视频模式
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _checkLongVideoMode();
    });
  }

  /// 处理视频结束事件 (根据 PlayMode 决定)
  void _handleVideoCompleted(Player player) {
    if (!mounted) return;
    final config = context.read<ConfigProvider>().config;
    final vp = context.read<VideoPlayerProvider>();
    switch (config.playMode) {
      case PlayMode.loopOne:
        // 单视频循环: 跳到开头继续播放
        player.seek(Duration.zero);
        player.play();
        break;
      case PlayMode.loop:
        // 列表循环: 跳到下一个,末尾时回到开头
        if (vp.displayList.isEmpty) return;
        final nextIndex = (_currentPageIndex + 1) % vp.displayList.length;
        _pageController.jumpToPage(nextIndex);
        break;
      case PlayMode.normal:
        // 播完即停: 暂停,显示重播按钮
        player.pause();
        setState(() => _isPlaying = false);
        ToastUtil.show(context, '播放完成');
        break;
    }
  }

  Future<void> _initAndPlayVideo(int index, String path) async {
    _getOrCreatePlayer(index, path);
    _playPlayer(index);
    // 续播：获取上次播放位置并跳转
    final resumePos = context.read<ResumeProvider>().getResumePosition(path);
    if (resumePos != null && resumePos.inSeconds > 0) {
      final entry = _playerCache[index];
      if (entry != null) {
        // 等待播放器实际开始播放后再跳转（5秒超时保护）
        final sub = entry.player.stream.playing.firstWhere((p) => p)
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
        sub.then((playing) {
          if (mounted && playing) entry.player.seek(resumePos);
        });
      }
    }
    // 启动自动保存播放进度
    final entry = _playerCache[index];
    if (entry != null) {
      context.read<ResumeProvider>().startAutoSave(
        path,
        () => entry.player.state.position,
        () => entry.player.state.duration,
      );
    }
  }

  // ==================== 页面切换 ====================

  Future<void> _onPageChanged(int newIndex) async {
    final vp = context.read<VideoPlayerProvider>();
    if (vp.displayList.isEmpty || newIndex >= vp.displayList.length) return;
    if (newIndex == _currentPageIndex) return;

    final previousIndex = _currentPageIndex;
    _currentPageIndex = newIndex;

    final isFastScroll = (newIndex - previousIndex).abs() > 1;

    // 1. 暂停所有视频（确保只有一个音频在播放）
    _pauseAllPlayers();

    // 2. 快速滑动：激进销毁非目标页播放器
    if (isFastScroll) {
      final indicesToRemove = _playerCache.keys
          .where((i) => i != newIndex)
          .toList();
      for (final i in indicesToRemove) {
        _removePlayer(i);
      }
    }

    // 3. 管理滑动窗口（预加载页创建后处于暂停状态）
    final pathList = vp.displayPathList;
    await _managePlayerWindow(newIndex, pathList);
    if (!mounted) return;

    // 4. 仅播放当前视频（预加载页保持暂停）
    _playPlayer(newIndex);

    // 5. 通知 provider 更新当前索引（仅更新索引，不操作player避免双重播放）
    vp.updateCurrentIndex(newIndex);

    // 6. 更新续播自动保存目标
    if (newIndex < vp.displayList.length) {
      final newEntry = _playerCache[newIndex];
      if (newEntry != null) {
        context.read<ResumeProvider>().startAutoSave(
          vp.displayList[newIndex].path,
          () => newEntry.player.state.position,
          () => newEntry.player.state.duration,
        );
      }
    }

    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    final entry = _playerCache[_currentPageIndex];
    if (entry != null) {
      entry.player.playOrPause();
      // _isPlaying 由 player.stream.playing 监听自动同步，无需手动设置
    }
  }

  /// 单击：UI可见时切换播放/暂停，UI隐藏时恢复显示UI
  void _onSingleTap() {
    if (_isUiVisible) {
      _togglePlayPause();
      _resetUiHideTimer();
    } else {
      _showUi();
    }
  }

  /// 显示UI并启动自动隐藏计时器
  void _showUi() {
    setState(() => _isUiVisible = true);
    _resetUiHideTimer();
  }

  /// 重置UI自动隐藏计时器（3秒后隐藏）
  void _resetUiHideTimer() {
    // PopupMenu 打开期间不重置,避免菜单还没选完就自动隐藏
    if (_isMenuOpen) return;
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying && !_isMenuOpen) {
        setState(() => _isUiVisible = false);
      }
    });
  }

  /// 鼠标移动回调 (桌面端)
  void _onMouseMove(PointerHoverEvent e) {
    if (_lastMousePos == e.position) return;
    _lastMousePos = e.position;
    if (!_isUiVisible) {
      setState(() => _isUiVisible = true);
    }
    _resetUiHideTimer();
  }

  /// 标记 PopupMenu 打开 (在鼠标移动回调里暂停计时器)
  void _onMenuOpen() {
    _isMenuOpen = true;
    _uiHideTimer?.cancel();
  }

  /// 标记 PopupMenu 关闭
  void _onMenuClose() {
    _isMenuOpen = false;
    _resetUiHideTimer();
  }

  /// 检测当前视频是否为长视频 (duration >= 5 min)
  /// 如果用户已手动设置覆盖 (_longVideoOverride != null),以用户选择为准
  void _checkLongVideoMode() {
    final entry = _playerCache[_currentPageIndex];
    if (entry == null) return;
    final duration = entry.player.state.duration;
    final width = entry.player.state.width ?? 0;
    final height = entry.player.state.height ?? 0;
    final isWideAspect = width > 0 && height > 0 && (width / height) > 1.0;
    final autoDetected = duration >= _longVideoThreshold || isWideAspect;
    // 优先使用用户手动选择,否则使用自动检测
    final target = _longVideoOverride ?? autoDetected;
    if (target != _isLongVideoMode && mounted) {
      setState(() => _isLongVideoMode = target);
    }
  }

  // ==================== PlayerShortcutHandler 实现 ====================

  @override
  void togglePlayPause() => _togglePlayPause();

  @override
  void seek(Duration delta) {
    final entry = _playerCache[_currentPageIndex];
    if (entry == null) return;
    final cur = entry.player.state.position;
    final dur = entry.player.state.duration;
    final target = cur + delta;
    final clamped = target < Duration.zero
      ? Duration.zero
      : (target > dur ? dur : target);
    entry.player.seek(clamped);
  }

  @override
  void seekToFraction(double fraction) {
    final entry = _playerCache[_currentPageIndex];
    if (entry == null) return;
    final dur = entry.player.state.duration;
    entry.player.seek(Duration(milliseconds: (fraction * dur.inMilliseconds).round()));
  }

  @override
  void setVolume(double delta) {
    setState(() {
      _volume = (_volume + delta).clamp(0.0, 100.0);
      if (_volume > 0) _lastNonZeroVolume = _volume;
    });
    final entry = _playerCache[_currentPageIndex];
    entry?.player.setVolume(_volume);
  }

  @override
  void toggleMute() {
    setState(() {
      if (_volume > 0) {
        _lastNonZeroVolume = _volume;
        _volume = 0;
      } else {
        _volume = _lastNonZeroVolume;
      }
    });
    final entry = _playerCache[_currentPageIndex];
    entry?.player.setVolume(_volume);
  }

  // --- 桌面端窗口尺寸记忆 ---
  Size? _preFullscreenSize;
  Offset? _preFullscreenPosition;

  @override
  void toggleFullscreen() async {
    final newValue = !_isFullscreen;
    setState(() => _isFullscreen = newValue);
    if (PlatformUtils.isDesktop) {
      if (newValue) {
        // 进入全屏: 保存当前窗口尺寸/位置
        _preFullscreenSize = await windowManager.getSize();
        _preFullscreenPosition = await windowManager.getPosition();
      }
      await windowManager.setFullScreen(newValue);
      if (!newValue) {
        // 退出全屏: 恢复原窗口尺寸
        if (_preFullscreenSize != null) {
          await windowManager.setSize(_preFullscreenSize!);
          if (_preFullscreenPosition != null) {
            await windowManager.setPosition(_preFullscreenPosition!);
          }
        }
      }
    }
  }

  @override
  void exitFullscreen() async {
    if (_isFullscreen) {
      setState(() => _isFullscreen = false);
      if (PlatformUtils.isDesktop) {
        await windowManager.setFullScreen(false);
        // 恢复原窗口尺寸
        if (_preFullscreenSize != null) {
          await windowManager.setSize(_preFullscreenSize!);
          if (_preFullscreenPosition != null) {
            await windowManager.setPosition(_preFullscreenPosition!);
          }
        }
      }
    }
  }

  @override
  void next() {
    final vp = context.read<VideoPlayerProvider>();
    if (_currentPageIndex < vp.displayList.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  void previous() {
    if (_currentPageIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  void showUi() => _showUi();

  /// 双击点赞：如果已收藏只触发动画，如果未收藏则收藏+动画
  void _onDoubleTapLike() {
    final vp = context.read<VideoPlayerProvider>();
    final currentPath = vp.currentVideo?.path;
    if (currentPath != null) {
      final fp = context.read<FavoriteProvider>();
      if (!fp.isFavorite(currentPath)) {
        fp.toggleFavorite(currentPath, vp.currentIndex);
      }
    }
    // 触发红心动画 (随机横向偏移 ±16)
    final id = _likeAnimationIdCounter++;
    final randX = (id * 37) % 33 - 16;
    setState(() {
      _likeAnimations.add(_LikeAnimation(id: id, randomOffsetX: randX));
    });
    // 1秒后移除动画
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() {
          _likeAnimations.removeWhere((a) => a.id == id);
        });
      }
    });
  }

  // ==================== UI 构建 ====================

  /// 饱和度滤镜：saturation=100为正常，0为灰度，200为超饱和
  Widget _buildVideoWithSaturation(Widget videoWidget, double saturation) {
    if (saturation == 100) return videoWidget;
    final s = saturation / 100;
    final r = 0.2126 * (1 - s);
    final g = 0.7152 * (1 - s);
    final b = 0.0722 * (1 - s);
    return ColorFiltered(
      colorFilter: ColorFilter.matrix(<double>[
        r + s,  g,      b,      0, 0,
        r,      g + s,  b,      0, 0,
        r,      g,      b + s,  0, 0,
        0,      0,      0,      1, 0,
      ]),
      child: videoWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body = Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<VideoPlayerProvider>(
        builder: (context, vp, _) {
          if (vp.displayList.isEmpty) {
            return _buildEmptyState(context);
          }

          final pathList = vp.displayPathList;
          final saturation = context.watch<ConfigProvider>().config.saturation;

          return Stack(
            children: [
              // 垂直滑动 PreloadPageView
              PreloadPageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: context.watch<ConfigProvider>().config.swipeAnimationEnabled ? const _QuickerScrollPhysics() : const BouncingScrollPhysics(),
                itemCount: vp.displayList.length,
                preloadPagesCount: 1,
                onPageChanged: (i) {
                  _onPageChanged(i);
                  _checkLongVideoMode();
                },
                itemBuilder: (context, index) {
                  return RepaintBoundary(
                    child: _buildVideoPage(index, pathList[index], saturation),
                  );
                },
              ),

              // UI叠加层 (非手势模式时显示，自动隐藏)
              if (!vp.isGestureMode)
                AnimatedOpacity(
                  opacity: _isUiVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: IgnorePointer(
                    ignoring: !_isUiVisible,
                    child: Stack(
                      children: [
                        _buildTopBar(vp),
                        if (_isLongVideoMode) _buildLongVideoControlBar(vp) else _buildBottomBar(vp),
                        if (!_isLongVideoMode) _buildRightActionBar(vp),
                        const Positioned(top: 60, right: 12, child: TimerDisplay()),
                      ],
                    ),
                  ),
                ),

              // 长视频模式: 中央播放/暂停 (显示时点击隐藏)
              if (_isLongVideoMode && !vp.isGestureMode)
                Center(
                  child: AnimatedOpacity(
                    duration: AppTheme.durMedium,
                    opacity: _isUiVisible && !_isPlaying ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !_isUiVisible || _isPlaying,
                      child: GestureDetector(
                        onTap: _togglePlayPause,
                        child: GlassContainer(
                          decoration: GlassDecoration.strong.copyWith(
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 56),
                        ),
                      ),
                    ),
                  ),
                ),

              // 手势模式退出提示
              if (vp.isGestureMode)
                Positioned(
                  top: 40, left: 0, right: 0,
                  child: GestureDetector(
                    onTap: () => vp.exitGestureMode(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.black54,
                      child: const Text('点击退出手势模式', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    // 桌面端: 包装鼠标移动检测 + 快捷键
    if (PlatformUtils.isDesktop) {
      body = MouseRegion(
        onHover: _onMouseMove,
        child: PlayerShortcutScope(
          handler: this,
          isFullscreen: _isFullscreen,
          onShowUi: _showUi,
          child: body,
        ),
      );
    }

    return body;
  }

  /// 长视频模式底部控制条 (类似 YouTube/Bilibili)
  Widget _buildLongVideoControlBar(VideoPlayerProvider vp) {
    final currentEntry = _playerCache[_currentPageIndex];
    final config = context.watch<ConfigProvider>().config;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 视频信息
                if (vp.currentVideo != null)
                  IgnorePointer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((vp.currentVideo!.bloggerName ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '@${vp.currentVideo!.bloggerName}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: config.fontSize + 2,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Text(
                          vp.currentVideo!.fileName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: config.fontSize,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                // 现代进度条
                modern.ModernProgressBar(
                  player: currentEntry?.player,
                  showTimeBubble: true,
                  videoPath: vp.currentVideo?.path,
                ),
                const SizedBox(height: 8),
                // 控件行: 播放/暂停在左,其余全部靠右
                // 音量不再在行内放 Slider(避免与上方进度条视觉重复),
                // 点击音量按钮弹出玻璃弹窗
                Row(
                  children: [
                    IconButton(
                      icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
                      color: Colors.white,
                      onPressed: _togglePlayPause,
                    ),
                    const Spacer(),
                    _GlassIconButton(
                      icon: _volumeIcon(_volume),
                      tooltip: '音量 ${_volume.toInt()}%',
                      onPressed: _showVolumeSlider,
                    ),
                    const SizedBox(width: 8),
                    _buildSpeedButton(vp),
                    const SizedBox(width: 8),
                    _GlassIconButton(
                      icon: _isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                      tooltip: _isFullscreen ? '退出全屏' : '全屏',
                      onPressed: toggleFullscreen,
                    ),
                    const SizedBox(width: 8),
                    _buildMoreMenu(vp),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVolumeSlider() {
    final currentEntry = _playerCache[_currentPageIndex];
    if (currentEntry == null) return;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Material(
                  color: Colors.transparent,
                  child: GlassContainer(
                    decoration: GlassDecoration.strong.copyWith(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(_volumeIcon(_volume),
                                color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              '音量',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_volume.toInt()}%',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _volume = 0;
                                });
                                setLocal(() {});
                                currentEntry.player.setVolume(0);
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.volume_off_rounded,
                                    color: Colors.white70, size: 18),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 7),
                                  overlayShape: SliderComponentShape.noOverlay,
                                  activeTrackColor: colorScheme.primary,
                                  inactiveTrackColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  thumbColor: colorScheme.primary,
                                ),
                                child: Slider(
                                  value: _volume,
                                  min: 0,
                                  max: 100,
                                  onChanged: (v) {
                                    setState(() => _volume = v);
                                    if (v > 0) _lastNonZeroVolume = v;
                                    setLocal(() {});
                                    currentEntry.player.setVolume(v);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _volume = 100;
                                  _lastNonZeroVolume = 100;
                                });
                                setLocal(() {});
                                currentEntry.player.setVolume(100);
                              },
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.volume_up_rounded,
                                    color: Colors.white70, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _volumeIcon(double volume) {
    if (volume <= 0) return Icons.volume_off_rounded;
    if (volume < 33) return Icons.volume_mute_rounded;
    if (volume < 66) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  Widget _buildVideoPage(int index, String path, double saturation) {
    final entry = _getOrCreatePlayer(index, path);
    final isCurrentPage = index == _currentPageIndex;

    // 非当前页不渲染Video widget，节省GPU资源
    if (!isCurrentPage) {
      return const SizedBox.expand();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 视频渲染层 - 应用旋转/缩放变换
        Center(
          child: Transform.rotate(
            angle: _rotationState == 0 ? 0 : -math.pi / 2,
            child: Transform.scale(
              scale: _rotationState == 0 ? 1.0 : (_rotationState == 1 ? 1.8 : 2.24),
              child: AspectRatio(
                aspectRatio: _rotationState == 0 ? 9 / 16 : 16 / 9,
                child: entry != null
                    ? _buildVideoWithSaturation(
                        Video(
                          controller: entry.controller,
                          controls: NoVideoControls,
                          subtitleViewConfiguration: const SubtitleViewConfiguration(visible: true),
                        ),
                        saturation,
                      )
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),
        ),

        // 点击交互层 - 仅 onTap，不拦截 drag，让垂直滑动穿透到 PageView
        if (isCurrentPage && !PlatformUtils.isDesktop)
          Positioned.fill(
            child: PlaybackGestureDetector(
              player: entry?.player,
              onVolumeChanged: (v) {
                if (mounted) {
                  setState(() {
                    _volume = v;
                    if (v > 0) _lastNonZeroVolume = v;
                  });
                }
              },
              onSingleTap: _onSingleTap,
              onDoubleTap: _onDoubleTapLike,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                  _captureThumbnail();
                }
              },
              child: const SizedBox.expand(),
            ),
          ),
        // 桌面端: 保持原有轻量 GestureDetector (无手势控制)
        if (isCurrentPage && PlatformUtils.isDesktop)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onSingleTap,
              onDoubleTap: _onDoubleTapLike,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                  _captureThumbnail();
                }
              },
            ),
          ),

        // 双击红心动画层
        if (isCurrentPage)
          IgnorePointer(
            child: _LikeAnimationOverlay(animations: _likeAnimations),
          ),

        // 暂停图标 (弹入动效)
        AnimatedOpacity(
          duration: AppTheme.durMedium,
          curve: AppTheme.curveEmphasized,
          opacity: (isCurrentPage && !_isPlaying) ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: isCurrentPage && _isPlaying,
            child: Center(
              child: AnimatedScale(
                duration: AppTheme.durMedium,
                curve: AppTheme.curveEmphasized,
                scale: (isCurrentPage && !_isPlaying) ? 1.0 : 0.6,
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: GlassContainer(
                    decoration: GlassDecoration.strong.copyWith(
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 56),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 弹幕覆盖层 (仅当前页)
        if (isCurrentPage)
          const IgnorePointer(
            child: DanmakuOverlay(),
          ),
      ],
    );
  }

  Widget _buildTopBar(VideoPlayerProvider vp) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.transparent],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 列表/收藏模式时显示退出按钮，否则显示列表按钮
                if (vp.isListMode || vp.isFavoriteMode)
                  _GlassIconButton(
                    icon: Icons.arrow_back,
                    tooltip: vp.isFavoriteMode ? '退出收藏模式' : '退出列表模式',
                    onPressed: () {
                      vp.exitSubMode();
                      if (mounted) {
                        _pageController.jumpToPage(vp.currentIndex.clamp(0, vp.displayList.length - 1));
                        setState(() {});
                      }
                    },
                  )
                else ...[
                  _GlassIconButton(
                    icon: Icons.arrow_back,
                    tooltip: '返回',
                    onPressed: () => Navigator.pop(context),
                  ),
                  _GlassIconButton(
                    icon: Icons.list_rounded,
                    tooltip: '视频列表',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoListPage())),
                  ),
                ],
                // 模式标识
                if (vp.isListMode || vp.isFavoriteMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GlassContainer(
                      decoration: GlassDecoration.subtle.copyWith(
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        vp.isFavoriteMode ? '收藏模式' : '列表模式',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  )
                else
                  _GlassIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: '刷新',
                    onPressed: _loadVideos,
                  ),
                const Expanded(child: SizedBox.shrink()),
                IgnorePointer(child: RealTimeCounter()),
                _GlassIconButton(
                  icon: Icons.settings_rounded,
                  tooltip: '设置',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(VideoPlayerProvider vp) {
    final currentEntry = _playerCache[_currentPageIndex];
    final config = context.watch<ConfigProvider>().config;

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 视频信息
                if (vp.currentVideo != null)
                  IgnorePointer(
                    child: Opacity(
                      opacity: config.nameOpacity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((vp.currentVideo!.bloggerName ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '@${vp.currentVideo!.bloggerName}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: config.fontSize + 2,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Text(
                            vp.currentVideo!.fileName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: config.fontSize,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                // 进度条
                custom.ProgressBar(player: currentEntry?.player),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 右侧竖排操作栏（仿抖音布局）
  Widget _buildRightActionBar(VideoPlayerProvider vp) {
    return Positioned(
      right: 8,
      bottom: MediaQuery.of(context).size.height * 0.18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 收藏红心
          FavoriteButton(videoPath: vp.currentVideo?.path ?? '', index: vp.currentIndex),
          const SizedBox(height: 16),
          // 倍速
          _buildSpeedButton(vp),
          const SizedBox(height: 16),
          // 旋转
          _buildRightSideButton(
            _rotationState == 0 ? Icons.screen_rotation : Icons.screen_lock_rotation,
            _rotationState == 0 ? '横屏' : '恢复',
            () => setState(() => _rotationState = (_rotationState + 1) % 3),
          ),
          const SizedBox(height: 16),
          // 弹幕开关
          Consumer<DanmakuProvider>(
            builder: (context, dp, _) => _buildRightSideButton(
              Icons.subtitles,
              dp.isEnabled ? '弹幕开' : '弹幕关',
              () => dp.toggle(),
              isActive: dp.isEnabled,
            ),
          ),
          const SizedBox(height: 16),
          // 更多操作（弹出菜单）
          _buildMoreMenu(vp),
        ],
      ),
    );
  }

  Widget _buildRightSideButton(IconData icon, String label, VoidCallback onTap, {bool isActive = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassContainer(
            decoration: GlassDecoration.subtle.copyWith(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: isActive ? colorScheme.primary : Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? colorScheme.primary : Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(VideoPlayerProvider vp) {
    return Listener(
      onPointerDown: (_) => _onMenuOpen(),
      child: PopupMenuButton<String>(
        onCanceled: _onMenuClose,
        icon: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassContainer(
              decoration: GlassDecoration.subtle.copyWith(
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 4),
            const Text('更多', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
        onSelected: (value) {
          _onMenuClose();
          _onMoreMenuSelected(value, vp);
        },
        itemBuilder: (_) => [
        const PopupMenuItem(value: 'next', child: Text('下一个')),
        const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
        const PopupMenuItem(value: 'jump', child: Text('跳转')),
        const PopupMenuItem(value: 'timer', child: Text('定时器')),
        const PopupMenuItem(value: 'notebook', child: Text('笔记本')),
        const PopupMenuItem(value: 'danmaku', child: Text('弹幕设置')),
        const PopupMenuItem(value: 'gesture', child: Text('手势模式')),
        PopupMenuItem(
          value: 'long_video',
          child: Row(
            children: [
              Icon(_isLongVideoMode ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 18),
              const SizedBox(width: 8),
              const Text('长视频模式'),
            ],
          ),
        ),
        if (!vp.isFavoriteMode)
          const PopupMenuItem(value: 'favorite_mode', child: Text('收藏模式')),
        if (vp.isListMode || vp.isFavoriteMode)
          const PopupMenuItem(value: 'exit_sub', child: Text('退出子模式')),
      ],
      ),
    );
  }

  void _onMoreMenuSelected(String value, VideoPlayerProvider vp) {
    switch (value) {
      case 'next':
        if (_currentPageIndex < vp.displayList.length - 1) {
          _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        }
        break;
      case 'delete':
        _showDeleteConfirm(vp);
        break;
      case 'jump':
        _showJumpDialog(vp);
        break;
      case 'timer':
        _showTimerDialog(context.read<TimerProvider>());
        break;
      case 'notebook':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NotebookPage()));
        break;
      case 'danmaku':
        _showDanmakuSettings();
        break;
      case 'gesture':
        vp.enterGestureMode();
        break;
      case 'long_video':
        final newValue = !_isLongVideoMode;
        setState(() => _isLongVideoMode = newValue);
        // 持久化用户选择,关闭 App 后仍然记住
        unawaited(_saveLongVideoOverride(newValue));
        break;
      case 'favorite_mode':
        final fp = context.read<FavoriteProvider>();
        if (fp.favorites.isNotEmpty) {
          final favVideos = fp.favorites.map((f) => VideoItem.fromPath(f.filePath, f.index)).toList();
          vp.enterFavoritePlayMode(favVideos);
          if (mounted) {
            _pageController.jumpToPage(0);
            setState(() {});
          }
        }
        break;
      case 'exit_sub':
        vp.exitSubMode();
        if (mounted) {
          _pageController.jumpToPage(vp.currentIndex.clamp(0, vp.displayList.length - 1));
          setState(() {});
        }
        break;
    }
  }

  void _showDanmakuSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => const DanmakuSettingsSheet(),
    );
  }

  Widget _buildSpeedButton(VideoPlayerProvider vp) {
    return Listener(
      onPointerDown: (_) => _onMenuOpen(),
      child: PopupMenuButton<double>(
        onCanceled: _onMenuClose,
        icon: GlassContainer(
          decoration: GlassDecoration.subtle.copyWith(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('${vp.playbackRate}x', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        onSelected: (rate) {
          _onMenuClose();
          final entry = _playerCache[_currentPageIndex];
          if (entry != null) {
            entry.player.setRate(rate);
          }
          vp.setPlaybackRate(rate);
        },
        itemBuilder: (_) => AppConstants.playbackRates.map((r) =>
          PopupMenuItem(value: r, child: Text('${r}x'))).toList(),
      ),
    );
  }

  void _showDeleteConfirm(VideoPlayerProvider vp) {
    final currentVideo = vp.currentVideo;
    if (currentVideo == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除视频'),
        content: Text('确定删除 "${currentVideo.fileName}" 吗？\n此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final config = context.read<ConfigProvider>().config;
              final fileService = FileService(customVideoDir: config.customVideoDir);
              final videoRepo = VideoRepository(fileService);
              await videoRepo.deleteVideo(currentVideo.path);
              // 切换到下一个视频
              if (vp.displayList.length > 1) {
                final nextIndex = _currentPageIndex < vp.displayList.length - 1
                    ? _currentPageIndex : _currentPageIndex - 1;
                final updatedList = vp.displayList.where((v) => v.path != currentVideo.path).toList();
                vp.setVideoList(updatedList);
                if (mounted) {
                  _pageController.jumpToPage(nextIndex.clamp(0, updatedList.length - 1));
                }
              } else {
                vp.setVideoList([]);
              }
              if (mounted) {
                ToastUtil.show(context, '已删除 ${currentVideo.fileName}');
                context.read<DeviceProvider>().vibrate();
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showJumpDialog(VideoPlayerProvider vp) {
    final totalVideos = vp.displayList.length;
    if (totalVideos == 0) return;
    final controller = TextEditingController(text: '${_currentPageIndex + 1}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('跳转视频 (共$totalVideos个)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '输入视频序号',
                  suffixIcon: Icon(Icons.edit, size: 18),
                ),
                onSubmitted: (_) => Navigator.pop(ctx),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _jumpAdjustButton(ctx, controller, -1000, totalVideos),
                  _jumpAdjustButton(ctx, controller, -100, totalVideos),
                  _jumpAdjustButton(ctx, controller, -10, totalVideos),
                  _jumpAdjustButton(ctx, controller, -1, totalVideos),
                  _jumpAdjustButton(ctx, controller, 1, totalVideos),
                  _jumpAdjustButton(ctx, controller, 10, totalVideos),
                  _jumpAdjustButton(ctx, controller, 100, totalVideos),
                  _jumpAdjustButton(ctx, controller, 1000, totalVideos),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final target = int.tryParse(controller.text);
              if (target != null && target >= 1 && target <= totalVideos) {
                Navigator.pop(ctx);
                _pageController.jumpToPage(target - 1);
              } else {
                ToastUtil.show(context, '请输入1~$totalVideos的数字');
              }
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Widget _jumpAdjustButton(BuildContext ctx, TextEditingController controller, int delta, int total) {
    final label = delta > 0 ? '+$delta' : '$delta';
    return OutlinedButton(
      onPressed: () {
        final current = int.tryParse(controller.text) ?? 1;
        final next = (current + delta).clamp(1, total);
        controller.text = '$next';
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  /// 右滑截取当前帧作为缩略图
  Future<void> _captureThumbnail() async {
    final entry = _playerCache[_currentPageIndex];
    if (entry == null) return;
    try {
      final bytes = await entry.player.screenshot(format: 'image/jpeg');
      if (bytes != null && mounted) {
        // 保存截图到应用目录
        final dir = await _getScreenshotDir();
        final fileName = 'screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File(p.join(dir.path, fileName));
        await file.writeAsBytes(bytes);
        if (mounted) ToastUtil.show(context, '已保存截图');
      }
    } catch (e) {
      if (mounted) ToastUtil.show(context, '截帧失败');
    }
  }

  Future<Directory> _getScreenshotDir() async {
    final baseDir = await PathUtils.getBaseDir();
    final dir = Directory(p.join(baseDir.path, '截图'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  void _showTimerDialog(TimerProvider tp) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('定时关闭'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tp.isRunning) ...[
                Text('当前剩余: ${tp.remainingSeconds ~/ 60}分${tp.remainingSeconds % 60}秒', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                TextButton(onPressed: () { tp.cancelTimer(); Navigator.pop(ctx); }, child: Text('取消定时', style: TextStyle(color: colorScheme.error))),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [10, 20, 30, 60, 90, 120].map((m) => OutlinedButton(
                  onPressed: () { tp.setTimer(m * 60); Navigator.pop(ctx); ToastUtil.show(context, '已设置${m}分钟定时'); },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                  child: Text('${m}分'),
                )).toList(),
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))],
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('暂无视频', style: TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickVideoFolder(context),
                icon: const Icon(Icons.folder_open),
                label: const Text('选择视频文件夹'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _importVideos(context),
                icon: const Icon(Icons.video_call),
                label: const Text('导入视频文件'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('更多设置'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickVideoFolder(BuildContext context) async {
    // Android上选择文件夹需要MANAGE_EXTERNAL_STORAGE权限
    if (PlatformUtils.isAndroid) {
      try {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted && context.mounted) {
          ToastUtil.show(context, '需要存储管理权限才能选择文件夹');
          return;
        }
      } catch (_) {}
    }
    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择视频文件夹');
    if (dir == null) return; // 用户取消选择
    if (context.mounted) {
      await context.read<ConfigProvider>().updateField(customVideoDir: dir);
      if (!context.mounted) return;
      ToastUtil.show(context, '已设置视频目录');
      await _loadVideos();
      // 扫描后如果仍无视频，提示用户
      if (context.mounted && context.read<VideoPlayerProvider>().displayList.isEmpty) {
        ToastUtil.show(context, '该目录下未找到视频文件');
      }
    }
  }

  Future<void> _importVideos(BuildContext context) async {
    // Android上需要存储权限
    if (PlatformUtils.isAndroid) {
      try {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted && context.mounted) {
          ToastUtil.show(context, '需要存储权限才能导入视频');
          return;
        }
      } catch (_) {}
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    if (result == null || result.files.isEmpty) return; // 用户取消选择
    if (!context.mounted) return;
    final config = context.read<ConfigProvider>().config;
    final fileService = FileService(customVideoDir: config.customVideoDir);
    final videoRepo = VideoRepository(fileService);
    int successCount = 0;
    int failCount = 0;
    for (final file in result.files) {
      if (file.path != null) {
        final destPath = await videoRepo.importVideo(file.path!);
        if (destPath != null) {
          successCount++;
        } else {
          failCount++;
        }
      }
    }
    if (context.mounted) {
      if (successCount > 0) {
        ToastUtil.show(context, '已导入 $successCount 个视频${failCount > 0 ? "，$failCount 个失败" : ""}');
        await _loadVideos();
      } else {
        ToastUtil.show(context, '导入失败，请检查存储权限和视频目录设置');
      }
    }
  }
}

// ==================== 自定义快速滚动物理 ====================

class _QuickerScrollPhysics extends BouncingScrollPhysics {
  const _QuickerScrollPhysics({super.parent});

  @override
  _QuickerScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _QuickerScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.2,
    stiffness: 300.0,
    ratio: 1.1,
  );
}

// ==================== 播放器条目 ====================

class _VideoPlayerEntry {
  final Player player;
  final VideoController controller;

  _VideoPlayerEntry(this.player, this.controller);
}

// ==================== 双击红心动画 ====================

class _LikeAnimation {
  final int id;
  final int randomOffsetX;
  _LikeAnimation({required this.id, required this.randomOffsetX});
}

class _LikeAnimationOverlay extends StatelessWidget {
  final List<_LikeAnimation> animations;
  const _LikeAnimationOverlay({required this.animations});

  static const _duration = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    if (animations.isEmpty) return const SizedBox.shrink();
    return Stack(
      alignment: Alignment.center,
      children: animations.map((anim) {
        return TweenAnimationBuilder<double>(
          key: ValueKey(anim.id),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: _duration,
          curve: Curves.easeOut,
          builder: (context, t, child) {
            // 缩放: 0 -> 1.2 (0~30%) -> 1.0 (30~100%)
            final scale = t < 0.3
                ? (t / 0.3) * 1.2
                : 1.2 - 0.2 * ((t - 0.3) / 0.7);
            // 透明度: 1 -> 0 (50%~100%)
            final opacity = t < 0.5 ? 1.0 : 1.0 - ((t - 0.5) / 0.5);
            // 上浮
            final dy = -t * 90.0;
            return Transform.translate(
              offset: Offset(anim.randomOffsetX.toDouble(), dy),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.redAccent,
            size: 96,
            shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
          ),
        );
      }).toList(),
    );
  }
}

// ==================== 玻璃图标按钮 ====================

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;

  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: AppTheme.durFast,
        curve: AppTheme.curveStandard,
        child: GlassContainer(
          decoration: GlassDecoration.subtle.copyWith(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
