import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';
import 'core/utils/platform_utils.dart';
import 'data/services/storage_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  if (PlatformUtils.isDesktop) {
    await windowManager.ensureInitialized();
  }
  await _requestPermissions();
  // 预初始化StorageService
  final storage = await StorageService.getInstance();
  runApp(App(storage: storage));
}

Future<void> _requestPermissions() async {
  if (!PlatformUtils.isMobile) return;
  // Android 13+ 细分媒体权限
  await [
    Permission.videos,
    Permission.photos,
    Permission.audio,
  ].request();
  // Android 12 及以下需要整体存储权限
  await Permission.storage.request();
  // 选择文件夹/导入文件需要MANAGE_EXTERNAL_STORAGE
  await Permission.manageExternalStorage.request();
}
