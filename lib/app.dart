import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/config_provider.dart';
import 'providers/video_player_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/danmaku_provider.dart';
import 'providers/search_provider.dart';
import 'providers/beauty_provider.dart';
import 'providers/online_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/resume_provider.dart';
import 'providers/device_provider.dart';
import 'providers/cultivation_provider.dart';
import 'data/repositories/config_repository.dart';
import 'data/repositories/video_repository.dart';
import 'data/repositories/favorite_repository.dart';
import 'data/repositories/search_repository.dart';
import 'data/repositories/play_history_repository.dart';
import 'data/services/storage_service.dart';
import 'data/services/file_service.dart';
import 'data/services/online_api_service.dart';
import 'data/services/audio_service.dart';
import 'data/services/thumbnail_service.dart';
import 'core/theme/app_theme.dart';
import 'ui/pages/splash_page.dart';

class App extends StatelessWidget {
  final StorageService storage;
  final FileService _fileService = FileService();
  final OnlineApiService _onlineApiService = OnlineApiService();
  final AudioService _audioService = AudioService();
  final ThumbnailService _thumbnailService = ThumbnailService();

  App({super.key, required this.storage});

  ThemeMode _parseThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigProvider(ConfigRepository(storage), _fileService)),
        ChangeNotifierProvider(create: (_) => VideoPlayerProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider(FavoriteRepository(storage))),
        ChangeNotifierProvider(create: (_) => DanmakuProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider(SearchRepository(storage), VideoRepository(_fileService))),
        ChangeNotifierProvider(create: (_) => BeautyProvider(_fileService, _audioService)),
        ChangeNotifierProvider(create: (_) => OnlineProvider(_onlineApiService)),
        ChangeNotifierProvider(create: (_) => TimerProvider(storage)),
        ChangeNotifierProvider(create: (_) => ResumeProvider(PlayHistoryRepository(storage))),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => CultivationProvider()),
        Provider<ThumbnailService>.value(value: _thumbnailService),
      ],
      child: Consumer<ConfigProvider>(
        builder: (context, cp, _) => MaterialApp(
          title: '小抖音',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _parseThemeMode(cp.config.themeMode),
          home: const SplashPage(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
