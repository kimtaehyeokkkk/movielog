import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/rating_with_movie.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/data/services/tmdb_movie_service.dart';

// 로그인 기능이 없어서 인증된 "내 계정"이 아니라 학습용 회원 1번의 공개 평점을 조회한다.
const int sampleMemberId = 1;

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, this._movieService, int memberId)
      : _memberId = memberId;

  final RatingApiService _service;
  final TmdbMovieService _movieService;
  // 같은 movieId는 TMDB에 한 번만 묻는다. (404로 못 찾은 영화는 null로 저장)
  final Map<int, TmdbMovieDto?> _movieCache = {};

  int _memberId;
  int _requestVersion = 0;
  bool _disposed = false;

  List<RatingWithMovie> ratings = const [];
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  int get memberId => _memberId;

  Future<void> load() async {
    final version = ++_requestVersion;
    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final rawRatings = await _service.fetchMyRatings(_memberId);
      if (_isStale(version)) return;

      final entries = <RatingWithMovie>[];
      var missingMovies = 0;
      // 영화 정보 조회가 실패해도 평점 목록은 지우지 않는다. (평점의 주인은 자체 백엔드)
      for (final rating in rawRatings) {
        if (_isStale(version)) return;
        if (!_movieCache.containsKey(rating.movieId)) {
          try {
            _movieCache[rating.movieId] =
                await _movieService.findMovieById(rating.movieId);
          } on DioException {
            // 일시적인 네트워크 실패는 캐시하지 않고 다음 로딩에서 다시 묻는다.
          }
        }
        final movie = _movieCache[rating.movieId];
        if (movie == null) missingMovies++;
        entries.add(RatingWithMovie(rating: rating, movie: movie));
      }
      if (_isStale(version)) return;

      ratings = entries;
      status = entries.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
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

  // kDebugMode 전용: 다른 회원을 조회해 Empty(회원 3)·Error 404(없는 회원) 응답을 재현한다.
  Future<void> debugLoadMember(int memberId) {
    _memberId = memberId;
    return load();
  }

  bool _isStale(int version) => _disposed || version != _requestVersion;

  @override
  void dispose() {
    _disposed = true;
    _requestVersion++;
    super.dispose();
  }
}
