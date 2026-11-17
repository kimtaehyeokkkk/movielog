import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// debug 전용 MovieLog 요청 로그. 한 요청을 한두 줄로 남기고 민감 정보는 가린다.
// - Authorization: 붙었는지만 "Bearer ***"로 표시 (토큰 원문 X)
// - 요청 body의 password: "***"
// - 응답 body는 accessToken이 들어 있을 수 있어 code·message만 남긴다.
class MovieLogLoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final auth = options.headers.containsKey('Authorization')
        ? 'Authorization: Bearer ***'
        : 'Authorization 없음';
    final body = _maskBody(options.data);
    debugPrint(
      '[MovieLog →] ${options.method} ${options.uri.path} | $auth'
      '${body == null ? '' : ' | body $body'}',
    );
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '[MovieLog ←] ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri.path}${_summary(response.data)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    debugPrint(
      '[MovieLog ✕] ${status ?? err.type.name} ${err.requestOptions.method} '
      '${err.requestOptions.uri.path}${_summary(err.response?.data)}',
    );
    handler.next(err);
  }

  static Object? _maskBody(Object? data) {
    if (data is! Map) return data;
    return {
      for (final entry in data.entries)
        entry.key: entry.key == 'password' ? '***' : entry.value,
    };
  }

  static String _summary(Object? data) {
    if (data is Map && data['code'] != null) {
      return ' | ${data['code']} ${data['message']}';
    }
    if (data is List) return ' | 배열 ${data.length}개';
    return '';
  }
}
