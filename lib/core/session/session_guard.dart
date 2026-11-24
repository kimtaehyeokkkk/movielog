// "지금 도착한 응답이 현재 로그인 세션의 것인가"를 판정한다.
// 계정은 GET me로 확인한 email로 구분하고, memberId나 JWT 안의 값은 추측하지 않는다.
class SessionGuard {
  int _generation = 0;
  String? _accountId;

  int get generation => _generation;
  String? get accountId => _accountId;

  // 검증된 새 세션을 시작할 때만 호출한다. (AuthSessionBridge가 호출, 화면·build에서 X)
  // 같은 계정이라도 토큰이 새로 발급되면 새 세션이라 번호를 올린다.
  int startSession(String accountId) {
    _accountId = accountId;
    return ++_generation;
  }

  void invalidate() {
    _accountId = null;
    _generation++;
  }

  bool isCurrent(int generation, String accountId) =>
      _generation == generation && _accountId == accountId;
}
