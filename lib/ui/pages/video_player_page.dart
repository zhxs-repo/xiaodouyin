import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:preload_page_view/preload_page_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/path_utils.dart';
import '../../core/utils/platform_utils.dart';
import '../../providers/video_player_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/danmaku_provider.dart';
import '../../providers/timer_provider.dart';
import '../../providers/resume_provider.dart';
import '../../providers/device_provider.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/file_service.dart';
import '../../data/models/video_item.dart';
import '../../core/utils/toast_util.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/danmaku_overlay.dart';
import '../widgets/favorite_button.dart';
import '../widgets/real_time_counter.dart';
import '../widgets/timer_display.dart';
import '../widgets/progress_bar.dart' as custom;
import 'video_list_page.dart';
import 'notebook_page.dart';
import 'settings_page.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with WidgetsBindingObserver {
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
  late final ResumeProvider _resumeProvider;

  // --- 双击红心动画 ---
  final List<_LikeAnimation> _likeAnimations = [];
  int _likeAnimationIdCounter = 0;

  // --- UI自动隐藏 ---
  bool _isUiVisible = true;
  Timer? _uiHideTimer;

  @override
  void initState() {
    super.initState();
    _resumeProvider = context.read<ResumeProvider>();
    WidgetsBinding.instance.addObserver(this);
    _loadVideos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playingSubscription?.cancel();
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
      } catch (_) {}
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
    _uiHideTimer?.cancel();
    _uiHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _isUiVisible = false);
      }
    });
  }

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
    // 触发红心动画
    final id = _likeAnimationIdCounter++;
    setState(() {
      _likeAnimations.add(_LikeAnimation(id: id, startTime: DateTime.now()));
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
    return Scaffold(
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
                onPageChanged: _onPageChanged,
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
                        _buildBottomBar(vp),
                        _buildRightActionBar(vp),
                        const Positioned(top: 60, right: 12, child: TimerDisplay()),
                      ],
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
        if (isCurrentPage)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _onSingleTap,
              onDoubleTap: _onDoubleTapLike,
              // 右滑截缩略图
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

        // 暂停图标
        if (isCurrentPage && !_isPlaying)
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 48),
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 列表/收藏模式时显示退出按钮，否则显示列表按钮
              if (vp.isListMode || vp.isFavoriteMode)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  tooltip: '返回',
                  onPressed: () => Navigator.pop(context),
                ),
                IconButton(
                  icon: const Icon(Icons.list, color: Colors.white),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VideoListPage())),
                ),
              ],
              // 模式标识
              if (vp.isListMode || vp.isFavoriteMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: vp.isFavoriteMode ? Colors.amber.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    vp.isFavoriteMode ? '收藏模式' : '列表模式',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _loadVideos,
                ),
              IgnorePointer(child: RealTimeCounter()),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(VideoPlayerProvider vp) {
    final currentEntry = _playerCache[_currentPageIndex];

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 视频信息
              if (vp.currentVideo != null)
                IgnorePointer(
                  child: Opacity(
                    opacity: context.watch<ConfigProvider>().config.nameOpacity,
                    child: Text(
                      '${vp.currentVideo!.bloggerName ?? ""} ${vp.currentVideo!.fileName}',
                      style: TextStyle(color: Colors.white, fontSize: context.watch<ConfigProvider>().config.fontSize),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              // 进度条
              custom.ProgressBar(player: currentEntry?.player),
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: isActive ? Colors.amber : Colors.white, size: 22),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: isActive ? Colors.amber : Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(VideoPlayerProvider vp) {
    return PopupMenuButton<String>(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 2),
          const Text('更多', style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
      onSelected: (value) => _onMoreMenuSelected(value, vp),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'next', child: Text('下一个')),
        const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
        const PopupMenuItem(value: 'jump', child: Text('跳转')),
        const PopupMenuItem(value: 'timer', child: Text('定时器')),
        const PopupMenuItem(value: 'notebook', child: Text('笔记本')),
        const PopupMenuItem(value: 'gesture', child: Text('手势模式')),
        if (!vp.isFavoriteMode)
          const PopupMenuItem(value: 'favorite_mode', child: Text('收藏模式')),
        if (vp.isListMode || vp.isFavoriteMode)
          const PopupMenuItem(value: 'exit_sub', child: Text('退出子模式')),
      ],
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
      case 'gesture':
        vp.enterGestureMode();
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

  Widget _buildSpeedButton(VideoPlayerProvider vp) {
    return PopupMenuButton<double>(
      icon: Text('${vp.playbackRate}x', style: const TextStyle(color: Colors.white, fontSize: 14)),
      onSelected: (rate) {
        final entry = _playerCache[_currentPageIndex];
        if (entry != null) {
          entry.player.setRate(rate);
        }
        vp.setPlaybackRate(rate);
      },
      itemBuilder: (_) => AppConstants.playbackRates.map((r) =>
        PopupMenuItem(value: r, child: Text('${r}x'))).toList(),
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
      builder: (ctx) => AlertDialog(
        title: const Text('定时关闭'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tp.isRunning) ...[
              Text('当前剩余: ${tp.remainingSeconds ~/ 60}分${tp.remainingSeconds % 60}秒', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 12),
              TextButton(onPressed: () { tp.cancelTimer(); Navigator.pop(ctx); }, child: const Text('取消定时', style: TextStyle(color: Colors.red))),
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
      ),
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
  final DateTime startTime;
  _LikeAnimation({required this.id, required this.startTime});
}

class _LikeAnimationOverlay extends StatelessWidget {
  final List<_LikeAnimation> animations;
  const _LikeAnimationOverlay({required this.animations});

  @override
  Widget build(BuildContext context) {
    if (animations.isEmpty) return const SizedBox();
    return Stack(
      alignment: Alignment.center,
      children: animations.map((anim) {
        final elapsed = DateTime.now().difference(anim.startTime).inMilliseconds;
        final progress = (elapsed / 1000.0).clamp(0.0, 1.0);
        // 缩放：0→1.2→1.0
        final scale = progress < 0.3
            ? (progress / 0.3) * 1.2
            : 1.2 - 0.2 * ((progress - 0.3) / 0.7);
        // 透明度：1→0
        final opacity = progress < 0.5 ? 1.0 : 1.0 - ((progress - 0.5) / 0.5);
        // 上浮偏移
        final offsetY = -progress * 80.0;
        return Transform.translate(
          offset: Offset(0, offsetY),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: const Icon(
                Icons.favorite,
                color: Colors.red,
                size: 80,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
