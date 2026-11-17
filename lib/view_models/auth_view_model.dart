import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';

enum AuthStatus { initializing, signedOut, authenticating, signedIn, retryRequired }

enum MemberLoadStatus { idle, loading, success, error }

// 앱 전체의 로그인 세션. Router가 status를 보고 화면을 정하고(redirect),
// 화면은 이 ViewModel의 메서드만 호출한다. (화면이 직접 /home·/login으로 이동하지 않음)
class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._authApi, this._memberApi, this._storage);

  final AuthApiService _authApi;
  final MemberApiService _memberApi;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.initializing;
  MemberInfo? member;
  MemberLoadStatus memberStatus = MemberLoadStatus.idle;
  // 로그인 Form·스플래시 재시도 화면에 보여줄 문구
  String? message;
  // 만료로 로그아웃됐을 때만 켜진다. 로그인 화면이 Snackbar로 한 번 안내하고 끈다.
  bool sessionExpired = false;
  bool storageCleanupInProgress = false;
  // 로그아웃·만료 정리에서 저장된 토큰 삭제가 실패했을 때 켜진다. 삭제에 성공할 때까지
  // 로그인 화면에서 다시 지우기를 안내한다. (토큰이 남아 있으면 재시작 시 다시 로그인될 수 있음)
  bool tokenCleanupFailed = false;

  // 로그인·로그아웃·만료·복원마다 올라간다. 요청을 보낼 때의 값과 응답이 왔을 때의 값이
  // 다르면 이전 세션의 늦은 응답이므로 버린다.
  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;

  bool _disposed = false;
  Future<void>? _tokenWrite;

  bool _isCurrent(int version) => !_disposed && version == _sessionVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // 앱 시작: 저장된 토큰을 읽고, 있으면 GET me로 서버 검증을 마친 뒤에만 signedIn.
  // 토큰이 있다는 사실만으로 로그인 상태를 확정하지 않는다.
  Future<void> restoreSession() async {
    if (storageCleanupInProgress || _disposed) return;
    final version = ++_sessionVersion;
    status = AuthStatus.initializing;
    message = null;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    _notify();

    try {
      final token = await _storage.readAccessToken();
      if (!_isCurrent(version)) return;
      if (token == null || token.isEmpty) {
        status = AuthStatus.signedOut;
      } else {
        final verifiedMember = await _memberApi.fetchMe();
        if (!_isCurrent(version)) return;
        member = verifiedMember;
        memberStatus = MemberLoadStatus.success;
        status = AuthStatus.signedIn;
      }
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크가 잠시 끊긴 것만으로 유효할 수 있는 토큰을 지우지 않는다. (재시도)
      status = AuthStatus.retryRequired;
      message = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
    } catch (error) {
      if (!_isCurrent(version)) return;
      if (kDebugMode) debugPrint('[Auth] 세션 복원 실패: ${error.runtimeType}');
      status = AuthStatus.retryRequired;
      message = '인증 저장소를 읽지 못했어요. 다시 시도해 주세요.';
    }
    if (_isCurrent(version)) _notify();
  }

  // 신규 로그인: 로그인 API 성공 → 토큰 저장 → signedIn. 내 정보는 MainScreen이 불러온다.
  Future<void> login(String email, String password) async {
    if (_disposed ||
        storageCleanupInProgress ||
        status == AuthStatus.authenticating) {
      return;
    }
    final version = ++_sessionVersion;
    status = AuthStatus.authenticating;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = false;
    message = null;
    _notify();

    final LoginResult result;
    try {
      result = await _authApi.login(
        LoginRequest(email: email, password: password),
      );
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = _loginErrorMessage(error);
      _notify();
      return;
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 응답을 확인하지 못했어요. 잠시 후 다시 시도해 주세요.';
      _notify();
      return;
    }
    if (!_isCurrent(version)) return;

    try {
      final writing = _storage.saveAccessToken(result.accessToken);
      _tokenWrite = writing;
      try {
        await writing;
      } finally {
        if (identical(_tokenWrite, writing)) _tokenWrite = null;
      }
      if (!_isCurrent(version)) return;
      // 새 토큰으로 덮어썼으니 이전 토큰 정리 실패는 더 이상 남아 있지 않다.
      tokenCleanupFailed = false;
      status = AuthStatus.signedIn;
    } catch (_) {
      if (!_isCurrent(version)) return;
      status = AuthStatus.signedOut;
      message = '로그인 정보를 안전하게 저장하지 못했어요.';
    }
    _notify();
  }

  // AUTH401_1(이메일·비밀번호 오류)은 Form 오류일 뿐 세션 만료가 아니다.
  String _loginErrorMessage(DioException error) {
    final code = apiErrorCode(error);
    if (code == 'AUTH401_1') return '이메일 또는 비밀번호를 확인해 주세요.';
    if (code == 'COMMON400') {
      return apiErrorMessage(error) ?? '입력값을 확인해 주세요.';
    }
    return '로그인 요청에 실패했어요. 잠시 후 다시 시도해 주세요.';
  }

  // 탭 화면(MainScreen)이 처음 열릴 때 한 번 호출한다. 이미 있으면 다시 부르지 않는다.
  Future<void> loadMember({bool force = false}) async {
    if (_disposed || status != AuthStatus.signedIn) return;
    if (memberStatus == MemberLoadStatus.loading) return;
    if (member != null && !force) return;

    final version = _sessionVersion;
    memberStatus = MemberLoadStatus.loading;
    _notify();

    try {
      final me = await _memberApi.fetchMe();
      if (!_isCurrent(version)) return; // 로그아웃·계정 전환 뒤 늦게 온 응답 무시
      member = me;
      memberStatus = MemberLoadStatus.success;
    } on DioException catch (error) {
      if (!_isCurrent(version)) return;
      if (isSessionExpiredError(error)) {
        await _clearCurrentSession(expired: true);
        return;
      }
      // 네트워크 실패: 로그아웃하지 않고 마이페이지에서 다시 시도할 수 있게 둔다.
      memberStatus = MemberLoadStatus.error;
    } catch (_) {
      if (!_isCurrent(version)) return;
      memberStatus = MemberLoadStatus.error;
    }
    _notify();
  }

  // 프로필 수정 성공 응답(수정된 내 정보 전체)으로 교체한다. GET me를 다시 부르지 않는다.
  void updateMember(MemberInfo updated) {
    if (_disposed || status != AuthStatus.signedIn) return;
    member = updated;
    memberStatus = MemberLoadStatus.success;
    _notify();
  }

  // 다른 ViewModel이 보호 요청에서 AUTH401_2/3/4를 받았을 때의 공개 진입점.
  // 요청을 보낼 때의 sessionVersion을 넘기면, 이전 세션의 늦은 401이 새 세션을 지우지 못한다.
  Future<void> expireSession({int? sessionVersion}) async {
    if (sessionVersion != null && sessionVersion != _sessionVersion) return;
    if (status != AuthStatus.signedIn) return;
    await _clearCurrentSession(expired: true);
  }

  // 직접 로그아웃: 저장소·메모리 세션을 비우지만 만료 Snackbar는 켜지 않는다.
  // (서버에서 토큰이 즉시 폐기된다는 보장은 아니다)
  Future<void> logout() => _clearCurrentSession(expired: false);

  void consumeSessionExpired() {
    sessionExpired = false;
  }

  Future<void> _clearCurrentSession({required bool expired}) async {
    if (_disposed || storageCleanupInProgress) return;
    final version = ++_sessionVersion;
    storageCleanupInProgress = true;
    member = null;
    memberStatus = MemberLoadStatus.idle;
    sessionExpired = expired;
    status = AuthStatus.signedOut;
    message = null;
    _notify();

    try {
      // 진행 중이던 토큰 저장을 기다린 뒤 삭제한다. 정리 중에는 새 로그인을 막는다.
      try {
        await _tokenWrite;
      } catch (_) {
        // 저장이 실패했어도 삭제는 시도한다.
      }
      await _storage.deleteAccessToken();
      tokenCleanupFailed = false;
    } catch (_) {
      // 화면은 이미 로그아웃 상태(보호 화면에서 나감)지만, 정리가 끝난 것은 아니다.
      // 삭제에 성공할 때까지 실패 상태를 유지하고 다시 지울 수 있게 한다.
      tokenCleanupFailed = true;
      if (_isCurrent(version)) message = _tokenCleanupFailedMessage;
    } finally {
      storageCleanupInProgress = false;
      if (_isCurrent(version)) _notify();
    }
  }

  static const _tokenCleanupFailedMessage =
      '저장된 인증 정보를 지우지 못했어요. 다시 지우기를 눌러 주세요.';

  // 로그인 화면의 "저장된 인증 정보 다시 지우기"
  Future<void> retryTokenCleanup() async {
    if (_disposed || !tokenCleanupFailed || storageCleanupInProgress) return;
    storageCleanupInProgress = true;
    _notify();
    try {
      await _storage.deleteAccessToken();
      tokenCleanupFailed = false;
      message = null;
    } catch (_) {
      message = _tokenCleanupFailedMessage;
    } finally {
      storageCleanupInProgress = false;
      _notify();
    }
  }

  // debug 전용: 저장된 토큰을 무효 값으로 바꾼 뒤 내 정보를 다시 요청해
  // AUTH401_3(유효하지 않은 토큰) → 세션 정리 → 로그인 화면 안내 흐름을 재현한다.
  Future<void> debugUseInvalidToken() async {
    if (!kDebugMode || status != AuthStatus.signedIn) return;
    await _storage.saveAccessToken('invalid.debug.token');
    await loadMember(force: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    super.dispose();
  }
}
