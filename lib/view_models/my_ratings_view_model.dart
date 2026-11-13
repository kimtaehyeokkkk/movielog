import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';
import 'package:movielog/view_models/submit_status.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

// 마이페이지 "내가 등록한 평점": 조회·수정·삭제. memberId는 회원가입으로 얻은 학습용 현재 회원이다.
class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, this.memberId);

  // TMDB에 한꺼번에 너무 많은 요청이 몰리지 않도록 동시에 조회할 영화 수를 제한한다.
  static const _movieLookupBatchSize = 5;

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  final int memberId;
  // 같은 movieId는 TMDB에 한 번만 묻는다. (404로 못 찾은 영화는 null로 저장)
  final Map<int, TmdbMovieDto?> _movieCache = {};

  int _requestVersion = 0;
  bool _disposed = false;
  bool _debugFailNextLoad = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;
  // 쓰기는 성공했지만 뒤이은 목록 GET만 실패했을 때의 안내 (저장 실패와 구분)
  String? refreshWarning;

  // Challenge: 다중 선택 삭제
  bool isSelecting = false;
  final Set<int> selectedRatingIds = {};
  bool isDeletingSelected = false;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    _notify();

    try {
      if (_debugFailNextLoad) {
        _debugFailNextLoad = false;
        throw DioException(
          requestOptions: RequestOptions(path: '/v6/members/$memberId/ratings'),
          type: DioExceptionType.connectionError,
          message: 'debug: 목록 재조회 실패 재현',
        );
      }

      final rawRatings = await _service.fetchMyRatings(memberId);
      if (_isStale(version)) return;

      // 캐시에 없는 movieId만 중복 없이 모아 몇 개씩 동시에 조회한다.
      // (평점마다 차례로 기다리면 평점 수만큼 Loading이 길어진다)
      final uncachedIds = {
        for (final rating in rawRatings)
          if (!_movieCache.containsKey(rating.movieId)) rating.movieId,
      }.toList();
      for (var i = 0; i < uncachedIds.length; i += _movieLookupBatchSize) {
        final batch = uncachedIds.skip(i).take(_movieLookupBatchSize);
        await Future.wait(batch.map(_lookUpMovie));
        if (_isStale(version)) return;
      }

      // 영화 정보 조회가 실패해도 평점 목록은 지우지 않는다. (평점의 주인은 자체 백엔드)
      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      for (final rating in rawRatings) {
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }

      ratings = entries;
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
      refreshWarning = null;
      // 목록에서 사라진 평점(다른 곳에서 삭제됨 등)은 선택에서도 뺀다.
      selectedRatingIds.retainAll(entries.map((e) => e.rating.ratingId));
      if (missingMovies > 0) {
        message = '일부 영화 정보를 가져오지 못해 제목·포스터를 대신 표시합니다.';
      }
    } on DioException catch (error) {
      if (_isStale(version)) return;
      status = MyRatingsLoadStatus.error;
      message = writeMyRatingsErrorMessage(error);
    } catch (error) {
      // 응답 JSON 모양이 달라 변환에 실패해도 Loading에 멈추지 않게 한다.
      if (_isStale(version)) return;
      if (kDebugMode) debugPrint('[MyRatings] 응답 변환 실패: $error');
      status = MyRatingsLoadStatus.error;
      message = '평점 정보를 읽지 못했습니다.';
    }

    if (!_isStale(version)) notifyListeners();
  }

  // 수정. 쓰기가 실패하면 SubmitFailure를 던져 Dialog가 닫히지 않고 문구를 보여주게 한다.
  // 쓰기가 성공한 뒤의 목록 GET 실패는 저장 실패로 다시 던지지 않는다.
  Future<void> updateRating({
    required int ratingId,
    required int score,
    String? comment,
  }) async {
    try {
      await _service.updateRating(
        memberId: memberId,
        ratingId: ratingId,
        // comment를 빼면 기존 후기가 null로 덮이는 계약이라 항상 명시해서 보낸다.
        request: UpdateRatingRequest(score: score, comment: comment),
      );
    } on DioException catch (error) {
      await _refreshIfOutOfSync(error);
      throw SubmitFailure(writeErrorMessage(error));
    }
    await _refreshAfterWrite();
  }

  // 단일 삭제. 성공(204)하면 목록을 다시 읽는다.
  Future<void> deleteRating(int ratingId) async {
    try {
      await _service.deleteRating(memberId: memberId, ratingId: ratingId);
    } on DioException catch (error) {
      await _refreshIfOutOfSync(error);
      throw SubmitFailure(writeErrorMessage(error));
    }
    await _refreshAfterWrite();
  }

  // 403·404는 화면의 목록이 서버와 어긋났다는 뜻이라 다시 조회해 맞춘다. (400·409는 조회 안 함)
  Future<void> _refreshIfOutOfSync(DioException error) async {
    if (_disposed || !shouldRefreshAfterRatingError(error)) return;
    await load();
  }

  Future<void> _refreshAfterWrite() async {
    if (_disposed) return;
    await load(); // GET 실패는 status=error로 기록된다.
    if (_disposed) return;
    refreshWarning = status == MyRatingsLoadStatus.error
        ? '저장은 완료됐지만 목록을 불러오지 못했습니다. 조회만 다시 시도해 주세요.'
        : null;
    _notify();
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
  // 실패 개수를 돌려준다. 모든 요청이 끝나면 목록을 다시 읽는다.
  Future<int> deleteSelectedRatings() async {
    if (isDeletingSelected || selectedRatingIds.isEmpty) return 0;
    isDeletingSelected = true;
    _notify();

    var failed = 0;
    try {
      // 원본 Set을 순회하면서 지우면 ConcurrentModificationError가 나므로 복사본을 순회한다.
      for (final ratingId in selectedRatingIds.toList()) {
        if (_disposed) return failed;
        try {
          await _service.deleteRating(memberId: memberId, ratingId: ratingId);
          selectedRatingIds.remove(ratingId);
        } on DioException {
          failed++;
        }
      }
    } finally {
      isDeletingSelected = false;
      _notify(); // 예상하지 못한 오류에도 로딩을 해제한다.
    }

    if (selectedRatingIds.isEmpty) isSelecting = false;
    await _refreshAfterWrite(); // GET 실패는 삭제 성공 여부와 분리한다.
    return failed;
  }

  // kDebugMode 전용: 다음 목록 GET 한 번을 실패시켜 "저장 성공 후 조회만 실패"를 재현한다.
  void debugFailNextLoad() {
    _debugFailNextLoad = true;
  }

  // 영화 한 편 조회. 404는 null로 캐시하고, 그 밖의 실패(네트워크 오류·응답 변환 오류)는
  // 이 영화만 placeholder로 두고 캐시하지 않아 다음 로딩에서 다시 묻는다.
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
    super.dispose();
  }
}
