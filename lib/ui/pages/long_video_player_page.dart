import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/platform_utils.dart';
import '../../core/utils/route_observer.dart';
import '../../core/utils/toast_util.dart';
import '../../data/models/app_config.dart';
import '../../data/models/video_item.dart';
import '../../data/repositories/favorite_repository.dart';
import '../../data/repositories/play_history_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../data/services/file_service.dart';
import '../../data/services/storage_service.dart';
import '../../providers/config_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/resume_provider.dart';
import '../gestures/desktop_shortcuts.dart';
import '../widgets/modern_progress_bar.dart' as modern;

/// 长视频模式：单个 mpv 实例 + mpv 原生播放列表。
///
/// 与短视频模式的 LRU 多播放器池不同，这里只有一个 [Player]，切集由 mpv 的
/// playlist 完成，收藏/播放历史/续播使用独立存储键，与短视频数据互不干扰。
class LongVideoPlayerPage extends StatefulWidget {
  const LongVideoPlayerPage({super.key});

  @override
  State<LongVideoPlayerPage> createState() => _LongVideoPlayerPageState();
}

class _LongVideoPlayerPageState extends State<LongVideoPlayerPage>
    with WidgetsBindingObserver, WindowListener, RouteAware
    implements PlayerShortcutHandler {
  /// 单个实例的 demuxer 缓存，比默认 32MB 收敛一半
  static const int _demuxerCacheBytes = 16 * 1024 * 1024;
  static const List<String> _subtitleExts = [
    '.srt',
    '.ass',
    '.ssa',
    '.vtt',
    '.sub',
  ];
  static const Duration _uiHideDelay = Duration(seconds: 4);

  late final Player _player;
  late final VideoController _controller;

  FavoriteProvider? _favorites;
  ResumeProvider? _resume;
  late final ConfigProvider _config;

  List<VideoItem> _videos = const [];
  int _index = 0;
  bool _loading = true;
  bool _isPlaying = false;
  bool _error = false;

  Duration _livePosition = Duration.zero;
  Duration _liveDuration = Duration.zero;

  bool _isUiVisible = true;
  bool _showPlaylist = false;
  Timer? _uiHideTimer;
  double _volume = 100;
  double _lastNonZeroVolume = 100;
  double _rate = 1.0;
  bool _isFullscreen = false;
  Size? _preFullscreenSize;
  Offset? _preFullscreenPosition;

  bool _wasPlayingBeforeSuspend = false;
  bool _wasPlayingBeforeBlur = false;
  Route? _observedRoute;

  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub;
  StreamSubscription<Playlist>? _playlistSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  int _subtitleSeq = 0;

  @override
  void initState() {
    super.initState();
    _player = Player(
      configuration: const PlayerConfiguration(
        title: '小抖音 长视频',
        bufferSize: _demuxerCacheBytes,
      ),
    );
    _controller = VideoController(_player);
    _listen();
    WidgetsBinding.instance.addObserver(this);
    if (PlatformUtils.isDesktop) {
      windowManager.addListener(this);
    }
    // dispose() 时 element 已 defunct，那里不能再 context.read，先存下实例
    _config = context.read<ConfigProvider>();
    _config.addListener(_onConfigChanged);
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _observedRoute) {
      appRouteObserver.unsubscribe(this);
      appRouteObserver.subscribe(this, route);
      _observedRoute = route;
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _config.removeListener(_onConfigChanged);
    WidgetsBinding.instance.removeObserver(this);
    if (PlatformUtils.isDesktop) {
      windowManager.removeListener(this);
    }
    _uiHideTimer?.cancel();
    _playingSub?.cancel();
    _completedSub?.cancel();
    _playlistSub?.cancel();
    _errorSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _saveCurrentProgress();
    _resume?.stopAutoSave();
    _resume?.dispose();
    _favorites?.dispose();
    _player.dispose();
    super.dispose();
  }

  // ==================== 初始化 ====================

  Future<void> _init() async {
    final config = _config.config;
    final storage = await StorageService.getInstance();
    if (!mounted) return;
    final favorites = FavoriteProvider(
      FavoriteRepository(storage, storageKey: StorageKeys.longVideoFavorites),
      autoExport: false,
    );
    final resume = ResumeProvider(
      PlayHistoryRepository(
        storage,
        storageKey: StorageKeys.longVideoPlayHistory,
      ),
    );
    await favorites.load();
    await resume.load();
    resume.setEnabled(config.globalResumeEnabled);
    if (!mounted) return;
    setState(() {
      _favorites = favorites;
      _resume = resume;
    });
    await _loadVideos();
  }

  Future<void> _loadVideos() async {
    final config = _config.config;
    final videos = await VideoRepository(
      FileService(customVideoDir: config.customVideoDir),
    ).loadVideos();
    if (!mounted) return;
    setState(() {
      _videos = videos;
      _loading = false;
    });
    if (videos.isEmpty) return;
    await _openPlaylist(_resolveStartIndex(videos));
  }

  /// 从长视频播放历史里挑最近看过的一集作为起始，没有记录则从第一集开始
  int _resolveStartIndex(List<VideoItem> videos) {
    final history = _resume?.history;
    if (history == null || history.isEmpty) return 0;
    String? newestPath;
    DateTime? newestTime;
    for (final record in history.values) {
      if (newestTime == null || record.timestamp.isAfter(newestTime)) {
        final idx = videos.indexWhere((v) => v.path == record.videoPath);
        if (idx < 0) continue;
        newestTime = record.timestamp;
        newestPath = record.videoPath;
      }
    }
    if (newestPath == null) return 0;
    return videos.indexWhere((v) => v.path == newestPath);
  }

  Future<void> _openPlaylist(int startIndex) async {
    if (_videos.isEmpty) return;
    final medias = _videos.map((v) => Media(v.path)).toList();
    await _player.open(Playlist(medias, index: startIndex), play: true);
    if (!mounted) return;
    setState(() => _index = startIndex);
    await _applyPlaylistMode();
    _trackCurrentVideo(startIndex);
    _loadSubtitles(_videos[startIndex].path);
    final position = _resume?.getResumePosition(_videos[startIndex].path);
    if (position != null && position.inSeconds > 0) {
      _seekAfterStart(position);
    }
  }

  /// open 会覆盖随后的 seek，因此等播放器真正进入播放状态后再跳转
  void _seekAfterStart(Duration position) {
    _player.stream.playing
        .firstWhere((playing) => playing)
        .timeout(const Duration(seconds: 5), onTimeout: () => false)
        .then((playing) {
          if (mounted && playing) _player.seek(position);
        });
  }

  Future<void> _applyPlaylistMode() async {
    final mode = _playlistModeOf(_config.config.playMode);
    await _player.setPlaylistMode(mode);
  }

  /// 长视频模式只有"列表循环 / 单集循环"两档，顺序播放（normal）按列表循环处理。
  PlaylistMode _playlistModeOf(PlayMode mode) {
    switch (mode) {
      case PlayMode.loopOne:
        return PlaylistMode.single;
      case PlayMode.loop:
      case PlayMode.normal:
        return PlaylistMode.loop;
    }
  }

  void _onConfigChanged() {
    if (!mounted) return;
    _applyPlaylistMode();
  }

  // ==================== 播放器事件 ====================

  void _listen() {
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() {
        _isPlaying = playing;
        _isUiVisible = true;
      });
      _resetUiHideTimer();
    });
    _completedSub = _player.stream.completed.listen((completed) {
      if (!mounted || !completed) return;
      _saveCurrentProgress();
      setState(() => _isUiVisible = true);
      // eof-reached 是每个文件结束都会触发，只在真正播完整个列表时提示
      if (_isPlaylistEnd()) {
        _uiHideTimer?.cancel();
        _showToast('播放完成');
      }
    });
    _playlistSub = _player.stream.playlist.listen((playlist) {
      final index = playlist.index;
      if (!mounted || index == _index || index < 0 || index >= _videos.length) {
        return;
      }
      _trackCurrentVideo(index);
      _loadSubtitles(_videos[index].path);
      setState(() => _index = index);
    });
    _errorSub = _player.stream.error.listen((message) {
      if (!mounted) return;
      setState(() => _error = message.isNotEmpty);
      if (message.isNotEmpty) debugPrint('长视频播放失败: $message');
    });
    _positionSub = _player.stream.position.listen(
      (position) => _livePosition = position,
    );
    _durationSub = _player.stream.duration.listen(
      (duration) => _liveDuration = duration,
    );
  }

  /// 为当前集启动进度自动保存（上一集的落盘由调用方在切集前完成）
  void _trackCurrentVideo(int index) {
    if (index < 0 || index >= _videos.length) return;
    if (_error) setState(() => _error = false);
    _resume?.stopAutoSave();
    _resume?.startAutoSave(
      _videos[index].path,
      () => _player.state.position,
      () => _player.state.duration,
    );
  }

  void _saveCurrentProgress() {
    if (_index < 0 || _index >= _videos.length) return;
    _resume?.saveNow(
      _videos[_index].path,
      () => _livePosition,
      () => _liveDuration,
    );
  }

  /// mpv 只在列表末尾停止，循环/单集模式下不会真正播完
  bool _isPlaylistEnd() {
    final mode = _player.state.playlistMode;
    if (mode == PlaylistMode.loop || mode == PlaylistMode.single) return false;
    return _index >= _videos.length - 1;
  }

  /// 加载字幕：同目录同名字幕优先，其次内封默认轨道
  Future<void> _loadSubtitles(String videoPath) async {
    final seq = ++_subtitleSeq;
    // 换集时先关闭上一集遗留的外挂字幕
    _player.setSubtitleTrack(SubtitleTrack.no());
    final file = File(videoPath);
    final baseName = p.basenameWithoutExtension(file.path);
    for (final ext in _subtitleExts) {
      final subtitle = File(p.join(file.parent.path, '$baseName$ext'));
      if (!await subtitle.exists()) continue;
      if (!mounted || _subtitleSeq != seq) return;
      _player.setSubtitleTrack(SubtitleTrack.uri(subtitle.path));
      return;
    }
    try {
      await _player.stream.playing
          .firstWhere((playing) => playing)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    } catch (_) {
      return;
    }
    if (!mounted || _subtitleSeq != seq) return;
    final realTracks = _player.state.tracks.subtitle
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();
    if (realTracks.isEmpty) return;
    final track = realTracks.firstWhere(
      (t) => t.isDefault == true,
      orElse: () => realTracks.first,
    );
    _player.setSubtitleTrack(track);
  }

  // ==================== 播放控制 ====================

  Future<void> _jumpTo(int index) async {
    if (index < 0 || index >= _videos.length || index == _index) return;
    _saveCurrentProgress();
    // media_kit 的 jump 会先 play 再切 playlist-pos，无需额外调用 play
    await _player.jump(index);
    if (!mounted) return;
    setState(() => _index = index);
    _trackCurrentVideo(index);
    _loadSubtitles(_videos[index].path);
  }

  void _togglePlayPause() {
    if (_player.state.completed ||
        (_liveDuration.inSeconds > 0 && _livePosition >= _liveDuration)) {
      _player.seek(Duration.zero);
    }
    _player.playOrPause();
    _resetUiHideTimer();
  }

  @override
  void seek(Duration delta) {
    final target = _livePosition + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _liveDuration ? _liveDuration : target);
    _player.seek(clamped);
    _resetUiHideTimer();
  }

  @override
  void seekToFraction(double fraction) {
    if (_liveDuration == Duration.zero) return;
    _player.seek(_liveDuration * fraction.clamp(0.0, 1.0));
    _resetUiHideTimer();
  }

  @override
  void setVolume(double delta) {
    final next = (_volume + delta).clamp(0.0, 100.0);
    setState(() {
      if (next > 0) _lastNonZeroVolume = next;
      _volume = next;
    });
    _player.setVolume(next);
    _resetUiHideTimer();
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
    _player.setVolume(_volume);
    _resetUiHideTimer();
  }

  void _setRate(double rate) {
    setState(() => _rate = rate);
    _player.setRate(rate);
    _resetUiHideTimer();
  }

  Future<void> _cyclePlayMode() async {
    final current = _config.config.playMode;
    final next = current == PlayMode.loopOne ? PlayMode.loop : PlayMode.loopOne;
    await _config.updateField(playMode: next);
    _resetUiHideTimer();
  }

  @override
  void next() => _jumpTo(_index + 1);

  @override
  void previous() => _jumpTo(_index - 1);

  @override
  void togglePlayPause() => _togglePlayPause();

  @override
  void showUi() => _showUi();

  // ==================== 全屏 / 生命周期 / 路由 ====================

  @override
  void toggleFullscreen() async {
    final newValue = !_isFullscreen;
    setState(() => _isFullscreen = newValue);
    if (!PlatformUtils.isDesktop) return;
    if (newValue) {
      _preFullscreenSize = await windowManager.getSize();
      _preFullscreenPosition = await windowManager.getPosition();
    }
    await windowManager.setFullScreen(newValue);
    if (!newValue && _preFullscreenSize != null) {
      await windowManager.setSize(_preFullscreenSize!);
      if (_preFullscreenPosition != null) {
        await windowManager.setPosition(_preFullscreenPosition!);
      }
    }
  }

  @override
  void exitFullscreen() async {
    if (!_isFullscreen) return;
    setState(() => _isFullscreen = false);
    if (!PlatformUtils.isDesktop) return;
    await windowManager.setFullScreen(false);
    if (_preFullscreenSize != null) {
      await windowManager.setSize(_preFullscreenSize!);
      if (_preFullscreenPosition != null) {
        await windowManager.setPosition(_preFullscreenPosition!);
      }
    }
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted && !_isFullscreen) setState(() => _isFullscreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted && _isFullscreen) setState(() => _isFullscreen = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (!isActive && _isPlaying) {
      _wasPlayingBeforeBlur = true;
      _player.pause();
    } else if (isActive && _wasPlayingBeforeBlur) {
      _wasPlayingBeforeBlur = false;
      _player.play();
    }
  }

  /// 被上层页面覆盖：暂停并停止进度自动保存（只有一个 mpv 实例，不必销毁）
  @override
  void didPushNext() {
    _saveCurrentProgress();
    _resume?.stopAutoSave();
    _wasPlayingBeforeSuspend = _isPlaying;
    if (_isPlaying) _player.pause();
  }

  @override
  void didPopNext() {
    _trackCurrentVideo(_index);
    if (_wasPlayingBeforeSuspend) _player.play();
    _wasPlayingBeforeSuspend = false;
  }

  // ==================== UI ====================

  void _showUi() {
    if (!_isUiVisible) setState(() => _isUiVisible = true);
    _resetUiHideTimer();
  }

  void _resetUiHideTimer() {
    _uiHideTimer?.cancel();
    if (!_isPlaying) return;
    _uiHideTimer = Timer(_uiHideDelay, () {
      if (mounted && !_showPlaylist) setState(() => _isUiVisible = false);
    });
  }

  void _showToast(String message) {
    if (mounted) ToastUtil.show(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final favorites = _favorites;
    final resume = _resume;
    Widget body = _loading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : _videos.isEmpty
        ? _buildEmptyState()
        : _buildPlayer();
    // 页面级 provider 遮蔽全局的短视频 provider，实现收藏/播放历史/续播隔离
    if (favorites != null && resume != null) {
      body = MultiProvider(
        providers: [
          ChangeNotifierProvider<FavoriteProvider>.value(value: favorites),
          ChangeNotifierProvider<ResumeProvider>.value(value: resume),
        ],
        child: body,
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: PlayerShortcutScope(
        handler: this,
        isFullscreen: _isFullscreen,
        onShowUi: _showUi,
        child: body,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_outlined, color: Colors.white54, size: 56),
          const SizedBox(height: 12),
          const Text('没有本地视频', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          const Text(
            '请先在短视频模式导入视频',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    final config = context.watch<ConfigProvider>().config;
    final current = _videos[_index];
    final fit = switch (config.videoFit) {
      VideoFitMode.cover => BoxFit.cover,
      VideoFitMode.fitWidth => BoxFit.fitWidth,
      VideoFitMode.fitHeight => BoxFit.fitHeight,
      VideoFitMode.contain => BoxFit.contain,
    };
    final uiOpacity = _isUiVisible ? 1.0 : 0.0;

    return MouseRegion(
      onHover: (_) => _showUi(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlayPause,
        onDoubleTapDown: (details) => _onDoubleTap(details.globalPosition),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: Video(
                controller: _controller,
                fit: fit,
                controls: NoVideoControls,
                subtitleViewConfiguration: const SubtitleViewConfiguration(
                  visible: true,
                ),
              ),
            ),
            if (_error) _buildErrorLayer(),
            if (!_isPlaying)
              Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white.withValues(alpha: 0.35),
                  size: 72,
                ),
              ),
            if (_showPlaylist) _buildPlaylistScrim(),
            _buildTopBar(current, uiOpacity),
            _buildBottomBar(current, uiOpacity),
            if (_showPlaylist) _buildPlaylistPanel(),
          ],
        ),
      ),
    );
  }

  void _onDoubleTap(Offset position) {
    final width = MediaQuery.sizeOf(context).width;
    if (position.dx < width / 3) {
      seek(const Duration(seconds: -10));
    } else if (position.dx > width * 2 / 3) {
      seek(const Duration(seconds: 10));
    } else {
      _togglePlayPause();
    }
  }

  Widget _buildErrorLayer() {
    return Align(
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 160),
        child: GlassContainer(
          decoration: GlassDecoration.subtle.copyWith(
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('播放失败', style: TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() => _error = false);
                  // 用 jump 重载当前集，open(Media) 会把整个播放列表丢掉
                  _player.jump(_index);
                  _loadSubtitles(_videos[_index].path);
                },
                icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
                label: const Text('重试', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 淡入淡出的控制条容器：完全隐藏时不再拦截点击
  Widget _faded(double opacity, Widget child) => IgnorePointer(
    ignoring: opacity == 0,
    child: AnimatedOpacity(
      duration: AppTheme.durFast,
      opacity: opacity,
      child: child,
    ),
  );

  Widget _buildTopBar(VideoItem current, double opacity) {
    return PositionedDirectional(
      top: 0,
      start: 0,
      end: 0,
      child: _faded(
        opacity,
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    tooltip: '返回',
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          current.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '长视频 ${_index + 1}/${_videos.length}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Consumer<FavoriteProvider>(
                    builder: (context, fp, _) {
                      final isFav = fp.isFavorite(current.path);
                      return IconButton(
                        onPressed: () =>
                            fp.toggleFavorite(current.path, current.index),
                        icon: Icon(
                          isFav
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: isFav ? AppTheme.accentColor : Colors.white,
                        ),
                        tooltip: isFav ? '取消收藏' : '收藏',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(VideoItem current, double opacity) {
    return PositionedDirectional(
      bottom: 0,
      start: 0,
      end: 0,
      child: _faded(
        opacity,
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  modern.ModernProgressBar(
                    player: _player,
                    showTimeBubble: true,
                    videoPath: current.path,
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: previous,
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                        ),
                        tooltip: '上一集',
                      ),
                      IconButton(
                        onPressed: _togglePlayPause,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        tooltip: _isPlaying ? '暂停' : '播放',
                      ),
                      IconButton(
                        onPressed: next,
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white,
                        ),
                        tooltip: '下一集',
                      ),
                      _PlayModeButton(
                        mode: context.watch<ConfigProvider>().config.playMode,
                        onPressed: _cyclePlayMode,
                      ),
                      _RateButton(rate: _rate, onChanged: _setRate),
                      if (PlatformUtils.isDesktop) ...[
                        Icon(
                          _volume == 0 ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(
                          width: 110,
                          child: Slider(
                            value: _volume,
                            max: 100,
                            activeColor: AppTheme.primaryColor,
                            onChanged: (value) {
                              setState(() {
                                _volume = value;
                                if (value > 0) _lastNonZeroVolume = value;
                              });
                              _player.setVolume(value);
                            },
                            onChangeEnd: (_) => _resetUiHideTimer(),
                          ),
                        ),
                      ] else
                        IconButton(
                          onPressed: toggleMute,
                          icon: Icon(
                            _volume == 0 ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white,
                          ),
                          tooltip: '静音',
                        ),
                      const Spacer(),
                      StreamBuilder<Duration>(
                        stream: _player.stream.position,
                        builder: (context, snapshot) => Text(
                          '${_formatDuration(snapshot.data ?? Duration.zero)} / '
                          '${_formatDuration(_player.state.duration)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showPlaylist = !_showPlaylist;
                            if (_showPlaylist) {
                              _uiHideTimer?.cancel();
                              _isUiVisible = true;
                            } else {
                              _resetUiHideTimer();
                            }
                          });
                        },
                        icon: Icon(
                          Icons.playlist_play_rounded,
                          color: _showPlaylist
                              ? AppTheme.primaryColor
                              : Colors.white,
                        ),
                        tooltip: '播放列表',
                      ),
                      IconButton(
                        onPressed: toggleFullscreen,
                        icon: Icon(
                          _isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: Colors.white,
                        ),
                        tooltip: '全屏',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 面板展开时铺在视频之上的透明点击层。
  /// 放在控制条下层：控制面板外的空白只收起面板，不再穿透触发播放/暂停，
  /// 同时控制条上的按钮仍可正常点击。
  Widget _buildPlaylistScrim() {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showPlaylist = false),
      ),
    );
  }

  Widget _buildPlaylistPanel() {
    final width = MediaQuery.sizeOf(context).width.clamp(260.0, 380.0);
    // 面板底色跟随主题亮度（深色主题黑纱 / 浅色主题白纱），文字颜色必须同步，
    // 否则浅色主题下白字落在白纱上几乎不可读。
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : colorScheme.onSurface;
    final mutedColor = isDark ? Colors.white70 : colorScheme.onSurfaceVariant;
    final faintColor = isDark ? Colors.white54 : colorScheme.onSurfaceVariant;
    final favoriteColor = isDark
        ? AppTheme.accentColor
        : const Color(0xFFB8860B);
    // 面板内 item 之间的空隙不属于任何子手势, 不吃掉就会被外层 scrim 当成
    // "面板外点击", 点一下列表空白就把面板关掉了
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: GlassContainer(
            decoration: GlassDecoration.strong.copyWith(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppTheme.radiusXL),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                    child: Row(
                      children: [
                        Text(
                          '播放列表 (${_videos.length})',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => setState(() => _showPlaylist = false),
                          icon: Icon(Icons.close, color: textColor),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _videos.length,
                      itemBuilder: (context, i) {
                        final video = _videos[i];
                        final isCurrent = i == _index;
                        return Consumer<FavoriteProvider>(
                          builder: (context, fp, _) => ListTile(
                            selected: isCurrent,
                            selectedTileColor: AppTheme.primaryColor.withValues(
                              alpha: 0.16,
                            ),
                            dense: true,
                            leading: Icon(
                              isCurrent
                                  ? Icons.play_arrow_rounded
                                  : Icons.movie_outlined,
                              color: isCurrent
                                  ? AppTheme.primaryColor
                                  : faintColor,
                              size: 20,
                            ),
                            title: Text(
                              video.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent ? textColor : mutedColor,
                                fontWeight: isCurrent
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: fp.isFavorite(video.path)
                                ? Text(
                                    '已收藏',
                                    style: TextStyle(
                                      color: favoriteColor,
                                      fontSize: 11,
                                    ),
                                  )
                                : null,
                            onTap: () {
                              _jumpTo(i);
                              setState(() => _showPlaylist = false);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '${two(minutes)}:${two(seconds)}';
  }
}

class _PlayModeButton extends StatelessWidget {
  final PlayMode mode;
  final VoidCallback onPressed;

  const _PlayModeButton({required this.mode, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (mode) {
      PlayMode.loopOne => (Icons.repeat_one_rounded, '单集循环'),
      PlayMode.normal || PlayMode.loop => (Icons.repeat_rounded, '列表循环'),
    };
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: Colors.white),
      tooltip: '$label（点击切换）',
    );
  }
}

class _RateButton extends StatelessWidget {
  final double rate;
  final ValueChanged<double> onChanged;

  const _RateButton({required this.rate, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: '倍速',
      initialValue: rate,
      onSelected: onChanged,
      offset: const Offset(0, -40),
      itemBuilder: (context) => [
        for (final value in AppConstants.playbackRates)
          PopupMenuItem(
            value: value,
            child: Text('${value}x', style: const TextStyle(fontSize: 13)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Text(
          rate == 1.0 ? '倍速' : '${rate}x',
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}
