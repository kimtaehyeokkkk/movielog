import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 토큰 저장·조회·삭제 규칙을 인증 흐름에서 분리한다.
// 로그인·로그아웃·Interceptor는 이 인터페이스만 알고, 테스트에서는 메모리 구현으로 바꿔 끼운다.
abstract interface class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<String?> readAccessToken();
  Future<void> deleteAccessToken();
}

// Android Keystore / iOS Keychain을 쓰는 보안 저장소. 토큰은 여기에만 저장한다.
// (SharedPreferences는 평문이라 장르·이메일처럼 민감하지 않은 값에만 쓴다)
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage(this._storage);

  static const _accessTokenKey = 'movielog.access_token';
  final FlutterSecureStorage _storage;

  @override
  Future<void> saveAccessToken(String token) {
    return _storage.write(key: _accessTokenKey, value: token);
  }

  @override
  Future<String?> readAccessToken() {
    return _storage.read(key: _accessTokenKey);
  }

  @override
  Future<void> deleteAccessToken() {
    return _storage.delete(key: _accessTokenKey);
  }
}
