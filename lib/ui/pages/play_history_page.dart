import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/resume_provider.dart';
import '../../data/models/play_history.dart';
import '../../core/utils/toast_util.dart';

class PlayHistoryPage extends StatelessWidget {
  const PlayHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('播放历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清空历史',
            onPressed: () => _showClearAllConfirm(context),
          ),
        ],
      ),
      body: Consumer<ResumeProvider>(
        builder: (context, resume, _) {
          final history = resume.history;
          if (history.isEmpty) {
            return Center(
              child: Text('暂无播放记录', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16)),
            );
          }
          // 按时间倒序排列
          final sortedEntries = history.entries.toList()
            ..sort((a, b) => b.value.timestamp.compareTo(a.value.timestamp));

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: sortedEntries.length,
            itemBuilder: (context, index) {
              final entry = sortedEntries[index];
              return _buildHistoryItem(context, entry.key, entry.value, resume);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, String path, PlayHistoryRecord record, ResumeProvider resume) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileName = path.split('/').last.split(r'\').last;
    final progress = record.duration.inMilliseconds > 0
        ? record.position.inMilliseconds / record.duration.inMilliseconds
        : 0.0;
    final timeStr = _formatTimeAgo(record.timestamp);

    return Dismissible(
      key: Key(path),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: colorScheme.error,
        child: Icon(Icons.delete, color: colorScheme.onError),
      ),
      onDismissed: (_) => resume.clearRecord(path),
      child: ListTile(
        title: Text(fileName, style: TextStyle(color: colorScheme.onSurface, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress, backgroundColor: colorScheme.surfaceContainerHighest, color: colorScheme.primary),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_formatDuration(record.position)} / ${_formatDuration(record.duration)}', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
                Text(timeStr, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: colorScheme.onSurfaceVariant, size: 18),
          onPressed: () async {
            await resume.clearRecord(path);
            if (context.mounted) ToastUtil.show(context, '已删除记录');
          },
        ),
      ),
    );
  }

  void _showClearAllConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('清空历史'),
          content: const Text('确定清空所有播放记录吗？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await context.read<ResumeProvider>().clearAll();
                if (context.mounted) ToastUtil.show(context, '已清空历史');
              },
              child: Text('清空', style: TextStyle(color: colorScheme.error)),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) return '${d.inHours}:$m:$s';
    return '$m:$s';
  }

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}
