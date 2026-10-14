import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaodouyin/data/models/xml_danmaku.dart';
import 'package:xiaodouyin/providers/danmaku_provider.dart';

XmlDanmaku _d(String text, double time, [XmlDanmakuMode mode = XmlDanmakuMode.scroll]) =>
    XmlDanmaku(
      text: text,
      timeSec: time,
      mode: mode,
      colorValue: 0xFFFF0000,
      fontSize: 25,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('DanmakuProvider 时间轴弹幕', () {
    test('按视频时间逐条进入显示队列', () {
      final dp = DanmakuProvider()
        ..loadTimeline([_d('a', 1), _d('b', 2), _d('c', 3)], sourcePath: r'D:\x\视频.xml');
      dp.start();
      addTearDown(dp.stop);

      expect(dp.timelineSource, '视频.xml');
      expect(dp.activeBullets, isEmpty);

      dp.syncTimeline(2.5);
      expect(dp.activeBullets.map((b) => b.text), ['a', 'b']);

      dp.syncTimeline(3.0);
      expect(dp.activeBullets.map((b) => b.text), ['a', 'b', 'c']);
    });

    test('弹幕属性来自 XML 而非全局配置', () {
      final dp = DanmakuProvider()
        ..loadTimeline([
          _d('顶部', 1, XmlDanmakuMode.top),
          _d('底部', 2, XmlDanmakuMode.bottom),
        ], sourcePath: 'x.xml');
      dp.start();
      addTearDown(dp.stop);

      dp.syncTimeline(2.0);
      final bullets = dp.activeBullets;
      expect(bullets.map((b) => b.position),
          [DanmakuPosition.top, DanmakuPosition.bottom]);
      expect(bullets.first.colorValue, 0xFFFF0000);
      // 固定弹幕只在顶部/底部区域取行，不能按滚动弹幕的行数铺开
      expect(bullets.every((b) => b.row < 3), isTrue);
    });

    test('大跨度前进只显示临近时间的弹幕，向后跳转清屏后重新起播', () {
      final dp = DanmakuProvider()
        ..loadTimeline([_d('a', 1), _d('b', 10), _d('c', 20)], sourcePath: 'x.xml');
      dp.start();
      addTearDown(dp.stop);

      dp.syncTimeline(21);
      expect(dp.activeBullets.map((b) => b.text), ['c']);

      dp.syncTimeline(9);
      expect(dp.activeBullets, isEmpty);

      dp.syncTimeline(10.5);
      expect(dp.activeBullets.map((b) => b.text), ['b']);
    });

    test('向前跳转途中经过的弹幕不补发', () {
      final dp = DanmakuProvider()
        ..loadTimeline([_d('a', 1), _d('b', 2), _d('c', 3)], sourcePath: 'x.xml');
      dp.start();
      addTearDown(dp.stop);

      dp.syncTimeline(1.0);
      dp.syncTimeline(100);
      expect(dp.activeBullets.length, 1);
    });

    test('弹幕关闭期间只推进游标，重新开启不倾泻历史弹幕', () {
      final dp = DanmakuProvider()
        ..loadTimeline([for (var i = 1; i <= 5; i++) _d('$i', i.toDouble())], sourcePath: 'x.xml');

      dp.syncTimeline(5);
      expect(dp.activeBullets, isEmpty);

      dp.start();
      addTearDown(dp.stop);
      dp.syncTimeline(5.2);
      expect(dp.activeBullets, isEmpty);

      dp.loadTimeline([_d('late', 8)], sourcePath: 'x.xml');
      dp.syncTimeline(8.5);
      expect(dp.activeBullets.map((b) => b.text), ['late']);
    });

    test('命中屏蔽词的时间轴弹幕被丢弃', () {
      final dp = DanmakuProvider()
        ..loadTimeline([_d('广告内容', 1), _d('正常', 2)], sourcePath: 'x.xml');
      dp.updateConfig(dp.config.copyWith(blocklist: ['广告']));
      dp.start();
      addTearDown(dp.stop);

      dp.syncTimeline(2.5);
      expect(dp.activeBullets.map((b) => b.text), ['正常']);
    });

    test('clearTimeline 卸载后不再产生弹幕', () {
      final dp = DanmakuProvider()
        ..loadTimeline([_d('a', 1)], sourcePath: 'x.xml');
      dp.start();
      addTearDown(dp.stop);

      dp.clearTimeline();
      expect(dp.timelineCount, 0);
      expect(dp.timelineSource, isNull);

      dp.syncTimeline(1);
      expect(dp.activeBullets, isEmpty);
    });
  });
}
