import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TmdbLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final maskedHeaders = Map<String, dynamic>.from(options.headers);
    if (maskedHeaders.containsKey('Authorization')) {
      maskedHeaders['Authorization'] = 'Bearer ***';
    }
    debugPrint('[TMDB 요청] ${options.method} ${options.uri}');
    debugPrint('[TMDB 요청 Header] $maskedHeaders');
    if (options.queryParameters.isNotEmpty) {
      debugPrint('[TMDB 요청 Query] ${options.queryParameters}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[TMDB 응답] ${response.statusCode} ${response.requestOptions.uri}',
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['results'] is List) {
      // 페이지 응답은 Body가 길어서 콘솔에서 잘리므로 모양을 먼저 남긴다.
      debugPrint(
        '[TMDB 응답 요약] page=${data['page']}/${data['total_pages']}, '
        'results=${(data['results'] as List).length}',
      );
    }
    debugPrint('[TMDB 응답 Body] $data');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[TMDB 오류] ${err.requestOptions.uri}');
    debugPrint(
      '[TMDB 오류 내용] ${err.type.name} '
      'status=${err.response?.statusCode} ${err.message}',
    );
    handler.next(err);
  }
}
