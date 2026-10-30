import 'package:dio/dio.dart';
import 'package:movielog/core/config/movielog_api_config.dart';

// MovieLog 자체 API 전용 Client. TMDB와 인증 방식이 달라 Client를 분리한다.
Dio createMovieLogApiClient() {
  return Dio(
    BaseOptions(
      baseUrl: MovieLogApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'accept': 'application/json'},
    ),
  );
}
