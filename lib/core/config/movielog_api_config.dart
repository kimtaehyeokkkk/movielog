import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class MovieLogApiConfig {
  static const _baseUrlKey = 'MOVIELOG_API_BASE_URL';

  // .env에 값이 없으면 로컬 Spring 서버를 쓴다.
  // (Android 에뮬레이터에서 PC 서버에 붙을 때는 http://10.0.2.2:8080으로 바꾼다.)
  static String get baseUrl {
    final value = dotenv.env[_baseUrlKey]?.trim() ?? '';
    return value.isEmpty ? 'http://localhost:8080' : value;
  }
}
