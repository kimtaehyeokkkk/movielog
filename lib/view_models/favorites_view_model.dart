import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/core/utils/safe_notify.dart';
import 'package:movielog/data/models/favorite_list_item.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';

// 마이페이지 "내 즐겨찾기". 즐겨찾기 목록(MovieLog)을 받고, 제목·포스터는 movieId로
// TMDB 상세를 찾아 붙인다. 영화 한 건 조회 실패는 그 카드만 placeholder로 두고 목록은 유지한다.
class FavoritesViewModel extends ChangeNotifier with SafeNotify {
  FavoritesViewModel({
    required this.favoriteApi,
    required this.tmdbApi,
    required this.sessionGuard,
    required this.accountId,
    required this.auth,
    this.enrichmentConcurrency = 5,
  }) : _sessionGeneration = sessionGuard.generation;

  // 이 ViewModel이 만들어진 세션. 같은 이메일로 다시 로그인해 세션 번호가 바뀌면
  // 이 ViewModel은 더 이상 요청하지 않는다. (Route의 ValueKey가 새 ViewModel을 만든다)
  final int _sessionGeneration;

  final FavoriteApiService favoriteApi;
  final TmdbMovieService tmdbApi;
  final SessionGuard sessionGuard;
  final String accountId;
  final AuthViewModel auth;
  // TMDB에 한꺼번에 너무 많은 요청이 몰리지 않게 동시에 최대 5개만 조회한다.
  final int enrichmentConcurrency;

  LoadPhase phase = LoadPhase.idle;
  List<FavoriteListItem> items = const [];
  String? errorMessage;
  int _refreshGeneration = 0;

  // debug 전용 실패 재현 (kDebugMode 메뉴에서만 켬)
  bool _debugFailNextRefresh = false;
  bool _debugFailOneMovie = false;

  // 세션 확인 → 즐겨찾기 목록 조회 → 영화 정보 보충 → 상태 결정
  Future<void> refresh() async {
    final sessionGeneration = _sessionGeneration;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final authVersion = auth.sessionVersion;
    final refreshGeneration = ++_refreshGeneration;
    bool isCurrent() =>
        sessionGuard.isCurrent(sessionGeneration, accountId) &&
        refreshGeneration == _refreshGeneration &&
        !isDisposed;

    // 목록이 이미 있으면(상세에서 돌아온 재조회) 카드를 지우지 않고 그대로 둔 채 갱신한다.
    if (items.isEmpty) phase = LoadPhase.loading;
    errorMessage = null;
    notifyIfAlive();
    try {
      if (_debugFailNextRefresh) {
        _debugFailNextRefresh = false;
        throw DioException(
          requestOptions: RequestOptions(path: '/v8/favorites'),
          type: DioExceptionType.connectionError,
          message: 'debug: 내 즐겨찾기 조회 실패 재현',
        );
      }
      final favorites = await favoriteApi.fetchMyFavorites();
      if (!isCurrent()) return;

      final failOneMovieId = _debugFailOneMovie && favorites.isNotEmpty
          ? favorites.first.movieId
          : null;
      _debugFailOneMovie = false;
      final enriched = await mapBounded(
        favorites,
        enrichmentConcurrency,
        (favorite) => _enrich(favorite, forceFail: favorite.movieId == failOneMovieId),
      );
      if (!isCurrent()) return;
      items = enriched;
      phase = items.isEmpty ? LoadPhase.empty : LoadPhase.ready;
    } on DioException catch (error) {
      if (!isCurrent()) return;
      if (isSessionExpiredError(error)) {
        // 세션 정리 후 Router가 /login으로 보낸다. (요청 당시 세션일 때만)
        await auth.expireSession(sessionVersion: authVersion);
        return;
      }
      items = const [];
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
    } catch (_) {
      if (!isCurrent()) return;
      items = const [];
      phase = LoadPhase.error;
      errorMessage = '내 즐겨찾기 목록을 불러오지 못했습니다.';
    } finally {
      if (isCurrent()) notifyIfAlive();
    }
  }

  // 영화 정보를 못 가져온 카드 한 장만 다시 조회한다. 다른 카드는 그대로 둔다.
  Future<void> retryItem(int movieId) async {
    final sessionGeneration = _sessionGeneration;
    final refreshGeneration = _refreshGeneration;
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) || isDisposed) {
      return;
    }
    final index = items.indexWhere((item) => item.favorite.movieId == movieId);
    if (index < 0) return;
    final updated = await _enrich(items[index].favorite);
    if (!sessionGuard.isCurrent(sessionGeneration, accountId) ||
        refreshGeneration != _refreshGeneration ||
        isDisposed) {
      return;
    }
    items = [
      for (final item in items)
        item.favorite.movieId == movieId ? updated : item,
    ];
    notifyIfAlive();
  }

  // 카드별 실패를 예외가 아니라 결과로 바꿔, 한 건 실패로 목록 전체가 비지 않게 한다.
  Future<FavoriteListItem> _enrich(
    FavoriteResponseDto favorite, {
    bool forceFail = false,
  }) async {
    try {
      if (forceFail) throw StateError('debug: 영화 정보 한 건 실패 재현');
      final movie = await tmdbApi.fetchMovieDetail(favorite.movieId);
      return FavoriteListItem(favorite: favorite, movie: movie);
    } catch (_) {
      return FavoriteListItem(
        favorite: favorite,
        errorMessage: '영화 정보를 불러오지 못했습니다.',
      );
    }
  }

  // kDebugMode 전용
  void debugFailNextRefresh() => _debugFailNextRefresh = true;
  void debugFailOneMovieOnNextRefresh() => _debugFailOneMovie = true;
}
