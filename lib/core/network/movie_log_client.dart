import 'package:dio/dio.dart';

// 워크북 자체 백엔드 전용 Client. TMDB Client와 baseUrl·헤더가 달라 합치지 않는다.
Dio createMovieLogClient() {
  return Dio(
    BaseOptions(
      baseUrl: 'https://workbook.devnoco.com',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
}
