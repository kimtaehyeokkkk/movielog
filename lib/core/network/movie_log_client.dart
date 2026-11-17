import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/network/movie_log_logging_interceptor.dart';
import 'package:movielog/core/storage/token_storage.dart';

// 워크북 자체 백엔드 Client. TMDB Client와 baseUrl·Authorization이 달라 합치지 않는다.
BaseOptions _movieLogOptions() {
  return BaseOptions(
    baseUrl: 'https://workbook.devnoco.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  );
}

// 공개 요청용: 로그인, 회원가입·중복 확인, 유저별 평점 조회 / AuthInterceptor 없음
Dio createMovieLogClient() {
  final dio = Dio(_movieLogOptions());
  if (kDebugMode) dio.interceptors.add(MovieLogLoggingInterceptor());
  return dio;
}

// 보호 요청용: 내 정보, 평점 등록·수정·삭제 / AuthInterceptor 등록
// 로그는 토큰이 붙은 뒤의 모습을 남기도록 AuthInterceptor 다음에 둔다.
Dio createAuthMovieLogClient(TokenStorage storage) {
  final dio = Dio(_movieLogOptions());
  dio.interceptors.add(AuthInterceptor(storage));
  if (kDebugMode) dio.interceptors.add(MovieLogLoggingInterceptor());
  return dio;
}
