import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:movielog/core/config/tmdb_config.dart';
import 'package:movielog/movie_log_app.dart';
import 'package:movielog/dart_practice.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // runApp 전에 로드를 끝내야 Client 생성 시 Token이 빈 값이 되지 않는다.
  await dotenv.load(fileName: '.env');

  if (kDebugMode && !TmdbConfig.hasAccessToken) {
    debugPrint('[TMDB] .env의 TMDB_ACCESS_TOKEN이 비어 있습니다.');
  }

  // 0주차 Dart 연습 출력은 개발 중에만 확인한다. (release 로그에 남기지 않음)
  if (kDebugMode) runDartPractice();
  runApp(const MovieLogApp());
}
