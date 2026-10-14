import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../models/online_category.dart';

class OnlineApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0',
    },
    validateStatus: (status) => status != null && status < 500,
  ));

  Future<String> fetchVideoUrl(String categoryId) => _fetchMediaUrl(
        AppConstants.videoApiBaseUrl,
        {'id': categoryId},
        '视频',
      );

  Future<String> fetchImageUrl(String categoryId) => _fetchMediaUrl(
        AppConstants.imageApiBaseUrl,
        {'category': categoryId},
        '图片',
      );

  /// 取一条真正能访问的图片链接。上游会偶发返回已失效的CDN链接(404)，
  /// 这里用HEAD预校验，最多重试3次，避免坏链接进入列表。
  Future<String> fetchAliveImageUrl(String categoryId) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      final url = await fetchImageUrl(categoryId);
      if (await isMediaUrlAlive(url)) return url;
    }
    throw Exception('图片链接暂时不可用，请稍后重试');
  }

  Future<bool> isMediaUrlAlive(String url) async {
    try {
      final response = await _dio.head(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          sendTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
        ),
      );
      final statusCode = response.statusCode ?? 0;
      return statusCode >= 200 && statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  Future<String> _fetchMediaUrl(
    String baseUrl,
    Map<String, dynamic> params,
    String kindLabel,
  ) async {
    final query = {...params, 'type': 'json', 't': DateTime.now().millisecondsSinceEpoch};
    try {
      final response = await _dio.get(baseUrl, queryParameters: query);
      if (response.statusCode == 400) {
        throw Exception('请求参数错误(400)，请检查分类ID是否有效');
      }
      final data = response.data;
      if (data is Map) {
        final code = data['code']?.toString();
        if (code != null && code != '1' && code != '200') {
          throw Exception(data['msg']?.toString() ?? '接口返回失败(code=$code)');
        }
        final url = _extractUrl(data);
        if (url.isNotEmpty) return url;
      }
      if (data is String && data.trim().isNotEmpty) return data.trim();
      throw Exception('未获取到 $kindLabel 链接');
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查网络';
      case DioExceptionType.receiveTimeout:
        return '响应超时，请稍后重试';
      case DioExceptionType.sendTimeout:
        return '发送超时，请检查网络';
      case DioExceptionType.connectionError:
        return '网络连接失败，请检查网络设置';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        return '服务器错误($statusCode)，请稍后重试';
      default:
        return '网络请求失败：${e.message}';
    }
  }

  List<OnlineCategory> getVideoCategories() {
    return AppConstants.videoCategories
        .map((c) => OnlineCategory(
              id: c['id'] as String,
              name: c['name'] as String,
              type: CategoryType.video,
            ))
        .toList();
  }

  List<OnlineCategory> getImageCategories() {
    return AppConstants.imageCategories
        .map((c) => OnlineCategory(
              id: c['id'] as String,
              name: c['name'] as String,
              type: CategoryType.image,
            ))
        .toList();
  }

  String _extractUrl(Map data) {
    final inner = data['data'];
    final candidates = <dynamic>[
      if (inner is Map) inner['link'],
      data['link'],
      data['url'],
      data['video_url'],
      if (inner is String) inner,
      if (inner is Map) inner['url'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.startsWith('http')) return value;
    }
    return '';
  }
}
