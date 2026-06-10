import 'package:flutter/material.dart';
import 'folder_home_page.dart';
import 'video_list_page.dart';

/// 主页面壳层 - 底部导航栏架构
/// Tab 1: 文件夹视图 (新)
/// Tab 2: 全部视频列表 (原首页)
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  
  // 使用 IndexedStack 保持页面状态
  final List<Widget> _pages = const [
    FolderHomePage(),
    VideoListPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: '文件夹',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: '全部视频',
          ),
        ],
      ),
    );
  }
}
