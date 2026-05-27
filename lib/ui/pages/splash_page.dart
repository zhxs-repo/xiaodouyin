import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/timer_provider.dart';
import '../../providers/resume_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/cultivation_provider.dart';
import '../../core/utils/tutorial_util.dart';
import 'password_page.dart';
import 'video_player_page.dart';
import 'beauty_page.dart';
import 'online_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initProviders();
      _checkStartupMode();
    });
  }

  void _initProviders() {
    // 异步初始化各Provider，捕获异常避免静默失败
    _safeInit(() => context.read<ConfigProvider>().loadConfig());
    _safeInit(() => context.read<FavoriteProvider>().load());
    _safeInit(() => context.read<TimerProvider>().load());
    _safeInit(() => context.read<ResumeProvider>().load());
    _safeInit(() async => context.read<DeviceProvider>().initBattery());
    _safeInit(() => context.read<CultivationProvider>().load());
    // 同步功能开关初始状态到对应Provider
    final config = context.read<ConfigProvider>().config;
    context.read<DeviceProvider>().setVibrationEnabled(config.vibrationEnabled);
    context.read<ResumeProvider>().setEnabled(config.globalResumeEnabled);
  }

  /// 安全执行异步初始化，捕获异常并打印日志
  void _safeInit(Future<void> Function() init) {
    init().then((_) {}, onError: (e) {
      debugPrint('Provider初始化失败: $e');
    });
  }

  void _checkStartupMode() {
    final config = context.read<ConfigProvider>().config;
    if (config.defaultStartupMode != 'none') {
      Future.microtask(() => _navigateToMode(config.defaultStartupMode));
    }
  }

  void _navigateToMode(String mode) {
    switch (mode) {
      case 'video':
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const VideoPlayerPage()));
        break;
      case 'beauty':
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BeautyPage()));
        break;
      case 'online':
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnlinePage()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>().config;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF1a1a2e)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_circle_filled, size: 80, color: Colors.red),
              const SizedBox(height: 20),
              const Text('小抖音', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 60),
              _buildModeButton('视频模式', Icons.videocam, 'video', config.videoModePassword),
              const SizedBox(height: 16),
              _buildModeButton('美图模式', Icons.image, 'beauty', config.beautyModePassword),
              const SizedBox(height: 16),
              _buildModeButton('在线模式', Icons.cloud, 'online', config.onlineModePassword),
              const SizedBox(height: 30),
              TextButton.icon(
                onPressed: () => showTutorialDialog(context),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('操作教程', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeButton(String label, IconData icon, String mode, String password) {
    return ElevatedButton.icon(
      onPressed: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PasswordPage(mode: mode, password: password))),
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(200, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    );
  }
}
