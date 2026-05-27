import 'package:flutter/material.dart';
import '../data/services/file_service.dart';
import '../data/services/audio_service.dart';

class BeautyProvider extends ChangeNotifier {
  final FileService _fileService;
  final AudioService _audioService;
  List<String> _images = [];
  List<String> _musicList = [];
  int _currentPreviewIndex = 0;
  String? _currentFolder;
  double _rotation = 0;

  BeautyProvider(this._fileService, this._audioService);

  List<String> get images => _images;
  List<String> get musicList => _musicList;
  int get currentPreviewIndex => _currentPreviewIndex;
  String? get currentFolder => _currentFolder;
  double get rotation => _rotation;
  bool get isMusicPlaying => _audioService.isPlaying;
  double get musicVolume => _audioService.volume;

  Future<void> loadImages() async {
    final images = await _fileService.scanImageFiles();
    // 避免相同列表重复触发notifyListeners
    if (_images.length == images.length &&
        (_images.isEmpty || _images.every((e) => images.contains(e)))) {
      return;
    }
    _images = images;
    notifyListeners();
  }

  Future<void> loadMusic(String dirPath) async {
    _musicList = await _fileService.scanAudioFiles(dirPath);
    await _audioService.setPlaylist(_musicList);
    notifyListeners();
  }

  void setPreviewIndex(int index) {
    _currentPreviewIndex = index;
    notifyListeners();
  }

  void nextImage() {
    if (_currentPreviewIndex < _images.length - 1) {
      _currentPreviewIndex++;
      notifyListeners();
    }
  }

  void prevImage() {
    if (_currentPreviewIndex > 0) {
      _currentPreviewIndex--;
      notifyListeners();
    }
  }

  void rotate90() {
    _rotation = (_rotation + 90) % 360;
    notifyListeners();
  }

  Future<void> toggleMusic() async {
    if (_audioService.isPlaying) {
      await _audioService.pause();
    } else {
      await _audioService.resume();
    }
    notifyListeners();
  }

  Future<void> nextMusic() async {
    await _audioService.playNext();
    notifyListeners();
  }

  Future<void> prevMusic() async {
    await _audioService.playPrev();
    notifyListeners();
  }

  Future<void> setMusicVolume(double volume) async {
    await _audioService.setVolume(volume);
    notifyListeners();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
