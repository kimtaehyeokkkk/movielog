import 'package:shared_preferences/shared_preferences.dart';

// Challenge: "이메일 저장". 민감하지 않은 이메일만 SharedPreferences에 둔다.
// 비밀번호와 토큰은 절대 여기에 저장하지 않는다. (토큰은 SecureTokenStorage)
class SavedEmailStorage {
  SavedEmailStorage([SharedPreferencesAsync? prefs]) : _prefsOverride = prefs;

  static const _key = 'movielog.saved_email';
  SharedPreferencesAsync? _prefsOverride;

  // 실제로 쓸 때 만든다. (테스트에서 메서드를 바꿔 끼우면 플랫폼 저장소를 건드리지 않음)
  SharedPreferencesAsync get _prefs =>
      _prefsOverride ??= SharedPreferencesAsync();

  Future<String?> read() => _prefs.getString(_key);

  Future<void> save(String email) => _prefs.setString(_key, email.trim());

  Future<void> clear() => _prefs.remove(_key);
}
