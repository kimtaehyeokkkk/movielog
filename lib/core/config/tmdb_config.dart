import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class TmdbConfig {
  static const _accessTokenKey = 'TMDB_ACCESS_TOKEN';

  static String get accessToken => dotenv.env[_accessTokenKey] ?? '';

  // Token 값 자체는 출력하지 않고, 비어 있는지만 확인한다.
  static bool get hasAccessToken => accessToken.trim().isNotEmpty;
}
