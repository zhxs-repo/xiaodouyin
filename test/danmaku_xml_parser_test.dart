import 'package:flutter_test/flutter_test.dart';
import 'package:xiaodouyin/data/models/xml_danmaku.dart';
import 'package:xiaodouyin/data/services/danmaku_xml_parser.dart';

void main() {
  group('DanmakuXmlParser.parse', () {
    test('解析标准 B 站弹幕并返回视频时间轴数据', () {
      const xml = '''
<i>
  <bulletav time="0" cid="1" />
  <d p="12.5,1,25,16777215,1700000000,0,12345,6,1">普通滚动</d>
  <d p="3.25,5,18,16711680,1700000001,0,12346,6,1">顶部</d>
  <d p="8.0,4,16,255,1700000002,0,12347,6,1">底部</d>
</i>
''';
      final result = DanmakuXmlParser.parse(xml);

      expect(result.map((d) => d.text), ['顶部', '底部', '普通滚动']);
      final first = result.first;
      expect(first.timeSec, 3.25);
      expect(first.mode, XmlDanmakuMode.top);
      expect(first.fontSize, 18.0);
      expect(first.colorValue, 0xFFFF0000); // XML 存 24 位 RGB，需补 alpha
      expect(result.last.colorValue, 0xFFFFFFFF);
    });

    test('逆向与高级弹幕降级为滚动，特殊标签被忽略', () {
      const xml = '''
<i>
  <d p="1.0,6,25,16777215,0,0,0,0,1">逆向</d>
  <d p="2.0,9,25,16777215,0,0,0,0,1">高级</d>
  <e p="1,2,3">特效</e>
  <d>缺少 p 属性</d>
  <d p="1,2">字段不足</d>
  <d p="abc,1,25,0,0,0,0,0,1">时间非法</d>
  <d p="5.0,1,25,0,0,0,0,0,1">   </d>
</i>
''';
      final result = DanmakuXmlParser.parse(xml);

      expect(result.map((d) => d.text), ['逆向', '高级']);
      expect(result.every((d) => d.mode == XmlDanmakuMode.scroll), isTrue);
    });

    test('非 XML 内容与根标签不匹配时返回空列表', () {
      expect(DanmakuXmlParser.parse('<not-an-i><d p="1,1,1,1"/></not-an-i>'), isEmpty);
      expect(DanmakuXmlParser.parse('完全不是 xml<<<'), isEmpty);
      expect(DanmakuXmlParser.parse(''), isEmpty);
    });

    test('弹幕按出现时间升序排列', () {
      const xml = '<i>'
          '<d p="9.0,1,25,16777215,0,0,0,0,1">c</d>'
          '<d p="1.0,1,25,16777215,0,0,0,0,1">a</d>'
          '<d p="5.0,1,25,16777215,0,0,0,0,1">b</d>'
          '</i>';
      expect(DanmakuXmlParser.parse(xml).map((d) => d.timeSec), [1.0, 5.0, 9.0]);
    });
  });

  group('DanmakuXmlParser.xmlPathFor', () {
    test(r'把视频扩展名替换为 .xml', () {
      expect(DanmakuXmlParser.xmlPathFor(r'D:\videos\a\b.mp4'), r'D:\videos\a\b.xml');
      expect(DanmakuXmlParser.xmlPathFor('/data/noext'), '/data/noext.xml');
    });
  });
}
