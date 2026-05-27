import 'package:flutter/material.dart';
import 'video_player_page.dart';
import 'beauty_page.dart';
import 'online_page.dart';

class PasswordPage extends StatefulWidget {
  final String mode;
  final String password;

  const PasswordPage({super.key, required this.mode, required this.password});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  String _input = '';
  String _modeLabel = '';
  int _errorCount = 0;
  bool _isLocked = false; // 错误次数过多时锁定输入

  @override
  void initState() {
    super.initState();
    switch (widget.mode) {
      case 'video': _modeLabel = '视频模式'; break;
      case 'beauty': _modeLabel = '美图模式'; break;
      case 'online': _modeLabel = '在线模式'; break;
    }
  }

  void _onDigitPress(String digit) {
    if (_isLocked) return;
    setState(() => _input += digit);
  }

  void _onDelete() {
    if (_input.isNotEmpty) setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _onConfirm() {
    if (_isLocked) return;
    if (_input == widget.password) {
      _navigateToMode();
    } else {
      _errorCount++;
      setState(() => _input = '');
      if (_errorCount >= 3) {
        // 错误3次后锁定3秒
        setState(() => _isLocked = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('错误次数过多，请3秒后重试'), duration: Duration(seconds: 3)));
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isLocked = false;
              _errorCount = 0;
            });
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('密码错误'), duration: Duration(seconds: 1)));
      }
    }
  }

  void _navigateToMode() {
    Widget page;
    switch (widget.mode) {
      case 'video': page = const VideoPlayerPage(); break;
      case 'beauty': page = const BeautyPage(); break;
      case 'online': page = const OnlinePage(); break;
      default: page = const VideoPlayerPage();
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.black,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          tooltip: '返回',
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Text(_modeLabel, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text('请输入密码', style: TextStyle(fontSize: 16, color: Colors.white54)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _input.length ? Colors.white : Colors.white24,
                      ),
                    )),
                  ),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          for (final d in ['1','2','3','4','5','6','7','8','9'])
                            _buildDigitButton(d),
                          _buildDigitButton('0'),
                          _buildActionButton('⌫', _onDelete),
                          _buildActionButton('✓', _onConfirm),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDigitButton(String digit) => ElevatedButton(
    onPressed: () => _onDigitPress(digit),
    style: ElevatedButton.styleFrom(shape: const CircleBorder(), backgroundColor: Colors.white10),
    child: Text(digit, style: const TextStyle(fontSize: 24, color: Colors.white)),
  );

  Widget _buildActionButton(String label, VoidCallback onPressed) => ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(shape: const CircleBorder(), backgroundColor: Colors.white12),
    child: Text(label, style: const TextStyle(fontSize: 20, color: Colors.white)),
  );
}
