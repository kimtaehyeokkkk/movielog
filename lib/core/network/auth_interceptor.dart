import 'package:dio/dio.dart';
import 'package:movielog/core/storage/token_storage.dart';

// 보호 API(내 정보, 평점 등록·수정·삭제)에만 MovieLog JWT를 붙인다.
// 보호용 Client에만 등록하고, 그 안에서도 host·path를 한 번 더 확인한다.
// (TMDB·이미지 URL·공개 API에는 토큰이 실리면 안 된다)
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._storage);

  static const _host = 'workbook.devnoco.com';
  final TokenStorage _storage;

  static bool isProtected(RequestOptions options) {
    final uri = options.uri;
    final path = uri.path;
    return uri.host == _host &&
        (path == '/v7/members/me' ||
            path == '/v7/ratings' ||
            path.startsWith('/v7/ratings/'));
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!isProtected(options)) {
      handler.next(options);
      return;
    }
    options.headers.remove('Authorization'); // 이전 요청의 토큰을 재사용하지 않는다.
    try {
      final token = await _storage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (_) {
      // 서버의 401과 기기 저장소 실패는 다른 오류다. 응답 없는 오류로 구분해 넘긴다.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('인증 저장소를 읽지 못했습니다.'),
        ),
      );
    }
  }
}
