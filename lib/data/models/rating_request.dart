// 서버 평점은 1~5 정수만 받는다. 별점 위젯이 정수 단위로 막아도 남겨 두는 안전장치.
int validateServerScore(double value) {
  if (value < 1 || value > 5 || value != value.roundToDouble()) {
    throw ArgumentError('서버 평점은 1~5 사이 정수여야 합니다.');
  }
  return value.toInt();
}

// 평점 등록 요청 body. movieId는 TMDB 영화 id(TmdbMovieDto.id)다.
class CreateRatingRequest {
  const CreateRatingRequest({
    required this.movieId,
    required this.score,
    this.comment,
  });

  final int movieId;
  final int score;
  final String? comment;

  // 등록의 comment는 선택이라 비어 있으면 키 자체를 넣지 않는다.
  Map<String, dynamic> toJson() => {
        'movieId': movieId,
        'score': score,
        if (comment != null && comment!.trim().isNotEmpty)
          'comment': comment!.trim(),
      };
}

// 평점 수정 요청 body. PATCH지만 score는 필수이고, comment를 빼면 기존 후기가 null로
// 덮이는 전체 교체 계약이라 comment는 항상 명시적으로 보낸다. (null이면 후기 삭제)
class UpdateRatingRequest {
  const UpdateRatingRequest({required this.score, required this.comment});

  final int score;
  final String? comment;

  Map<String, dynamic> toJson() => {'score': score, 'comment': comment};
}
