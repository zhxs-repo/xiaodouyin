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

  Future<String> fetchVideoUrl(String categoryId) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    try {
      final response = await _dio.get(
        AppConstants.videoApiBaseUrl,
        queryParameters: {'type': 'json', 'id': categoryId, 't': ts},
      );
      if (response.statusCode == 400) {
        throw Exception('请求参数错误(400)，请检查分类ID是否有效');
      }
      return _parseMediaUrl(response.data);
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    }
  }

  Future<String> fetchImageUrl(String categoryId) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    try {
      final response = await _dio.get(
        AppConstants.imageApiBaseUrl,
        queryParameters: {'category': categoryId, 'type': 'json', 't': ts},
      );
      if (response.statusCode == 400) {
        throw Exception('请求参数错误(400)，请检查分类ID是否有效');
      }
      return _parseMediaUrl(response.data);
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

  String _parseMediaUrl(dynamic data) {
    if (data is String) return data;
    if (data is Map) {
      return data['link']?.toString() ??
             data['url']?.toString() ??
             data['data']?.toString() ??
             data['video_url']?.toString() ?? '';
    }
    return data.toString();
  }
}
