import 'dart:convert';
import 'package:flutter/material.dart';
import '../../data/services/storage_service.dart';
import '../../core/constants/storage_keys.dart';

class _Note {
  final String id;
  String content;
  _Note(this.id, this.content);

  Map<String, dynamic> toJson() => {'id': id, 'content': content};
  factory _Note.fromJson(Map<String, dynamic> json) =>
      _Note(json['id'] as String, json['content'] as String);
}

class NotebookPage extends StatefulWidget {
  const NotebookPage({super.key});

  @override
  State<NotebookPage> createState() => _NotebookPageState();
}

class _NotebookPageState extends State<NotebookPage> {
  List<_Note> _notes = [];
  bool _isLoading = true;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final storage = await StorageService.getInstance();
    final saved = storage.getStringList(StorageKeys.videoNotebook);
    if (mounted) {
      setState(() {
        if (saved != null) {
          _notes = saved.map((s) {
            try {
              return _Note.fromJson(jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              // 兼容旧格式：纯文本字符串
              return _Note('${_nextId++}', s);
            }
          }).toList();
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveNotes() async {
    final storage = await StorageService.getInstance();
    final data = _notes.map((n) => jsonEncode(n.toJson())).toList();
    await storage.setStringList(StorageKeys.videoNotebook, data);
  }

  void _addNote() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加笔记'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '输入笔记内容...'),
          onSubmitted: (_) => Navigator.pop(ctx),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _notes.add(_Note('${_nextId++}', text)));
                _saveNotes();
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _deleteNote(int index) {
    setState(() => _notes.removeAt(index));
    _saveNotes();
  }

  void _editNote(int index) {
    final controller = TextEditingController(text: _notes[index].content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑笔记'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _notes[index].content = text);
                _saveNotes();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('笔记本')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(child: Text('暂无笔记', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, index) => Dismissible(
                    key: ValueKey(_notes[index].id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Colors.red.withValues(alpha: 0.3),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteNote(index),
                    child: ListTile(
                      title: Text(_notes[index].content, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      leading: Text('${index + 1}', style: const TextStyle(color: Colors.white38)),
                      onTap: () => _editNote(index),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: const Icon(Icons.add),
      ),
    );
  }
}
