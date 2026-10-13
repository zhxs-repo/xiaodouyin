import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioPlayer? _player;
  List<String> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  double _volume = 1.0;

  /// 首次播放才创建原生播放器，避免 App 一启动就常驻一个 audioplayers 实例
  AudioPlayer get _audio => _player ??= AudioPlayer();

  bool get isPlaying => _isPlaying;
  int get currentIndex => _currentIndex;
  List<String> get playlist => _playlist;
  double get volume => _volume;

  Future<void> setPlaylist(List<String> paths) async {
    _playlist = paths;
    _currentIndex = 0;
  }

  Future<void> play([int? index]) async {
    if (_playlist.isEmpty) return;
    if (index != null) _currentIndex = index;
    if (_currentIndex >= _playlist.length) return;
    final player = _audio;
    await player.setVolume(_volume);
    await player.play(DeviceFileSource(_playlist[_currentIndex]));
    _isPlaying = true;
  }

  Future<void> pause() async {
    if (_player == null) return;
    await _player!.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    if (_player == null) return;
    await _player!.resume();
    _isPlaying = true;
  }

  Future<void> stop() async {
    if (_player == null) return;
    await _player!.stop();
    _isPlaying = false;
  }

  Future<void> playNext() async {
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await play(_currentIndex);
    }
  }

  Future<void> playPrev() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await play(_currentIndex);
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player?.setVolume(_volume);
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}
