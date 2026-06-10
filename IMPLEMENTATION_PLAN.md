# 🚀 小抖音 v2.0 重构实施方案 (User-Centric)

> **版本**: v2.0  
> **状态**: 待执行  
> **最后更新**: 2025-01-XX  
> **作者**: zhxs-repo  

---

## 📋 目录

1. [执行摘要](#执行摘要)
2. [需求回顾与可行性分析](#需求回顾与可行性分析)
3. [实施路线图](#实施路线图)
4. [详细技术方案](#详细技术方案)
5. [代码级实施方案](#代码级实施方案)
6. [风险评估与应对](#风险评估与应对)
7. [测试计划](#测试计划)
8. [发布计划](#发布计划)

---

## 🎯 执行摘要

### 核心目标
从"工程师思维"转向"用户思维"，打造**实用、可控、高性能**的视频播放器。

### 关键变更
| 类别 | 变更前 | 变更后 | 用户价值 |
|------|--------|--------|----------|
| **本地弹幕** | 不支持 | 支持同名 XML 加载 | 满足弹幕盒子刚需 |
| **播放模式** | 强制智能切换 | 可配置开关，默认关闭 | 把选择权还给用户 |
| **首页布局** | 单一视频列表 | 文件夹管理 + 原列表 Tab2 | 媒体管理更直观 |
| **预览体验** | 进度条缩略图 | 海报墙瀑布流/双列 | 快速浏览内容 |
| **手势交互** | 竖滑冲突 | 长按触发精细调节 | 操作更精准 |
| **设置架构** | 混杂 | 全局/播放器分离 | 查找更便捷 |
| **性能适配** | 一刀切 | 设备分级动态调整 | 低端机不卡顿 |
| **多端体验** | 统一交互 | 符合平台习惯 | 原生般流畅 |

### 明确排除 (本期不动)
- ✅ **美图模块**：图片选择/导入页、图片浏览器完全保留，不做任何改动

### 工期估算
- **总周期**: 25 工作日
- **阶段划分**: 4 个阶段 (配置改造 → 核心功能 → 交互适配 → 测试发布)

---

## 🔍 需求回顾与可行性分析

### 功能需求

#### F1: 本地弹幕 XML 支持
**用户需求**: "本地弹幕是真实需求，有弹幕盒子这样的需求，需要支持适配文件同名的 xml 弹幕加载"

**可行性**: ✅ 高  
**技术难度**: ⭐⭐⭐  
**现有基础**: 
- `lib/core/danmaku/` 已有弹幕渲染引擎
- `lib/services/danmaku_service.dart` 提供数据接口

**实施方案**:
1. 新增 `DanmakuXmlParser` 解析器
2. 扩展 `DanmakuService.loadDanmaku()` 支持 XML 格式
3. 自动检测 `video.xml` / `video.danmaku.xml` 同名文件

**代码影响**:
```dart
// 新增文件：lib/services/danmaku_xml_parser.dart
class DanmakuXmlParser {
  Future<List<DanmakuComment>> parse(File xmlFile);
}

// 修改：lib/services/danmaku_service.dart
Future<void> loadDanmaku(String videoPath) async {
  // 优先加载同名 XML
  final xmlFile = File('${videoPath.baseName}.xml');
  if (await xmlFile.exists()) {
    comments = await DanmakuXmlParser().parse(xmlFile);
    return;
  }
  // 原有逻辑...
}
```

---

#### F2: 智能模式开关化
**用户需求**: "长短适配有分别的需求，智能模式可以作为开个，或者全局做个开关，并不是完全不需要，默认可以关闭智能，默认短视频风格"

**可行性**: ✅ 极高  
**技术难度**: ⭐⭐  
**现有基础**: 
- `lib/providers/player_settings_provider.dart` 已存在
- 播放模式判断逻辑在 `VideoPlayerPage` 中

**实施方案**:
1. 在 `PlayerSettings` 中新增 `bool enableSmartMode` (默认 false)
2. 修改 `VideoPlayerPage` 判断逻辑：`if (settings.enableSmartMode && duration > 5min)`
3. 设置页增加开关 UI

**代码影响**:
```dart
// 修改：lib/providers/player_settings_provider.dart
class PlayerSettings with ChangeNotifier {
  bool enableSmartMode = false; // 新增，默认关闭
  
  void toggleSmartMode() {
    enableSmartMode = !enableSmartMode;
    notifyListeners();
  }
}

// 修改：lib/ui/pages/video_player_page.dart
final isShortVideo = widget.videoDuration.inMinutes < 5;
final useShortLayout = settings.enableSmartMode 
    ? isShortVideo 
    : settings.forceShortLayout; // 用户手动选择
```

---

#### F3: 设备性能分级
**用户需求**: "可以增加设置，并判断设备性能，为高端设备默认开启，可以手动关闭"

**可行性**: ✅ 中高  
**技术难度**: ⭐⭐  
**现有基础**: 
- `lib/core/utils/device_utils.dart` 可能已有设备信息获取

**实施方案**:
1. 定义性能分级标准 (CPU 核心数、内存、GPU 型号)
2. 启动时检测设备等级 (Low/Mid/High)
3. 根据等级设置特效默认值 (玻璃拟态、缩略图缓存帧数等)
4. 所有特效开关支持手动覆盖

**代码影响**:
```dart
// 新增：lib/core/utils/performance_tier.dart
enum PerformanceTier { low, mid, high }

class PerformanceDetector {
  static PerformanceTier detect() {
    final cores = await ProcessInfo.physicalCpuCount;
    final memory = await SystemMemory.totalPhysicalMemory;
    
    if (cores >= 8 && memory >= 8 * GB) return PerformanceTier.high;
    if (cores >= 4 && memory >= 4 * GB) return PerformanceTier.mid;
    return PerformanceTier.low;
  }
}

// 修改：lib/providers/settings_provider.dart
class AppSettings {
  bool enableGlassmorphism;
  int thumbnailCacheFrames;
  
  AppSettings() {
    final tier = PerformanceDetector.detect();
    enableGlassmorphism = tier == PerformanceTier.high; // 仅高端机默认开启
    thumbnailCacheFrames = tier == PerformanceTier.high ? 8 : 3;
  }
}
```

---

#### F4: 海报墙预览
**用户需求**: "适配预览图有必要，可以在播放视频之前增加一个海报墙效果，瀑布流展示缩略图，可以预览视频内容，可以区分长短视频，开启短视频默认瀑布流，开启长视频默认双列缩略图，附带展示视频格式，时长等等信息"

**可行性**: ✅ 中  
**技术难度**: ⭐⭐⭐  
**现有基础**: 
- `lib/services/thumbnail_service.dart` 支持提取缩略图
- `lib/ui/widgets/video_thumbnail.dart` 已有基础组件

**实施方案**:
1. 创建 `PosterWallView` 组件
2. 支持两种布局：瀑布流 (短视频)、双列网格 (长视频)
3. 缩略图卡片显示：封面、时长、格式、分辨率
4. 点击跳转播放页

**代码影响**:
```dart
// 新增：lib/ui/widgets/poster_wall_view.dart
class PosterWallView extends StatelessWidget {
  final List<VideoFile> videos;
  final bool isShortVideoMode;
  
  @override
  Widget build(BuildContext context) {
    return isShortVideoMode 
        ? _buildWaterfallFlow(videos)  // 瀑布流
        : _buildDualColumnGrid(videos); // 双列网格
  }
  
  Widget _buildVideoCard(VideoFile video) {
    return Stack(
      children: [
        Thumbnail(image: video.thumbnail),
        Positioned(bottom: 8, child: DurationBadge(video.duration)),
        Positioned(top: 8, right: 8, child: FormatBadge(video.format)),
      ],
    );
  }
}
```

---

#### F5: 删除美颜滤镜
**用户需求**: "美艳滤镜可以剔除" → **更正**: "美图模块不动"

**状态**: ❌ **已取消**  
**说明**: 经确认，美图模块 (图片选择/导入 + 图片浏览) 保持现状，本期不做任何改动。

---

### 交互需求

#### I1: 手势优化
**用户需求**: 
- 保持单击暂停，双击点赞
- 左侧竖向滑动改变亮度，右边竖向滑动改变音量
- 横行滑动快进快退
- 截图采用截图按钮
- 竖向滑动需要考虑事件冲突，如果不好实现，可以考虑放到菜单中，或者靠上位置长按触发后再进行滑动，普通滑动依旧为切换视频

**可行性**: ✅ 中  
**技术难度**: ⭐⭐⭐  
**现有基础**: 
- `lib/ui/widgets/gesture_detector_layer.dart` 处理手势

**实施方案**:
1. 保留基础手势 (单击/双击/横滑)
2. 竖滑改为**长按 500ms + 滑动**触发
3. 新增截图按钮悬浮于控制栏
4. 普通竖滑维持切换视频逻辑

**代码影响**:
```dart
// 修改：lib/ui/widgets/gesture_detector_layer.dart
class AdvancedGestureDetector extends StatefulWidget {
  final Duration longPressDuration = Duration(milliseconds: 500);
  
  void _onVerticalDragStart(DragStartDetails details) {
    _longPressTimer = Timer(longPressDuration, () {
      _isFineTuningMode = true;
      HapticFeedback.mediumImpact(); // 触觉反馈
    });
  }
  
  void _onVerticalDragEnd(DragEndDetails details) {
    _longPressTimer?.cancel();
    if (!_isFineTuningMode) {
      // 普通滑动：切换视频
      _switchVideo();
    } else {
      // 长按后滑动：调节音量/亮度
      _applyAdjustment();
    }
    _isFineTuningMode = false;
  }
}
```

---

#### I2: 设置拆分
**用户需求**: "将部分设置项拆分，分为全局设置，放入设置页中，其他的留在播放器"

**可行性**: ✅ 高  
**技术难度**: ⭐⭐  
**现有基础**: 
- `lib/ui/pages/settings_page.dart` 已存在

**实施方案**:
1. 全局设置：主题、语言、性能分级、默认播放模式
2. 播放器内设置：清晰度、字幕、音轨、弹幕开关
3. 播放器设置通过底部弹窗展示

**代码影响**:
```dart
// 修改：lib/ui/pages/settings_page.dart
class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        SettingsGroup(title: '全局设置', children: [
          SmartModeSwitch(),
          PerformanceTierDisplay(),
          ThemeSelector(),
        ]),
        SettingsGroup(title: '关于', children: [
          VersionInfo(),
          OpenSourceLicenses(),
        ]),
      ],
    );
  }
}

// 新增：lib/ui/widgets/player_settings_popup.dart
class PlayerSettingsPopup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BottomSheet(
      child: Column(
        children: [
          QualitySelector(),
          SubtitleSelector(),
          DanmakuToggle(),
        ],
      ),
    );
  }
}
```

---

#### I3: 多端适配
**用户需求**: "为多端进行单独的适配，功能一致，但交互符合平台习惯"

**可行性**: ✅ 中  
**技术难度**: ⭐⭐  
**现有基础**: 
- Flutter 跨平台能力
- `Theme.of(context).platform` 可判断平台

**实施方案**:
1. Desktop: 鼠标悬停显示控件，支持键盘快捷键
2. Mobile: 触摸手势为主，隐藏式控制栏
3. 针对不同平台调整控件尺寸、间距

**代码影响**:
```dart
// 修改：lib/ui/pages/video_player_page.dart
final isDesktop = Theme.of(context).platform == TargetPlatform.desktop;

return Stack(
  children: [
    VideoLayer(),
    if (isDesktop)
      DesktopControlBar(hoverToShow: true) // 悬停显示
    else
      MobileControlBar(tapToToggle: true), // 点击显示
  ],
);

// 新增：lib/core/utils/platform_extensions.dart
extension PlatformX on BuildContext {
  bool get isDesktop => Theme.of(this).platform == TargetPlatform.desktop;
  bool get isMobile => Theme.of(this).platform == TargetPlatform.android || 
                       Theme.of(this).platform == TargetPlatform.iOS;
}
```

---

### 建议需求

#### S1: 文件夹管理
**用户需求**: "缺少文件夹管理，可以将包含媒体的文件夹在首页展示，取最后一次播放的媒体缩略图作为封面，如果没有播放过，默认第一个媒体的缩略图"

**可行性**: ✅ 中  
**技术难度**: ⭐⭐⭐  
**现有基础**: 
- `lib/services/file_service.dart` 提供文件扫描

**实施方案**:
1. 创建 `FolderHomePage` 作为新首页
2. 扫描媒体文件夹，按最后播放时间排序
3. 封面逻辑：优先最后播放视频缩略图 → 第一个视频缩略图
4. 点击进入文件夹视图

**代码影响**:
```dart
// 新增：lib/ui/pages/folder_home_page.dart
class FolderHomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MediaFolder>>(
      stream: FileService().watchFolders(),
      builder: (context, snapshot) {
        return GridView.builder(
          itemCount: snapshot.data.length,
          itemBuilder: (context, index) {
            final folder = snapshot.data[index];
            final cover = folder.lastPlayedVideo?.thumbnail 
                       ?? folder.videos.first.thumbnail;
            return FolderCard(folder: folder, cover: cover);
          },
        );
      },
    );
  }
}
```

---

#### S2: 首页迁移
**用户需求**: "原本的首页可以放置在第二个 tab，作为功能迁移的兼容项，后续慢慢做功能及 ui 的优化"

**可行性**: ✅ 高  
**技术难度**: ⭐⭐  
**现有基础**: 
- `lib/app.dart` 使用 `BottomNavigationBar`

**实施方案**:
1. 主 Tab: 文件夹管理 (新首页)
2. Tab2: 原视频列表 (兼容模式)
3. 使用 `IndexedStack` 保持状态

**代码影响**:
```dart
// 修改：lib/app.dart
class XiaodouyinApp extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          FolderHomePage(),  // Tab 1: 新首页
          VideoListPage(),   // Tab 2: 原首页
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: '文件夹'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: '视频'),
        ],
      ),
    );
  }
}
```

---

## 🗺️ 实施路线图

### Phase 1: 配置化改造 (T+1 ~ T+4)
**目标**: 完成可配置化基础建设

| 任务 | 工时 | 负责人 | 交付物 |
|------|------|--------|--------|
| 智能模式开关化 | 1d | - | `PlayerSettings.enableSmartMode` |
| 设置页拆分准备 | 2d | - | 全局/播放器设置分离架构 |
| 性能检测接口 | 1d | - | `PerformanceDetector` 工具类 |

**里程碑**: 用户可手动关闭智能模式，设置页结构清晰

---

### Phase 2: 核心功能增强 (T+5 ~ T+12)
**目标**: 完成用户强需求功能

| 任务 | 工时 | 负责人 | 交付物 |
|------|------|--------|--------|
| XML 弹幕解析器 | 3d | - | `DanmakuXmlParser` |
| 文件夹管理首页 | 3d | - | `FolderHomePage` |
| 海报墙预览组件 | 2d | - | `PosterWallView` |

**里程碑**: 支持本地弹幕、文件夹浏览、视频预览

---

### Phase 3: 交互与适配 (T+13 ~ T+19)
**目标**: 提升交互体验和跨平台一致性

| 任务 | 工时 | 负责人 | 交付物 |
|------|------|--------|--------|
| 手势冲突解决 | 2d | - | 长按触发机制 |
| 多端交互适配 | 3d | - | Desktop/Mobile 差异化 |
| 截图按钮集成 | 1d | - | 独立截图入口 |
| 性能分级应用 | 1d | - | 动态特效默认值 |

**里程碑**: 手势操作流畅，多端体验统一

---

### Phase 4: 测试与发布 (T+20 ~ T+25)
**目标**: 确保质量并发布 v2.0

| 任务 | 工时 | 负责人 | 交付物 |
|------|------|--------|--------|
| 低端机性能测试 | 2d | - | 性能分级阈值表 |
| 全功能回归测试 | 2d | - | 测试报告 |
| Bug 修复 | 1d | - | 稳定版本 |
| 发布 v2.0 | 0.5d | - | Release Note |

**里程碑**: v2.0 正式上线

---

## 💻 代码级实施方案

### 文件清单

#### 新增文件
```
lib/
├── services/
│   ├── danmaku_xml_parser.dart       # XML 弹幕解析器
│   └── performance_detector.dart     # 性能检测工具
├── ui/
│   ├── pages/
│   │   ├── folder_home_page.dart     # 文件夹管理首页
│   │   └── settings_page.dart        # 重构后的设置页
│   └── widgets/
│       ├── poster_wall_view.dart     # 海报墙组件
│       ├── player_settings_popup.dart # 播放器内设置弹窗
│       └── screenshot_button.dart    # 截图按钮
└── core/
    └── utils/
        └── platform_extensions.dart  # 平台扩展工具
```

#### 修改文件
```
lib/
├── services/
│   └── danmaku_service.dart          # 扩展支持 XML 加载
├── providers/
│   ├── player_settings_provider.dart # 新增智能模式开关
│   └── app_settings_provider.dart    # 新增性能分级逻辑
├── ui/
│   ├── pages/
│   │   ├── video_player_page.dart    # 适配新手势和双模式
│   │   └── app.dart                  # 新增 Tab2
│   └── widgets/
│       └── gesture_detector_layer.dart # 重构手势逻辑
└── main.dart                         # 启动时检测设备性能
```

---

### 关键代码示例

#### 1. XML 弹幕解析器
```dart
// lib/services/danmaku_xml_parser.dart
import 'dart:io';
import 'xml/xml.dart';

class DanmakuXmlParser {
  Future<List<DanmakuComment>> parse(File xmlFile) async {
    final content = await xmlFile.readAsString();
    final document = XmlDocument.parse(content);
    
    return document.findAllElements('d').map((elem) {
      final time = double.parse(elem.getAttribute('p')!.split(',')[0]);
      final text = elem.innerText;
      return DanmakuComment(
        time: Duration(seconds: time.toInt()),
        content: text,
        type: _parseType(elem.getAttribute('p')),
      );
    }).toList();
  }
  
  DanmakuType _parseType(String? pAttr) {
    // 解析 Bilibili XML 格式
    final typeCode = int.parse(pAttr!.split(',')[1]);
    switch (typeCode) {
      case 1: return DanmakuType.scroll;
      case 4: return DanmakuType.bottom;
      case 5: return DanmakuType.top;
      default: return DanmakuType.scroll;
    }
  }
}
```

#### 2. 长按触发手势
```dart
// lib/ui/widgets/gesture_detector_layer.dart
class AdvancedGestureDetector extends StatefulWidget {
  @override
  State createState() => _AdvancedGestureDetectorState();
}

class _AdvancedGestureDetectorState extends State<AdvancedGestureDetector> {
  Timer? _longPressTimer;
  bool _isFineTuningMode = false;
  
  void _onVerticalDragStart(DragStartDetails details) {
    _longPressTimer = Timer(Duration(milliseconds: 500), () {
      setState(() => _isFineTuningMode = true);
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('进入精细调节模式'), duration: Duration(seconds: 1)),
      );
    });
  }
  
  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isFineTuningMode) {
      // 调节音量/亮度
      _adjustVolumeOrBrightness(details.delta.dy);
    }
    // 否则忽略，等待结束处理切换视频
  }
  
  void _onVerticalDragEnd(DragEndDetails details) {
    _longPressTimer?.cancel();
    if (!_isFineTuningMode) {
      _switchVideo(details.velocity.pixelsPerSecond.dy);
    }
    setState(() => _isFineTuningMode = false);
  }
}
```

#### 3. 海报墙组件
```dart
// lib/ui/widgets/poster_wall_view.dart
class PosterWallView extends StatelessWidget {
  final List<VideoFile> videos;
  final bool preferWaterfall;
  
  @override
  Widget build(BuildContext context) {
    if (preferWaterfall) {
      return MasonryGridView.count(
        crossAxisCount: 2,
        itemCount: videos.length,
        itemBuilder: (context, index) => _VideoCard(videos[index]),
      );
    } else {
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 16 / 9,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) => _VideoCard(videos[index]),
      );
    }
  }
}

class _VideoCard extends StatelessWidget {
  final VideoFile video;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(video.thumbnailData, fit: BoxFit.cover),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatDuration(video.duration),
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Chip(
            label: Text(video.format.toUpperCase(), style: TextStyle(fontSize: 10)),
            backgroundColor: Colors.blueAccent,
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
```

---

## ⚠️ 风险评估与应对

| 风险 | 概率 | 影响 | 应对措施 |
|------|------|------|----------|
| **XML 格式不兼容** | 中 | 高 | 支持多种弹幕格式 (Bilibili/Ass)，增加容错处理 |
| **手势识别误触** | 高 | 中 | 提供灵敏度调节，增加触觉反馈确认 |
| **低端机海报墙卡顿** | 中 | 高 | 懒加载 + 缩略图预生成，限制同时渲染数量 |
| **文件夹扫描慢** | 高 | 中 | 后台异步扫描 + 增量更新，添加进度提示 |
| **多端适配工作量大** | 中 | 中 | 优先保证 Mobile 体验，Desktop 逐步完善 |
| **用户不适应新手势** | 高 | 低 | 首次使用引导动画，设置中提供"经典模式"回退 |

---

## 🧪 测试计划

### 单元测试
- `DanmakuXmlParser`: 解析各种 XML 格式
- `PerformanceDetector`: 不同设备模拟测试
- `GestureDetector`: 手势边界条件

### 集成测试
- 文件夹浏览 → 选择视频 → 播放流程
- 弹幕加载 → 渲染 → 交互流程
- 设置修改 → 立即生效验证

### 性能测试
| 设备等级 | 测试项 | 目标 |
|----------|--------|------|
| **低端** (2GB RAM) | 海报墙滚动 FPS | ≥ 30fps |
| **中端** (4GB RAM) | 弹幕渲染 CPU | ≤ 15% |
| **高端** (8GB+ RAM) | 玻璃拟态功耗 | ≤ 5%/h |

### 用户体验测试
- 找 5 位非技术背景用户试用
- 记录 30 秒内学会基本操作的比例
- 收集手势误触反馈

---

## 📦 发布计划

### v2.0.0-alpha (T+12)
- 内部测试版
- 包含 Phase 1 & 2 功能
- 范围：开发团队 + 核心用户

### v2.0.0-beta (T+19)
- 公开测试版
- 包含全部功能
- 范围：GitHub Releases + 测试群

### v2.0.0 (T+25)
- 正式版
- 全渠道发布
- 更新日志重点突出"用户主导重构"

---

## 📝 更新日志 (草案)

```markdown
## v2.0.0 - User-Centric Release

### 🎉 新功能
- **本地弹幕**: 支持加载同名 XML 弹幕文件，完美适配弹幕盒子
- **文件夹管理**: 首页全新改版，按文件夹浏览媒体库
- **海报墙预览**: 播放前快速预览，短视频瀑布流/长视频双列布局
- **性能分级**: 自动检测设备性能，智能调整特效默认值

### ⚙️ 优化
- **智能模式开关化**: 默认关闭，把选择权还给用户
- **手势优化**: 长按触发精细调节，避免误操作
- **设置拆分**: 全局设置与播放器设置分离，查找更便捷
- **多端适配**: Desktop 键鼠优化，Mobile 触摸优化

### 🐛 修复
- 修复竖滑手势与切换视频冲突问题
- 修复低端设备玻璃拟态卡顿问题

### ⚠️ 已知问题
- 部分 Ass 格式弹幕兼容性待完善 (v2.0.1 修复)

### 💡 特别说明
- 美图模块保持不变，感谢用户反馈
```

---

## 🎯 成功标准

1. **功能完整性**: 所有计划功能 100% 实现
2. **性能达标**: 低端机海报墙滚动≥30fps
3. **用户满意度**: 测试用户 30 秒学会基本操作比例≥80%
4. **零严重 Bug**: 发布前无 P0/P1 级别问题
5. **代码质量**: 新增代码测试覆盖率≥70%

---

## 📞 联系方式

如有问题或建议，请提交 Issue 至 GitHub 仓库。

**Let's build a user-centric video player together!** 🚀
