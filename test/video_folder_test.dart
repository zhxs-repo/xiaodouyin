import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xiaodouyin/data/repositories/video_repository.dart';
import 'package:xiaodouyin/data/services/file_service.dart';

Future<void> _writeFile(String path) async {
  final file = File(path);
  await file.create(recursive: true);
  await file.writeAsString('x');
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('xiaodouyin_folders');
    addTearDown(() => root.delete(recursive: true));

    Future<void> write(List<String> segments) =>
        _writeFile(p.joinAll([root.path, ...segments]));

    // 根目录自己的视频，显示为"根目录"
    await write(['根目录.mp4']);
    // 有视频的文件夹，内部按文件名排序且忽略非视频文件
    await write(['剧集A', '02.mp4']);
    await write(['剧集A', '01.mkv']);
    await write(['剧集A', '说明.txt']);
    await write(['剧集B', 'ep1.mp4']);
    // 被排除的目录
    await write(['空文件夹', '.keep']);
    await write(['.隐藏', 'secret.mp4']);
    await write(['已屏蔽', '.nomedia']);
    await write(['已屏蔽', 'video.mp4']);
    await write(['已屏蔽', '子目录', 'video.mp4']);
    // 第 4 层，默认深度扫不到
    await write(['深', '层1', '层2', '层3', 'video.mp4']);
  });

  Future<List<String>> namesAtDepth(int maxDepth) async {
    final folders = await VideoRepository(
      FileService(customVideoDir: root.path),
    ).loadFolders(maxDepth: maxDepth);
    return folders.map((f) => f.name).toList();
  }

  test('默认扫描列出根目录与各层有视频的文件夹，跳过隐藏和 .nomedia', () async {
    expect(await namesAtDepth(FileService.folderScanMaxDepth),
        ['剧集A', '剧集B', '根目录']);
  });

  test('文件夹内视频按文件名排序，非视频文件被忽略', () async {
    final folders = await VideoRepository(
      FileService(customVideoDir: root.path),
    ).loadFolders();
    final seriesA = folders.firstWhere((f) => f.name == '剧集A');

    expect(seriesA.videoCount, 2);
    expect(seriesA.videos.map((v) => v.fileName), ['01.mkv', '02.mp4']);
    expect(seriesA.path, p.join(root.path, '剧集A'));
  });

  test('加深 maxDepth 后能扫到更深层的文件夹', () async {
    expect(await namesAtDepth(4), contains(p.join('深', '层1', '层2', '层3')));
  });

  test('.nomedia 目录的整棵子树都不扫描，即使加深深度', () async {
    final names = await namesAtDepth(6);

    expect(names, isNot(contains('已屏蔽')));
    expect(names, isNot(contains(p.join('已屏蔽', '子目录'))));
    expect(names, isNot(contains('.隐藏')));
  });
}
