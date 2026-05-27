import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _player = AudioPlayer();
  List<String> _playlist = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  double _volume = 1.0;

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
    await _player.play(DeviceFileSource(_playlist[_currentIndex]));
    _isPlaying = true;
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    await _player.resume();
    _isPlaying = true;
  }

  Future<void> stop() async {
    await _player.stop();
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
    await _player.setVolume(_volume);
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
