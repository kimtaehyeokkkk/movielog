import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty }

// 마이페이지 "내가 등록한 평점": 이번 로그인 세션에서 등록한 평점을 v7 토큰 기반 API로 수정·삭제한다.
// v7에는 토큰 기반 내 평점 목록 GET이 없어, 목록의 출처는 등록·수정 응답을 모아 둔 SessionRatings다.
// 평점의 movieId(TMDB 영화 id)로 TMDB 상세를 찾아 제목·포스터를 붙인다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(
    this._service,
    this._movieService,
    this._sessionRatings,
    this._auth,
  ) {
    _sessionRatings.addListener(load);
  }

  // TMDB에 한꺼번에 너무 많은 요청이 몰리지 않도록 동시에 조회할 영화 수를 제한한다.
  static const _movieLookupBatchSize = 5;

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final SessionRatings _sessionRatings;
  final AuthViewModel _auth;
  // 같은 movieId는 TMDB에 한 번만 묻는다. (404로 못 찾은 영화는 null로 저장)
  final Map<int, TmdbMovieDto?> _movieCache = {};

  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  // Challenge: 다중 선택 삭제
  bool isSelecting = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  // SessionRatings가 바뀔 때마다 다시 묶는다. 새 movieId가 있을 때만 TMDB를 조회한다.
  Future<void> load() async {
    if (_disposed) return;
    final version = ++_requestVersion;
    final source = _sessionRatings.items;

    final uncachedIds = {
      for (final rating in source)
        if (!_movieCache.containsKey(rating.movieId)) rating.movieId,
    }.toList();
    if (uncachedIds.isNotEmpty) {
      if (ratings.isEmpty) status = MyRatingsLoadStatus.loading;
      _notify();
      for (var i = 0; i < uncachedIds.length; i += _movieLookupBatchSize) {
        final batch = uncachedIds.skip(i).take(_movieLookupBatchSize);
        await Future.wait(batch.map(_lookUpMovie));
        if (_isStale(version)) return;
      }
    }

    // 영화 정보를 못 찾아도 평점은 지우지 않는다. (화면에서 "영화 #id"로 대신 표시)
    final entries = [
      for (final rating in source)
        RatingWithMovie(rating: rating, movie: _movieCache[rating.movieId]),
    ];
    ratings = entries;
    status = entries.isEmpty
        ? MyRatingsLoadStatus.empty
        : MyRatingsLoadStatus.success;
    message = entries.any((entry) => entry.movie == null)
        ? '일부 영화 정보를 가져오지 못해 영화 ID로 대신 표시합니다.'
        : null;
    selectedRatingIds.retainAll(entries.map((e) => e.rating.ratingId));
    if (entries.isEmpty) isSelecting = false;
    _notify();
  }

  // 수정. 쓰기가 실패하면 SubmitFailure를 던져 Dialog가 닫히지 않고 문구를 보여주게 한다.
  // 성공 응답의 result(수정된 평점 전체)로 목록을 바로 갱신한다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    final version = _auth.sessionVersion;
    try {
      final updated = await _service.updateRating(
        ratingId: ratingId,
        // comment를 빼면 기존 후기가 null로 덮이는 전체 교체 계약이라 항상 명시해서 보낸다.
        request: UpdateRatingRequest(score: score, comment: comment),
      );
      _sessionRatings.replace(updated, sessionVersion: version);
    } on DioException catch (error) {
      throw SubmitFailure(await _handleWriteError(error, ratingId, version));
    }
  }

  // 단일 삭제. 200(result null)이면 목록에서 뺀다.
  Future<void> deleteRating(int ratingId) async {
    final version = _auth.sessionVersion;
    try {
      await _service.deleteRating(ratingId);
      _sessionRatings.remove(ratingId, sessionVersion: version);
    } on DioException catch (error) {
      throw SubmitFailure(await _handleWriteError(error, ratingId, version));
    }
  }

  // 401·403·404를 서로 다르게 처리하고, 사용자에게 보여줄 문구를 돌려준다.
  Future<String> _handleWriteError(
    DioException error,
    int ratingId,
    int version,
  ) async {
    // AUTH401_2/3/4: 세션 정리 → Router가 /login으로 보내고 로그인 화면이 만료를 안내한다.
    if (isSessionExpiredError(error)) {
      await _auth.expireSession(sessionVersion: version);
      return '로그인이 만료됐어요. 다시 로그인해 주세요.';
    }
    // RATING404_1: 이미 없는 평점 → 목록에서 빼서 서버 상태와 맞춘다.
    if (apiErrorCode(error) == 'RATING404_1') {
      _sessionRatings.remove(ratingId, sessionVersion: version);
    }
    // RATING403_1(남의 평점)은 권한 문제일 뿐이라 로그아웃하지 않고 안내만 한다.
    return writeErrorMessage(error);
  }

  // --- Challenge: 다중 선택 삭제 ---

  void startSelecting() {
    isSelecting = true;
    selectedRatingIds.clear();
    _notify();
  }

  void cancelSelecting() {
    isSelecting = false;
    selectedRatingIds.clear();
    _notify();
  }

  void toggleSelected(int ratingId) {
    if (!selectedRatingIds.remove(ratingId)) selectedRatingIds.add(ratingId);
    _notify();
  }

  // 선택한 평점을 하나씩 삭제한다. 실패한 항목은 선택 상태로 남겨 다시 시도할 수 있게 하고,
  // 실패 개수를 돌려준다. 세션이 만료되면 남은 요청을 멈춘다.
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    final version = _auth.sessionVersion;
    isDeletingSelected = true;
    _notify();

    var failed = 0;
    try {
      // 원본 Set을 순회하면서 지우면 ConcurrentModificationError가 나므로 복사본을 순회한다.
      final targets = selectedRatingIds.toList();
      for (var i = 0; i < targets.length; i++) {
        final ratingId = targets[i];
        if (_disposed) return failed;
        try {
          await _service.deleteRating(ratingId);
          selectedRatingIds.remove(ratingId);
          _sessionRatings.remove(ratingId, sessionVersion: version);
        } on DioException catch (error) {
          if (isSessionExpiredError(error)) {
            failed += targets.length - i;
            await _auth.expireSession(sessionVersion: version);
            break;
          }
          if (apiErrorCode(error) == 'RATING404_1') {
            // 이미 없는 평점은 실패로 세지 않고 목록에서 뺀다.
            selectedRatingIds.remove(ratingId);
            _sessionRatings.remove(ratingId, sessionVersion: version);
          } else {
            failed++;
          }
        } catch (error) {
          // 계약과 다른 응답(StateError 등)도 그 항목만 실패로 세고 다음 항목을 이어서 지운다.
          if (kDebugMode) debugPrint('[MyRatings] 평점 $ratingId 삭제 확인 실패: $error');
          failed++;
        }
      }
    } finally {
      isDeletingSelected = false;
      if (selectedRatingIds.isEmpty) isSelecting = false;
      _notify(); // 예상하지 못한 오류에도 로딩을 해제한다.
    }
    return failed;
  }

  // 영화 한 편 조회. 404는 null로 캐시하고, 그 밖의 실패(네트워크 오류·응답 변환 오류)는
  // 이 영화만 placeholder로 두고 캐시하지 않아 다음에 다시 묻는다.
  Future<void> _lookUpMovie(int movieId) async {
    try {
      _movieCache[movieId] = await _movieService.findMovieById(movieId);
    } on DioException {
      // 일시적인 네트워크 실패
    } catch (error) {
      if (kDebugMode) debugPrint('[MyRatings] 영화 $movieId 변환 실패: $error');
    }
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    _sessionRatings.removeListener(load);
    super.dispose();
  }
}
