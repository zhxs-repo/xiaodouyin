import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/timer_provider.dart';
import '../../providers/resume_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/cultivation_provider.dart';
import '../../providers/danmaku_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/tutorial_util.dart';
import '../../core/utils/page_transitions.dart';
import 'password_page.dart';
import 'video_player_page.dart';
import 'beauty_page.dart';
import 'online_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final AnimationController _cardsController;
  late final Animation<double> _cardsOpacity;
  late final Animation<Offset> _cardsOffset;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: AppTheme.durSlow,
    );
    _logoScale = CurvedAnimation(parent: _logoController, curve: AppTheme.curveEmphasized);
    _logoOpacity = CurvedAnimation(parent: _logoController, curve: const Interval(0.2, 1.0, curve: AppTheme.curveEmphasized));

    _cardsController = AnimationController(
      vsync: this,
      duration: AppTheme.durSlow,
    );
    _cardsOpacity = CurvedAnimation(parent: _cardsController, curve: AppTheme.curveEmphasized);
    _cardsOffset = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _cardsController, curve: AppTheme.curveEmphasized),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _logoController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _cardsController.forward();
      _initProviders();
      _checkStartupMode();
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _cardsController.dispose();
    super.dispose();
  }

  void _initProviders() {
    _safeInit(() => context.read<ConfigProvider>().loadConfig());
    _safeInit(() => context.read<FavoriteProvider>().load());
    _safeInit(() => context.read<TimerProvider>().load());
    _safeInit(() => context.read<ResumeProvider>().load());
    _safeInit(() async => context.read<DeviceProvider>().initBattery());
    _safeInit(() => context.read<CultivationProvider>().load());
    _safeInit(() => context.read<DanmakuProvider>().load());
    final config = context.read<ConfigProvider>().config;
    context.read<DeviceProvider>().setVibrationEnabled(config.vibrationEnabled);
    context.read<ResumeProvider>().setEnabled(config.globalResumeEnabled);
  }

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
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          // 多色径向背景 + 模糊光斑
          Positioned.fill(
            child: CustomPaint(
              painter: _BackdropPainter(colorScheme: colorScheme),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo + 标题 (入场缩放)
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.7, end: 1.0).animate(_logoScale),
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.primaryGradient,
                                boxShadow: AppTheme.shadowGlow,
                              ),
                              child: Icon(Icons.play_arrow_rounded, color: colorScheme.onPrimary, size: 56),
                            ),
                            const SizedBox(height: 20),
                            Text('小抖音', style: Theme.of(context).textTheme.displayMedium),
                            const SizedBox(height: 8),
                            Text('选择模式开始', style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // 模式卡片 (上滑淡入)
                    FadeTransition(
                      opacity: _cardsOpacity,
                      child: SlideTransition(
                        position: _cardsOffset,
                        child: Column(
                          children: [
                            _ModeCard(
                              icon: Icons.movie_outlined,
                              title: '视频模式',
                              subtitle: '本地视频 / 沉浸式播放',
                              color: colorScheme.primary,
                              onTap: () => _enterMode('video', config.videoModePassword),
                            ),
                            const SizedBox(height: 14),
                            _ModeCard(
                              icon: Icons.photo_library_outlined,
                              title: '美图模式',
                              subtitle: '本地图片 / 音乐匹配',
                              color: colorScheme.tertiary,
                              onTap: () => _enterMode('beauty', config.beautyModePassword),
                            ),
                            const SizedBox(height: 14),
                            _ModeCard(
                              icon: Icons.cloud_outlined,
                              title: '在线模式',
                              subtitle: '在线视频 / 在线图片',
                              color: colorScheme.secondary,
                              onTap: () => _enterMode('online', config.onlineModePassword),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    TextButton.icon(
                      onPressed: () => showTutorialDialog(context),
                      icon: const Icon(Icons.help_outline, size: 18),
                      label: const Text('操作教程'),
                      style: TextButton.styleFrom(foregroundColor: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _enterMode(String mode, String password) {
    Navigator.push(
      context,
      PageTransitions.fadeThrough(PasswordPage(mode: mode, password: password)),
    );
  }
}

class _ModeCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: AppTheme.durFast,
        curve: AppTheme.curveStandard,
        child: GlassContainer(
          decoration: GlassDecoration.medium.copyWith(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusM),
                ),
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(widget.subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  final ColorScheme colorScheme;
  _BackdropPainter({required this.colorScheme});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    // 主色径向
    paint.shader = RadialGradient(
      center: const Alignment(-0.6, -0.8),
      radius: 1.0,
      colors: [
        colorScheme.primary.withValues(alpha: 0.25),
        colorScheme.primary.withValues(alpha: 0.0),
      ],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    // 三色径向
    paint.shader = RadialGradient(
      center: const Alignment(0.7, 0.2),
      radius: 0.9,
      colors: [
        colorScheme.tertiary.withValues(alpha: 0.20),
        colorScheme.tertiary.withValues(alpha: 0.0),
      ],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
    paint.shader = RadialGradient(
      center: const Alignment(0.1, 0.9),
      radius: 0.8,
      colors: [
        colorScheme.secondary.withValues(alpha: 0.18),
        colorScheme.secondary.withValues(alpha: 0.0),
      ],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.colorScheme != colorScheme;
}
