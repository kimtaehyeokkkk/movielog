import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/core/network/api_error.dart';
import 'package:movielog/core/utils/safe_notify.dart';
import 'package:movielog/data/models/movie_record_models.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';
import 'package:movielog/data/models/tmdb_movie_dto.dart';
import 'package:movielog/data/services/movie_record_api_service.dart';
import 'package:movielog/data/services/rating_api_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/session_ratings.dart';
import 'package:movielog/view_models/submit_status.dart';

// 영화 상세 화면은 평점 "등록"만 한다. 수정·삭제는 마이페이지의 내가 등록한 평점에서 한다.
// 사용자 식별은 memberId가 아니라 보호용 Client의 Authorization 헤더로 한다.
class MovieDetailViewModel extends ChangeNotifier with SafeNotify {
  MovieDetailViewModel(
    this._ratingService,
    this._movieRecordService,
    this._auth,
    this._sessionRatings,
    this.movie,
  );

  final RatingApiService _ratingService;
  final MovieRecordApiService _movieRecordService;
  final AuthViewModel _auth;
  final SessionRatings _sessionRatings;
  final TmdbMovieDto movie;

  SubmitStatus submitStatus = SubmitStatus.idle;
  String? submitMessage;
  // 실패했을 때 Dialog를 닫고 Snackbar로 안내할 오류인지 (409·회원 없음)
  bool submitClosesDialog = false;
  // 이 화면에서 방금 등록한 별점 (등록 응답의 Rating 객체에서 읽음)
  int? savedScore;

  bool get canRate => _auth.status == AuthStatus.signedIn;

  // 기본 등록: POST /v8/ratings
  Future<void> createRating({required int score, String? comment}) {
    return _submit(
      () => _ratingService.createRating(
        // movieId는 영화 배열 index가 아니라 TMDB가 부여한 영화 id. body에 memberId는 없다.
        CreateRatingRequest(movieId: movie.id, score: score, comment: comment),
      ),
    );
  }

  // Challenge: 아직 즐겨찾기하지 않은 영화는 POST /v8/movie-records로 평점과 즐겨찾기를
  // 한 번에 저장한다. (addToFavorites가 false여도 같은 API, 그때 favorite은 null)
  // 이미 즐겨찾기한 영화는 movie-records가 전체 롤백되므로 평점 API로 평점만 저장한다.
  Future<void> saveRating({
    required int score,
    String? comment,
    required bool addToFavorites,
    required bool alreadyFavorite,
  }) {
    if (alreadyFavorite) return createRating(score: score, comment: comment);
    return _submit(() async {
      final record = await _movieRecordService.saveMovieRecord(
        CreateMovieRecordRequest(
          movieId: movie.id,
          score: score,
          comment: comment,
          addToFavorites: addToFavorites,
        ),
      );
      return record.rating;
    });
  }

  Future<void> _submit(Future<RatingDto> Function() request) async {
    if (submitStatus == SubmitStatus.submitting) return;
    if (!canRate) {
      submitStatus = SubmitStatus.error;
      submitMessage = '로그인이 필요해요.';
      submitClosesDialog = false;
      notifyIfAlive();
      return;
    }
    final version = _auth.sessionVersion;
    submitStatus = SubmitStatus.submitting;
    submitMessage = null;
    submitClosesDialog = false;
    notifyIfAlive();

    try {
      final rating = await request();
      // 화면을 벗어났어도 같은 세션이면 등록 결과는 세션 목록에 남긴다.
      _sessionRatings.add(rating, sessionVersion: version);
      if (isDisposed) return;
      submitStatus = SubmitStatus.success;
      savedScore = rating.score;
    } on DioException catch (error) {
      if (isSessionExpiredError(error)) {
        // 세션 정리 후 Router가 /login으로 보낸다.
        await _auth.expireSession(sessionVersion: version);
        if (isDisposed) return;
        submitStatus = SubmitStatus.error;
        submitMessage = '로그인이 만료됐어요. 다시 로그인해 주세요.';
        submitClosesDialog = true;
      } else {
        if (isDisposed) return;
        submitStatus = SubmitStatus.error;
        submitMessage = writeErrorMessage(error);
        // 입력을 고쳐도 해결되지 않는 오류는 Dialog를 닫는다.
        // COMMON400(입력값)·네트워크 실패는 Dialog를 열어 둔 채 입력을 유지한다.
        submitClosesDialog = const {
          'RATING409_1',
          'FAVORITE409_1',
          'MEMBER404_1',
        }.contains(apiErrorCode(error));
      }
    } catch (error) {
      if (isDisposed) return;
      if (kDebugMode) debugPrint('[MovieDetail] 평점 저장 응답 확인 실패: $error');
      submitStatus = SubmitStatus.error;
      submitMessage = '저장 결과를 확인하지 못했습니다. 잠시 후 다시 확인해 주세요.';
      submitClosesDialog = false;
    }
    notifyIfAlive();
  }
}
