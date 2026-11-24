import 'package:flutter/foundation.dart';
import 'package:movielog/core/session/session_guard.dart';

// AuthViewModel의 상태 변화를 SessionGuard에 전달하는 연결만 담당한다.
// 인증 상태의 기준은 8주차 AuthViewModel이 그대로 가진다.
class AuthSessionBridge {
  AuthSessionBridge({
    required this.authSignals,
    required this.sessionVersion,
    required this.verifiedEmail,
  }) {
    authSignals.addListener(_sync);
    _sync();
  }

  final Listenable authSignals;
  final int Function() sessionVersion;
  // signedIn이고 GET me로 member가 생기기 전까지는 null
  final String? Function() verifiedEmail;
  final guard = SessionGuard();
  int? _seenVersion;
  String? _seenEmail;
  bool _disposed = false;

  // 세션 번호나 확인된 email이 바뀔 때만 새 세션으로 본다. (닉네임 수정·build로는 바뀌지 않음)
  void _sync() {
    if (_disposed) return;
    final version = sessionVersion();
    final email = verifiedEmail();
    if (version == _seenVersion && email == _seenEmail) return;
    _seenVersion = version;
    _seenEmail = email;
    guard.invalidate();
    if (email != null) guard.startSession(email);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    authSignals.removeListener(_sync);
    guard.invalidate();
  }
}
