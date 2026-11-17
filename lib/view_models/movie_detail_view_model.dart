import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

// 영화 상세 화면은 평점 "등록"만 한다. 수정·삭제는 마이페이지의 내가 등록한 평점에서 한다.
// 사용자 식별은 memberId가 아니라 보호용 Client의 Authorization 헤더로 한다.
class MovieDetailViewModel extends ChangeNotifier {
  MovieDetailViewModel(
    this._ratingService,
    this._auth,
    this._sessionRatings,
    this.movie,
  );

  final RatingApiService _ratingService;
  final AuthViewModel _auth;
  final SessionRatings _sessionRatings;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  // 이 화면에서 방금 등록한 별점 (등록 응답의 Rating 객체에서 읽음)
  int? savedScore;
  bool _disposed = false;

  bool get canRate => _auth.status == AuthStatus.signedIn;

  Future<void> createRating({required int score, String? comment}) async {
    if (submitStatus == SubmitStatus.submitting) return;
    if (!canRate) {
      submitStatus = SubmitStatus.error;
      submitMessage = '로그인이 필요해요.';
      _notify();
      return;
    }
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    _notify();

    try {
      final rating = await _ratingService.createRating(
        // movieId는 영화 배열 index가 아니라 TMDB가 부여한 영화 id. body에 memberId는 없다.
        CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
      );
      // 화면을 벗어났어도 같은 세션이면 등록 결과는 세션 목록에 남긴다.
      _sessionRatings.add(rating, sessionVersion: version);
      if (_disposed) return;
      submitStatus = SubmitStatus.success;
      savedScore = rating.score;
    } on DioException catch (error) {
      if (isSessionExpiredError(error)) {
        // 세션 정리 후 Router가 /login으로 보낸다.
        await _auth.expireSession(sessionVersion: version);
        if (_disposed) return;
        submitStatus = SubmitStatus.error;
        submitMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';
      } else {
        if (_disposed) return;
        submitStatus = SubmitStatus.error;
        // RATING409_1 이미 평점 있음 / COMMON400 별점 범위 / MEMBER404_1 → 서버 message 그대로
        submitMessage = writeErrorMessage(error);
      }
    } catch (error) {
      if (_disposed) return;
      if (kDebugMode) debugPrint('[MovieDetail] 평점 등록 응답 확인 실패: $error');
      submitStatus = SubmitStatus.error;
      submitMessage = '등록 결과를 확인하지 못했습니다. 잠시 후 다시 확인해 주세요.';
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
