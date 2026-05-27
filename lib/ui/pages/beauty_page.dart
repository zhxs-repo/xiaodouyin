import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/beauty_provider.dart';
import '../../providers/config_provider.dart';
import '../../data/services/file_service.dart';
import '../../core/utils/toast_util.dart';
import 'beauty_preview_page.dart';
import 'settings_page.dart';

class BeautyPage extends StatefulWidget {
  const BeautyPage({super.key});

  @override
  State<BeautyPage> createState() => _BeautyPageState();
}

class _BeautyPageState extends State<BeautyPage> {
  @override
  void initState() {
    super.initState();
    context.read<BeautyProvider>().loadImages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('美图模式'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => context.read<BeautyProvider>().loadImages()),
        IconButton(icon: const Icon(Icons.music_note), onPressed: _showMusicControl),
      ]),
      body: Consumer<BeautyProvider>(
        builder: (context, bp, _) {
          if (bp.images.isEmpty) {
            return _buildEmptyState(context);
          }
          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
            itemCount: bp.images.length,
            addAutomaticKeepAlives: true,
            addRepaintBoundaries: true,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () {
                bp.setPreviewIndex(index);
                Navigator.push(context, MaterialPageRoute(builder: (_) => BeautyPreviewPage(initialIndex: index)));
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(File(bp.images[index]), fit: BoxFit.cover,
                  cacheWidth: 200,
                  errorBuilder: (_, _, _) => Container(color: Colors.grey.shade800, child: const Icon(Icons.broken_image, color: Colors.white24))),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMusicControl() {
    showModalBottomSheet(context: context, builder: (context) => Container(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('背景音乐', style: TextStyle(fontSize: 18, color: Colors.white)),
        const SizedBox(height: 16),
        Consumer<BeautyProvider>(builder: (_, bp, _) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.skip_previous), onPressed: () => bp.prevMusic()),
            IconButton(icon: Icon(bp.isMusicPlaying ? Icons.pause : Icons.play_arrow), onPressed: () => bp.toggleMusic(), iconSize: 48),
            IconButton(icon: const Icon(Icons.skip_next), onPressed: () => bp.nextMusic()),
          ],
        )),
        const SizedBox(height: 12),
        Consumer<BeautyProvider>(builder: (_, bp, _) => Row(
          children: [
            const Icon(Icons.volume_down, color: Colors.white54, size: 20),
            Expanded(
              child: Slider(
                value: bp.musicVolume,
                onChanged: (v) => bp.setMusicVolume(v),
              ),
            ),
            const Icon(Icons.volume_up, color: Colors.white54, size: 20),
          ],
        )),
      ]),
    ));
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library, size: 64, color: Colors.white24),
            const SizedBox(height: 16),
            const Text('暂无图片', style: TextStyle(color: Colors.white54, fontSize: 18)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pickImageFolder(context),
                icon: const Icon(Icons.folder_open),
                label: const Text('选择图片文件夹'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _importImages(context),
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('导入图片文件'),
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

  Future<void> _pickImageFolder(BuildContext context) async {
    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: '选择图片文件夹');
    if (dir != null && context.mounted) {
      await context.read<ConfigProvider>().updateField(customImageDir: dir);
      if (!context.mounted) return;
      ToastUtil.show(context, '已设置图片目录');
      context.read<BeautyProvider>().loadImages();
    }
  }

  Future<void> _importImages(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null && result.files.isNotEmpty && context.mounted) {
      final config = context.read<ConfigProvider>().config;
      final fileService = FileService(customImageDir: config.customImageDir);
      int successCount = 0;
      for (final file in result.files) {
        if (file.path != null) {
          final destPath = await fileService.copyFileToImageDir(file.path!);
          if (destPath != null) successCount++;
        }
      }
      if (context.mounted) {
        ToastUtil.show(context, '已导入 $successCount 张图片');
        context.read<BeautyProvider>().loadImages();
      }
    }
  }
}
