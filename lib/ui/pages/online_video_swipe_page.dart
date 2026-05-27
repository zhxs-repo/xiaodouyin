import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:preload_page_view/preload_page_view.dart';
import '../../providers/online_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/toast_util.dart';
import '../widgets/progress_bar.dart' as custom;
import '../widgets/favorite_button.dart';

/// 抖音式垂直滑动视频页面
///
/// 参考实现：
/// - mjl0602/flutter_tiktok: 自定义滚动物理 + AbsorbPointer 手势冲突解决
/// - FlutterWiz/flutter_video_feed: PreloadPageView + LRU缓存 + 滑动窗口管理
class OnlineVideoSwipePage extends StatefulWidget {
  final String categoryName;

  const OnlineVideoSwipePage({super.key, required this.categoryName});

  @override
  State<OnlineVideoSwipePage> createState() => _OnlineVideoSwipePageState();
}

class _OnlineVideoSwipePageState extends State<OnlineVideoSwipePage>
    with WidgetsBindingObserver {
  // --- 控制器 ---
  final PreloadPageController _pageController = PreloadPageController();

  // --- LRU 播放器缓存 ---
  static const int _maxCacheSize = 3; // 最多同时保留3个播放器
  final Map<int, _VideoPlayerEntry> _playerCache = {};
  final List<int> _accessOrder = []; // 最近访问在末尾
  final Set<int> _disposingPlayers = {}; // 正在销毁的索引，防竞态

  // --- 状态 ---
  int _currentPageIndex = 0;
  bool _isPlaying = true;
  bool _isAppActive = true;
  bool _hasInitialized = false;
  int _rotationState = 0; // 0=正常, 1=横屏1.8x, 2=横屏2.24x
  double _playbackRate = 1.0;
  StreamSubscription<bool>? _playingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playingSubscription?.cancel();
    _pageController.dispose();
    _disposeAllPlayers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasActive = _isAppActive;
    _isAppActive = state == AppLifecycleState.resumed;

    if (!_isAppActive && wasActive) {
      // 进入后台：暂停所有视频
      _pauseAllPlayers();
    } else if (_isAppActive && !wasActive) {
      // 恢复前台：播放当前视频
      _playPlayer(_currentPageIndex);
    }
  }

  // ==================== 播放器管理 ====================

  /// 获取或创建播放器（LRU 缓存）
  /// 创建后立即暂停，仅当显式调用 _playPlayer 时才播放
  _VideoPlayerEntry? _getOrCreatePlayer(int index, String url) {
    // 缓存命中
    if (_playerCache.containsKey(index)) {
      _touchPlayer(index);
      return _playerCache[index]!;
    }

    // 缓存未命中：创建新播放器
    try {
      final player = Player(configuration: const PlayerConfiguration());
      final controller = VideoController(player);
      _playerCache[index] = _VideoPlayerEntry(player, controller);
      _touchPlayer(index);
      player.open(Media(url));
      // 关键：open后立即暂停，防止预加载页自动播放产生多音频
      player.pause();
      // 尝试加载内封字幕
      _loadEmbeddedSubtitles(player);
      // LRU 淘汰
      _enforceCacheLimit();

      return _playerCache[index]!;
    } catch (e) {
      return null;
    }
  }

  /// 尝试选择内封字幕的第一个轨道
  void _loadEmbeddedSubtitles(Player player) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final tracks = player.state.tracks.subtitle;
      final realTracks = tracks.where((t) => t.id != 'auto' && t.id != 'no').toList();
      if (realTracks.isNotEmpty) {
        final defaultTrack = realTracks.firstWhere(
          (t) => t.isDefault == true,
          orElse: () => realTracks.first,
        );
        player.setSubtitleTrack(defaultTrack);
      }
    });
  }

  /// 标记最近访问
  void _touchPlayer(int index) {
    _accessOrder
      ..remove(index)
      ..add(index);
  }

  /// LRU 淘汰超出容量的播放器
  void _enforceCacheLimit() {
    while (_playerCache.length > _maxCacheSize && _accessOrder.isNotEmpty) {
      final oldestIndex = _accessOrder.first;
      _removePlayer(oldestIndex);
    }
  }

  /// 滑动窗口管理：保持 [当前页-1, 当前页, 当前页+1] 范围内的播放器
  Future<void> _managePlayerWindow(int currentPage, List<String> videoList) async {
    final windowStart = (currentPage - 1).clamp(0, videoList.length - 1);
    final windowEnd = (currentPage + 1).clamp(0, videoList.length - 1);

    // 销毁窗口外的播放器
    final indicesToRemove = _playerCache.keys
        .where((i) => i < windowStart || i > windowEnd)
        .toList();
    for (final i in indicesToRemove) {
      _removePlayer(i);
    }

    // 初始化窗口内的播放器，当前页优先
    if (currentPage < videoList.length) {
      _getOrCreatePlayer(currentPage, videoList[currentPage]);
      if (windowStart < currentPage) {
        _getOrCreatePlayer(windowStart, videoList[windowStart]);
      }
      if (windowEnd > currentPage) {
        _getOrCreatePlayer(windowEnd, videoList[windowEnd]);
      }
    }
  }

  /// 移除并销毁指定播放器
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

  /// 销毁所有播放器
  void _disposeAllPlayers() {
    for (final entry in _playerCache.values) {
      try { entry.player.dispose(); } catch (_) {}
    }
    _playerCache.clear();
    _accessOrder.clear();
    _disposingPlayers.clear();
  }

  /// 暂停所有播放器
  void _pauseAllPlayers() {
    for (final entry in _playerCache.values) {
      try { entry.player.pause(); } catch (_) {}
    }
  }

  /// 播放指定索引的视频，并监听其播放状态流同步UI
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

  // ==================== 页面切换 ====================

  Future<void> _onPageChanged(int newIndex) async {
    if (newIndex == _currentPageIndex) return;

    final previousIndex = _currentPageIndex;
    _currentPageIndex = newIndex;

    // 检测快速滑动（跳页）
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
    final op = context.read<OnlineProvider>();
    await _managePlayerWindow(newIndex, op.videoUrlList);

    // 4. 仅播放当前视频（预加载页保持暂停）
    _playPlayer(newIndex);

    if (mounted) setState(() {});

    // 5. 通知 provider 预加载更多
    op.onVideoPageChanged(newIndex);
  }

  void _togglePlayPause() {
    final entry = _playerCache[_currentPageIndex];
    if (entry != null) {
      entry.player.playOrPause();
      // _isPlaying 由 player.stream.playing 监听自动同步，无需手动设置
    }
  }

  // ==================== UI 构建 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<OnlineProvider>(
        builder: (context, op, _) {
          if (op.isLoading && op.videoUrlList.isEmpty) {
            return _buildLoadingState();
          }

          if (op.error != null && op.videoUrlList.isEmpty) {
            return _buildErrorState(op);
          }

          final videoList = op.videoUrlList;
          if (videoList.isEmpty) return const SizedBox();

          return Stack(
            children: [
              // 垂直滑动 PreloadPageView（预构建前后页面，消除白屏）
              PreloadPageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const _QuickerScrollPhysics(), // 自定义快速滚动物理
                itemCount: videoList.length,
                preloadPagesCount: 1, // 预构建前后1页
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  final url = videoList[index];
                  return RepaintBoundary(
                    child: _buildVideoPage(index, url),
                  );
                },
              ),

              // 顶部栏
              _buildTopBar(videoList.length),

              // 底部控制栏（进度条+倍速+旋转）
              _buildBottomBar(videoList),

              // 右侧操作栏
              _buildRightActionBar(videoList),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('加载视频中...', style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildErrorState(OnlineProvider op) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(op.error!, style: const TextStyle(color: Colors.redAccent, fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => op.initVideoSwipeList(op.currentCategoryId ?? '1'),
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPage(int index, String url) {
    final isCurrentPage = index == _currentPageIndex;

    // 非当前页：渲染黑屏占位，不创建/渲染Video widget，避免UI重叠
    if (!isCurrentPage) {
      return const SizedBox.expand();
    }

    final entry = _getOrCreatePlayer(index, url);

    if (!_hasInitialized && entry != null) {
      _hasInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playPlayer(index);
      });
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
                    ? Video(
                        controller: entry.controller,
                        controls: NoVideoControls,
                        subtitleViewConfiguration: const SubtitleViewConfiguration(visible: true),
                      )
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
          ),
        ),

        // 点击交互层 - 仅 onTap，不拦截 drag，让垂直滑动穿透到 PageView
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _togglePlayPause,
          ),
        ),

        // 暂停图标
        if (!_isPlaying)
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
      ],
    );
  }

  Widget _buildTopBar(int totalCount) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              // 非交互区域用IgnorePointer包裹，不拦截滑动手势
              Expanded(
                child: IgnorePointer(
                  child: Text(
                    widget.categoryName,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IgnorePointer(
                child: Text(
                  '${_currentPageIndex + 1}/$totalCount',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.history, color: Colors.white70, size: 20),
                tooltip: '会话记录',
                onPressed: () => _showSessionList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRightActionBar(List<String> videoList) {
    final currentUrl = _currentPageIndex < videoList.length ? videoList[_currentPageIndex] : '';
    return Positioned(
      right: 12,
      bottom: MediaQuery.of(context).size.height * 0.3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 收藏按钮
          if (currentUrl.isNotEmpty)
            FavoriteButton(videoPath: currentUrl, index: _currentPageIndex),
          const SizedBox(height: 20),
          _buildSideButton(Icons.refresh, '换一个', () {
            final entry = _playerCache[_currentPageIndex];
            if (entry != null && _currentPageIndex < videoList.length) {
              entry.player.open(Media(videoList[_currentPageIndex]));
            }
          }),
          const SizedBox(height: 20),
          _buildSideButton(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            _isPlaying ? '暂停' : '播放',
            _togglePlayPause,
          ),
          const SizedBox(height: 20),
          // 旋转按钮
          _buildSideButton(
            _rotationState == 0 ? Icons.screen_rotation : Icons.screen_lock_rotation,
            _rotationState == 0 ? '横屏' : '恢复',
            () => setState(() => _rotationState = (_rotationState + 1) % 3),
          ),
          const SizedBox(height: 20),
          // 下载按钮
          _buildSideButton(Icons.download, '下载', () => _downloadCurrentVideo(videoList)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(List<String> videoList) {
    final currentEntry = _playerCache[_currentPageIndex];
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 进度条
              custom.ProgressBar(player: currentEntry?.player),
              const SizedBox(height: 4),
              // 倍速 + 视频序号
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 倍速按钮
                  _buildSpeedButton(),
                  // 视频序号
                  IgnorePointer(
                    child: Text(
                      '${_currentPageIndex + 1}/${videoList.length}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedButton() {
    return PopupMenuButton<double>(
      icon: Text('${_playbackRate}x', style: const TextStyle(color: Colors.white, fontSize: 14)),
      onSelected: (rate) {
        final entry = _playerCache[_currentPageIndex];
        if (entry != null) {
          entry.player.setRate(rate);
        }
        setState(() => _playbackRate = rate);
      },
      itemBuilder: (_) => AppConstants.playbackRates.map((r) =>
        PopupMenuItem(value: r, child: Text('${r}x'))).toList(),
    );
  }

  Widget _buildSideButton(IconData icon, String label, VoidCallback onTap) {
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
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Future<void> _downloadCurrentVideo(List<String> videoList) async {
    if (_currentPageIndex >= videoList.length) return;
    final url = videoList[_currentPageIndex];
    ToastUtil.show(context, '开始下载...');
    final op = context.read<OnlineProvider>();
    final savedPath = await op.downloadVideo(url, widget.categoryName);
    if (!mounted) return;
    if (savedPath != null) {
      ToastUtil.show(context, '已下载到 $savedPath');
    } else {
      ToastUtil.show(context, '下载失败');
    }
  }

  void _showSessionList() {
    final op = context.read<OnlineProvider>();
    final items = op.sessionItems;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('会话记录', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('${items.length}条', style: const TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Text('暂无浏览记录', style: TextStyle(color: Colors.white54)))
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[items.length - 1 - index]; // 最新的在前
                    final timeStr = '${item.viewedAt.hour.toString().padLeft(2, '0')}:${item.viewedAt.minute.toString().padLeft(2, '0')}';
                    return ListTile(
                      dense: true,
                      leading: Text(timeStr, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      title: Text(item.categoryName, style: const TextStyle(color: Colors.white, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.url, style: const TextStyle(color: Colors.white38, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== 自定义快速滚动物理 ====================
// 参考 mjl0602/flutter_tiktok 的 QuickerScrollPhysics
// 更轻的质量 + 更高的刚度 + 过阻尼 = 翻页更干脆利落

class _QuickerScrollPhysics extends BouncingScrollPhysics {
  const _QuickerScrollPhysics({super.parent});

  @override
  _QuickerScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _QuickerScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 0.2,       // 更轻 → 更快响应
    stiffness: 300.0, // 更高刚度 → 更快回弹
    ratio: 1.1,       // 过阻尼 → 无振荡
  );
}

// ==================== 播放器条目 ====================

class _VideoPlayerEntry {
  final Player player;
  final VideoController controller;

  _VideoPlayerEntry(this.player, this.controller);
}
