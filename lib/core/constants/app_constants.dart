class AppConstants {
  static const String appName = '小抖音';
  
  // API
  static const String videoApiBaseUrl = 'https://api.mmp.cc/api/ksvideo';
  static const String imageApiBaseUrl = 'https://api.mmp.cc/api/kswallpaper';
  
  // 视频格式
  static const List<String> videoExtensions = ['.mp4', '.avi', '.mkv', '.flv', '.wmv'];
  static const List<String> imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
  static const List<String> audioExtensions = ['.mp3'];
  
  // 目录名
  static const String videoDirName = '.视频文件';
  static const String imageDirName = '.图片文件';
  static const String videoThumbDirName = '缓存/视频缩略图';
  static const String imageThumbDirName = '缓存/图片缩略图';
  static const String dataDirName = '小抖音/数据';
  
  // 在线视频分类 (15类，YuZu已下线)
  static const List<Map<String, dynamic>> videoCategories = [
    {'id': 'jk', 'name': 'JK'},
    {'id': 'YuMeng', 'name': '欲梦'},
    {'id': 'NvDa', 'name': '女大'},
    {'id': 'NvGao', 'name': '女高'},
    {'id': 'ReWu', 'name': '热舞'},
    {'id': 'QingCun', 'name': '清纯'},
    {'id': 'SheJie', 'name': '蛇姐'},
    {'id': 'ChuanDa', 'name': '穿搭'},
    {'id': 'GaoZhiLiangXiaoJieJie', 'name': '高质量小姐姐'},
    {'id': 'HanFu', 'name': '汉服'},
    {'id': 'HeiSi', 'name': '黑丝'},
    {'id': 'BianZhuang', 'name': '变装'},
    {'id': 'LuoLi', 'name': '萝莉'},
    {'id': 'TianMei', 'name': '甜美'},
    {'id': 'BaiSi', 'name': '白丝'},
  ];
  
  // 在线图片分类 (11类，复用4个API分类id)
  static const List<Map<String, dynamic>> imageCategories = [
    {'id': 'kuaishou', 'name': '快手网红'},
    {'id': 'taobao', 'name': '淘宝买家秀'},
    {'id': 'meizi', 'name': '随机妹子'},
    {'id': 'cos', 'name': 'Cosplay'},
    {'id': 'meizi', 'name': '丝袜妹子'},
    {'id': 'cos', 'name': '精品Cos'},
    {'id': 'kuaishou', 'name': '网红壁纸'},
    {'id': 'taobao', 'name': '穿搭买家秀'},
    {'id': 'meizi', 'name': '高清妹子'},
    {'id': 'kuaishou', 'name': '快手壁纸'},
    {'id': 'cos', 'name': '动漫Cos'},
  ];
  
  // 倍速选项 (0.25x - 5x)
  static const List<double> playbackRates = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 5.0];
  
  // 收藏数阈值(自动导出)
  static const int favoriteAutoExportThreshold = 50;
}
