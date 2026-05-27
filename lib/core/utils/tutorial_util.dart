import 'package:flutter/material.dart';

/// 操作教程对话框
void showTutorialDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.grey.shade900,
      insetPadding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(child: Text('操作教程', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 18), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
          ),
          // 内容
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('核心操作'),
                  _item('上下滑动', '切换上一个/下一个视频'),
                  _item('单击屏幕', '暂停/继续播放（UI隐藏时恢复显示）'),
                  _item('双击屏幕', '点赞（红心飘浮动画）'),
                  _item('右滑屏幕', '截取当前帧'),
                  _section('右侧操作栏'),
                  _item('收藏红心', '收藏/取消收藏当前视频'),
                  _item('倍速', '选择播放倍速(0.25x~5.0x)'),
                  _item('旋转', '三态切换：竖屏→横屏1.8x→横屏2.24x'),
                  _item('弹幕', '开启/关闭弹幕显示'),
                  _item('更多', '下一个/删除/跳转/定时器/笔记本/手势模式'),
                  _section('底部信息栏'),
                  _item('视频信息', '显示当前视频名（可调透明度）'),
                  _item('进度条', '显示播放进度，可拖拽跳转'),
                  _section('顶部栏'),
                  _item('列表按钮', '打开视频列表（搜索/筛选/去重）'),
                  _item('设置按钮', '打开设置面板'),
                  _section('视频列表'),
                  _item('搜索框', '按文件名/博主名搜索'),
                  _item('列数切换', '2~6列网格展示'),
                  _item('重复检测', '查找同名重复视频'),
                  _item('博主筛选', '按博主分组'),
                  _item('长按视频项', '删除视频（需确认）'),
                  _section('密码入口'),
                  _item('99', '进入视频模式'),
                  _item('88', '进入美图模式'),
                  _item('77', '进入在线模式'),
                  _section('文件命名规则'),
                  _item('格式', '博主名_抖音ID_日期_序号.mp4'),
                  _item('示例', '小美_abc123_20240101_1.mp4'),
                  _section('存储路径'),
                  _item('视频目录', '可在设置中自定义'),
                  _item('图片目录', '可在设置中自定义'),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _section(String title) => Padding(
  padding: const EdgeInsets.only(top: 12, bottom: 4),
  child: Text(title, style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.bold)),
);

Widget _item(String label, String desc) => Padding(
  padding: const EdgeInsets.only(left: 8, bottom: 2),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 80,
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
      Expanded(
        child: Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ),
    ],
  ),
);
