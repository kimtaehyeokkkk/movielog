import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/view_models/submit_status.dart';

// 영화 상세 화면은 평점 "등록"만 한다. 조회·수정·삭제는 마이페이지의 내가 등록한 평점에서 한다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(this._ratingService, this.memberId, this.movie);

  final RatingApiService _ratingService;
  // 학습용 현재 회원 (회원가입 결과). 로그인 인증은 아니다.
  final int? memberId;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  // 이 화면에서 방금 등록한 별점 (안내 문구용)
  int? savedScore;
  bool _disposed = false;

  bool get canRate => memberId != null;

  Future<void> createRating({required int score, String? comment}) async {
    final id = memberId;
    if (id == null) {
      submitStatus = SubmitStatus.error;
      submitMessage = '먼저 회원가입을 완료해 주세요.';
      _notify();
      return;
    }
    if (submitStatus == SubmitStatus.submitting) return;

    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    _notify();

    try {
      await _ratingService.createRating(
        memberId: id,
        // movieId는 영화 배열 index가 아니라 TMDB가 부여한 영화 id
        request: CreateRatingRequest(
          movieId: movie.id,
          score: score,
          comment: comment,
        ),
      );
      if (_disposed) return;
      submitStatus = SubmitStatus.success;
      savedScore = score;
    } on DioException catch (error) {
      if (_disposed) return;
      submitStatus = SubmitStatus.error;
      // 400 별점 범위 / 404 없는 유저 / 409 이미 평점 있음 → 서버 message 그대로
      submitMessage = writeErrorMessage(error);
    } catch (error) {
      if (_disposed) return;
      if (kDebugMode) debugPrint('[MovieDetail] 평점 등록 응답 확인 실패: $error');
      submitStatus = SubmitStatus.error;
      submitMessage = '등록 결과를 확인하지 못했습니다. 내가 등록한 평점에서 확인해 주세요.';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
