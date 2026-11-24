import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/safe_notify.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';

// 영화 상세의 즐겨찾기 버튼 상태.
// 서버 성공을 확인한 뒤에만 북마크를 바꾼다. (결과를 기다리지 않고 먼저 바꾸는 optimistic update X)
class FavoriteDetailViewModel extends ChangeNotifier with SafeNotify {
  FavoriteDetailViewModel({
    required this.movieId,
    required this.favoriteApi,
    required this.sessionGuard,
    required this.accountId,
    required this.auth,
  }) : _sessionGeneration = sessionGuard.generation;

  // 이 ViewModel이 만들어진 세션. 같은 이메일로 다시 로그인해도 세션 번호가 바뀌면 요청하지 않는다.
  final int _sessionGeneration;

  // 상세 화면의 TMDB 영화 id. 즐겨찾기 경로에는 favoriteId가 아니라 이 값을 쓴다.
  final int movieId;
  final FavoriteApiService favoriteApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final AuthViewModel auth;

  bool isFavorite = false;
  bool hasLoadedStatus = false;
  bool isLoading = false; // 첫 여부 조회 중
  bool isSaving = false; // 등록·해제 중
  String? errorMessage;

  // 요청을 보낼 때의 세션 번호(SessionGuard)와 인증 세션 번호(AuthViewModel)를 함께 잡아 둔다.
  ({int generation, int authVersion, bool ok}) _snapshot() {
    final generation = _sessionGeneration;
    return (
      generation: generation,
      authVersion: auth.sessionVersion,
      ok: sessionGuard.isCurrent(generation, accountId) && !isDisposed,
    );
  }

  bool _stillCurrent(({int generation, int authVersion, bool ok}) snap) =>
      sessionGuard.isCurrent(snap.generation, accountId) && !isDisposed;

  Future<void> load() async {
    if (isLoading || isSaving) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    isLoading = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      final result = await favoriteApi.checkFavorite(movieId: movieId);
      if (!_stillCurrent(snap)) return;
      isFavorite = result.isFavorite;
      hasLoadedStatus = true;
    } on DioException catch (error) {
      if (!_stillCurrent(snap)) return;
      if (await _expireIfNeeded(error, snap)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } catch (_) {
      if (!_stillCurrent(snap)) return;
      errorMessage = '즐겨찾기 여부를 확인하지 못했습니다.';
    } finally {
      if (_stillCurrent(snap)) {
        isLoading = false;
        notifyIfAlive();
      }
    }
  }

  // 요청 중에는 중복 탭을 막는다. 실패하면 이전 아이콘 상태를 유지한다.
  Future<void> toggle() async {
    if (isSaving || isLoading || !hasLoadedStatus) return;
    final snap = _snapshot();
    if (!snap.ok) return;
    final before = isFavorite;
    isSaving = true;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (before) {
        await favoriteApi.deleteFavorite(movieId: movieId);
      } else {
        // timeout이어도 같은 POST를 자동으로 다시 보내지 않는다.
        await favoriteApi.addFavorite(movieId: movieId);
      }
      if (!_stillCurrent(snap)) return;
      isFavorite = !before;
    } on DioException catch (error) {
      if (!_stillCurrent(snap)) return;
      if (await _expireIfNeeded(error, snap)) return;
      final code = apiErrorCode(error);
      // 이미 등록(409)·이미 해제(404)면 POST/DELETE를 반복하지 않고 서버의 현재 여부로 맞춘다.
      if (code == 'FAVORITE409_1' || code == 'FAVORITE404_1') {
        await _syncFromServer(snap, before);
      } else {
        isFavorite = before;
        errorMessage = _failMessage(before);
      }
    } catch (_) {
      if (!_stillCurrent(snap)) return;
      isFavorite = before;
      errorMessage = _failMessage(before);
    } finally {
      if (_stillCurrent(snap)) {
        isSaving = false;
        notifyIfAlive();
      }
    }
  }

  Future<void> _syncFromServer(
    ({int generation, int authVersion, bool ok}) snap,
    bool before,
  ) async {
    try {
      final synced = await favoriteApi.checkFavorite(movieId: movieId);
      if (!_stillCurrent(snap)) return;
      isFavorite = synced.isFavorite;
      errorMessage = null;
    } on DioException catch (error) {
      if (!_stillCurrent(snap)) return;
      // 동기화 조회에서도 세션이 만료됐을 수 있다. (요청 당시 세션으로 정리)
      if (await _expireIfNeeded(error, snap)) return;
      isFavorite = before;
      errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
    } catch (_) {
      if (!_stillCurrent(snap)) return;
      isFavorite = before;
      errorMessage = '서버 상태를 다시 확인하지 못했습니다.';
    }
  }

  // AUTH401_2/3/4만 세션 만료. 요청 당시의 인증 세션 번호로 정리를 요청해,
  // 이전 계정의 늦은 401이 지금 계정을 로그아웃시키지 못하게 한다. (403·네트워크 실패는 X)
  Future<bool> _expireIfNeeded(
    DioException error,
    ({int generation, int authVersion, bool ok}) snap,
  ) async {
    if (!isSessionExpiredError(error)) return false;
    await auth.expireSession(sessionVersion: snap.authVersion);
    return true;
  }

  String _failMessage(bool before) =>
      before ? '즐겨찾기 해제에 실패했습니다.' : '즐겨찾기 등록에 실패했습니다.';
}
