import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/core/network/auth_interceptor.dart';
import 'package:movielog/core/session/auth_session_bridge.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/core/utils/map_bounded.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/favorite_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/favorite_detail_view_model.dart';
import 'package:movielog/view_models/favorites_view_model.dart';
import 'package:movielog/view_models/load_phase.dart';

import 'support/fake_auth.dart';

FavoriteResponseDto _favorite(int movieId) => FavoriteResponseDto(
      favoriteId: movieId + 1000,
      movieId: movieId,
      createdAt: DateTime.utc(2026, 11, 20),
    );

TmdbMovieDto _movie(int id) => TmdbMovieDto(
      id: id,
      title: '영화 $id',
      overview: '',
      posterPath: null,
      backdropPath: null,
      releaseDate: null,
      genreIds: const [],
      voteAverage: 0,
      popularity: 0,
    );

Map<String, dynamic> _wrap(Object? result) => {
      'isSuccess': true,
      'code': 'COMMON200',
      'message': 'ok',
      'result': result,
    };

// 서버 대신 요청을 가로채 정해진 응답을 돌려주는 Dio
Dio _dio(
  List<RequestOptions> captured, {
  int statusCode = 200,
  Object? data,
  List<Interceptor> before = const [],
}) {
  return Dio(BaseOptions(baseUrl: 'https://workbook.devnoco.com'))
    ..interceptors.addAll([
      ...before,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured.add(options);
          handler.resolve(
            Response(requestOptions: options, statusCode: statusCode, data: data),
          );
        },
      ),
    ]);
}

// 메모리에서 즐겨찾기 여부를 관리하는 가짜 Service. 오류·지연을 주입할 수 있다.
class _FakeFavoriteApi extends FavoriteApiService {
  _FakeFavoriteApi([Set<int>? favorites])
      : favorites = favorites ?? {},
        super(Dio());

  final Set<int> favorites;
  Object? addError;
  Object? deleteError;
  Object? listError;
  Completer<void>? pendingCheck;
  int addCalls = 0;
  int checkCalls = 0;

  @override
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    addCalls++;
    final error = addError;
    if (error != null) throw error;
    favorites.add(movieId);
    return _favorite(movieId);
  }

  @override
  Future<void> deleteFavorite({required int movieId}) async {
    final error = deleteError;
    if (error != null) throw error;
    favorites.remove(movieId);
  }

  @override
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    checkCalls++;
    final pending = pendingCheck;
    if (pending != null) await pending.future;
    return FavoriteCheckDto(
      movieId: movieId,
      isFavorite: favorites.contains(movieId),
    );
  }

  @override
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    final error = listError;
    if (error != null) throw error;
    return [for (final id in favorites) _favorite(id)];
  }
}

class _FakeTmdb extends TmdbMovieService {
  _FakeTmdb({this.failing = const {}}) : super(Dio());

  final Set<int> failing;
  final calls = <int>[];
  int _inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<TmdbMovieDto> fetchMovieDetail(int movieId) async {
    calls.add(movieId);
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    try {
      await Future<void>.delayed(Duration.zero);
      if (failing.contains(movieId)) throw networkError();
      return _movie(movieId);
    } finally {
      _inFlight--;
    }
  }
}

class _Session {
  _Session(this.auth, this.bridge);

  static Future<_Session> signedIn({FakeMemberApiService? memberApi}) async {
    final auth = await signedInAuth(memberApi: memberApi);
    final bridge = AuthSessionBridge(
      authSignals: auth,
      sessionVersion: () => auth.sessionVersion,
      verifiedEmail: () =>
          auth.status == AuthStatus.signedIn ? auth.member?.email : null,
    );
    return _Session(auth, bridge);
  }

  final AuthViewModel auth;
  final AuthSessionBridge bridge;
  SessionGuard get guard => bridge.guard;
  String get accountId => auth.member!.email;
}

void main() {
  group('FavoriteApiService (v8)', () {
    test('등록·목록·여부·해제를 movieId 경로로 보내고 각 응답을 읽는다', () async {
      final captured = <RequestOptions>[];
      final itemJson = {
        'favoriteId': 3,
        'movieId': 550,
        'createdAt': '2026-09-06T12:14:03.000Z',
      };

      final added = await FavoriteApiService(
        _dio(captured, statusCode: 201, data: _wrap(itemJson)),
      ).addFavorite(movieId: 550);
      final list = await FavoriteApiService(
        _dio(captured, data: _wrap([itemJson])),
      ).fetchMyFavorites();
      final check = await FavoriteApiService(
        _dio(captured, data: _wrap({'isFavorite': true})),
      ).checkFavorite(movieId: 550);
      await FavoriteApiService(_dio(captured, data: _wrap(null)))
          .deleteFavorite(movieId: 550);

      expect(added.favoriteId, 3);
      expect(captured[0].data, {'movieId': 550});
      expect(list.single.movieId, 550);
      // 여부 조회 응답에는 movieId가 없어 요청한 값을 넣는다.
      expect(check.movieId, 550);
      expect(check.isFavorite, isTrue);
      expect(captured.map((o) => '${o.method} ${o.uri.path}'), [
        'POST /v8/favorites',
        'GET /v8/favorites',
        'GET /v8/favorites/550',
        'DELETE /v8/favorites/550',
      ]);
    });

    test('목록 result가 빈 배열이면 빈 목록', () async {
      final list =
          await FavoriteApiService(_dio([], data: _wrap(<Object?>[])))
              .fetchMyFavorites();
      expect(list, isEmpty);
    });

    test('즐겨찾기 경로는 메서드까지 맞아야 보호 요청이다', () async {
      final captured = <RequestOptions>[];
      final dio = _dio(
        captured,
        before: [AuthInterceptor(MemoryTokenStorage('token-a'))],
      );

      await dio.post('/v8/favorites');
      await dio.get('/v8/favorites');
      await dio.get('/v8/favorites/550');
      await dio.delete('/v8/favorites/550');
      await dio.post('/v8/movie-records');
      await dio.put('/v8/favorites/550'); // 명세에 없는 메서드
      await dio.get('/v8/favorites/abc'); // movieId가 아님
      await dio.get('/v7/favorites');

      final headers = captured.map((o) => o.headers['Authorization']).toList();
      expect(headers.take(5), everyElement('Bearer token-a'));
      expect(headers.skip(5), everyElement(isNull));
    });
  });

  group('FavoriteDetailViewModel', () {
    Future<(FavoriteDetailViewModel, _FakeFavoriteApi, _Session)> create({
      Set<int>? favorites,
    }) async {
      final session = await _Session.signedIn();
      final api = _FakeFavoriteApi(favorites);
      final vm = FavoriteDetailViewModel(
        movieId: 550,
        favoriteApi: api,
        sessionGuard: session.guard,
        accountId: session.accountId,
        auth: session.auth,
      );
      return (vm, api, session);
    }

    test('처음 여부를 조회하고, 서버 성공 뒤에만 등록·해제 상태를 바꾼다', () async {
      final (vm, api, _) = await create();

      await vm.load();
      expect(vm.hasLoadedStatus, isTrue);
      expect(vm.isFavorite, isFalse);

      await vm.toggle();
      expect(vm.isFavorite, isTrue);
      expect(api.favorites, {550});

      await vm.toggle();
      expect(vm.isFavorite, isFalse);
      expect(api.favorites, isEmpty);
    });

    test('네트워크 실패면 이전 아이콘 상태를 유지하고 실패 문구', () async {
      final (vm, api, session) = await create();
      await vm.load();
      api.addError = networkError();

      await vm.toggle();

      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, '즐겨찾기 등록에 실패했습니다.');
      expect(vm.isSaving, isFalse);
      expect(session.auth.status, AuthStatus.signedIn);
    });

    test('FAVORITE409_1이면 POST를 반복하지 않고 서버 여부로 맞춘다', () async {
      final (vm, api, _) = await create();
      await vm.load();
      // 다른 곳에서 이미 등록됐다고 가정
      api.favorites.add(550);
      api.addError = apiError(409, 'FAVORITE409_1', '이미 이 영화를 즐겨찾기하셨습니다.');

      await vm.toggle();

      expect(api.addCalls, 1);
      expect(vm.isFavorite, isTrue);
      expect(vm.errorMessage, isNull);
    });

    test('FAVORITE404_1이면 서버 여부(해제됨)로 맞춘다', () async {
      final (vm, api, _) = await create(favorites: {550});
      await vm.load();
      api.favorites.clear();
      api.deleteError = apiError(404, 'FAVORITE404_1', '즐겨찾기한 영화를 찾을 수 없습니다.');

      await vm.toggle();

      expect(vm.isFavorite, isFalse);
      expect(vm.errorMessage, isNull);
    });

    test('AUTH401_4면 세션을 정리한다 (403·네트워크는 로그아웃 X)', () async {
      final (vm, api, session) = await create();
      await vm.load();
      api.addError = apiError(401, 'AUTH401_4', '토큰이 만료되었습니다.');

      await vm.toggle();

      expect(session.auth.status, AuthStatus.signedOut);
      expect(session.auth.sessionExpired, isTrue);
    });

    test('로그아웃 뒤 도착한 여부 응답은 반영하지 않는다', () async {
      final (vm, api, session) = await create(favorites: {550});
      api.pendingCheck = Completer();

      final loading = vm.load();
      await session.auth.logout();
      api.pendingCheck!.complete();
      await loading;

      expect(vm.hasLoadedStatus, isFalse);
      expect(vm.isFavorite, isFalse);
    });
  });

  group('FavoritesViewModel', () {
    Future<(FavoritesViewModel, _FakeFavoriteApi, _FakeTmdb, _Session)> create({
      Set<int>? favorites,
      Set<int> failing = const {},
    }) async {
      final session = await _Session.signedIn();
      final api = _FakeFavoriteApi(favorites);
      final tmdb = _FakeTmdb(failing: failing);
      final vm = FavoritesViewModel(
        favoriteApi: api,
        tmdbApi: tmdb,
        sessionGuard: session.guard,
        accountId: session.accountId,
        auth: session.auth,
      );
      return (vm, api, tmdb, session);
    }

    test('movieId로 TMDB 영화를 붙이고, 한 건 실패는 그 카드만 placeholder', () async {
      final (vm, _, _, _) = await create(favorites: {550, 13, 680}, failing: {13});

      await vm.refresh();

      expect(vm.phase, LoadPhase.ready);
      expect(vm.items, hasLength(3));
      expect(vm.items.where((i) => i.hasMovie), hasLength(2));
      final missing = vm.items.singleWhere((i) => !i.hasMovie);
      expect(missing.favorite.movieId, 13);
      expect(missing.errorMessage, '영화 정보를 불러오지 못했습니다.');
    });

    test('실패한 카드 하나만 다시 조회한다', () async {
      final (vm, _, tmdb, _) = await create(favorites: {550, 13}, failing: {13});
      await vm.refresh();
      tmdb.failing.clear();

      await vm.retryItem(13);

      expect(vm.items.every((i) => i.hasMovie), isTrue);
      expect(tmdb.calls.where((id) => id == 550), hasLength(1));
    });

    test('빈 목록은 empty, 목록 조회 실패는 error', () async {
      final (emptyVm, _, _, _) = await create();
      await emptyVm.refresh();
      expect(emptyVm.phase, LoadPhase.empty);

      final (errorVm, api, _, session) = await create(favorites: {550});
      api.listError = networkError();
      await errorVm.refresh();
      expect(errorVm.phase, LoadPhase.error);
      expect(session.auth.status, AuthStatus.signedIn);
    });

    test('상세에서 해제하고 돌아와 다시 조회하면 목록에서 사라진다', () async {
      final (vm, api, _, _) = await create(favorites: {550, 13});
      await vm.refresh();

      api.favorites.remove(550);
      await vm.refresh();

      expect(vm.items.map((i) => i.favorite.movieId), [13]);
    });

    test('다른 계정으로 바뀐 뒤에는 이전 ViewModel이 조회하지 않는다', () async {
      final (vm, api, _, session) = await create(favorites: {550});
      await session.auth.logout();
      await session.auth.login('b@umc.com', 'Password1!');
      await session.auth.loadMember();

      await vm.refresh();

      expect(vm.phase, LoadPhase.idle);
      expect(vm.items, isEmpty);
      expect(api.favorites, {550});
    });

    test('TMDB 보충 조회는 동시에 최대 5개', () async {
      final (vm, _, tmdb, _) =
          await create(favorites: {for (var id = 1; id <= 12; id++) id});

      await vm.refresh();

      expect(tmdb.calls, hasLength(12));
      expect(tmdb.maxInFlight, 5);
    });
  });

  group('SessionGuard · AuthSessionBridge', () {
    test('같은 이메일로 다시 로그인해도 새 세션 번호, 닉네임 수정으로는 그대로', () async {
      final session = await _Session.signedIn();
      final first = session.guard.generation;
      expect(session.guard.accountId, 'taehyeok@umc.com');

      session.auth.updateMember(member(nickname: '새닉네임'));
      expect(session.guard.generation, first);

      await session.auth.logout();
      expect(session.guard.accountId, isNull);
      await session.auth.login('taehyeok@umc.com', 'Password1!');
      await session.auth.loadMember();

      expect(session.guard.accountId, 'taehyeok@umc.com');
      expect(session.guard.generation, greaterThan(first));
      expect(session.guard.isCurrent(first, 'taehyeok@umc.com'), isFalse);
    });

    test('mapBounded는 입력 순서대로 결과를 돌려준다', () async {
      final result = await mapBounded<int, String>(
        [3, 1, 2],
        2,
        (value) async {
          await Future<void>.delayed(Duration(milliseconds: value));
          return '영화 $value';
        },
      );
      expect(result, ['영화 3', '영화 1', '영화 2']);
    });
  });
}
