import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';

// 등록·수정 성공 응답은 공통 형식이고 result가 평점 객체 전체다. (v6: ID?/null)
RatingDto parseRatingResult(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('평점 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<RatingDto>.fromJson(
    data,
    (value) => RatingDto.fromJson(value as Map<String, dynamic>),
  );
  final rating = common.result;
  if (rating == null) throw StateError('평점 result가 없습니다.');
  return rating;
}

// 유저별 평점 조회 성공은 공통 형식으로 감싸지 않은 배열 그대로다.
List<RatingDto> parseRatingList(Object? data) {
  if (data is! List) throw StateError('평점 목록 응답은 배열이어야 합니다.');
  return data
      .map((value) => RatingDto.fromJson(value as Map<String, dynamic>))
      .toList();
}

// 평점 API (v7). 같은 Service 안에서도 메서드마다 Client가 다르다.
// - 유저별 평점 조회: 공개 API → 공개용 Client (토큰 없음)
// - 등록·수정·삭제: 보호 API → 보호용 Client (AuthInterceptor가 Bearer를 붙임)
// 사용자 식별은 path의 memberId가 아니라 Authorization 헤더로 바뀌어 memberId 인자가 없다.
class RatingApiService {
  RatingApiService(this._publicDio, this._authDio);

  final Dio _publicDio;
  final Dio _authDio;

  // v7에도 토큰 기반 "내 평점 목록" GET은 없다. 로그인·내 정보 응답에 memberId가 없어서
  // 지금 화면에서는 쓰지 않고, 공개 조회 계약만 남겨 둔다.
  Future<List<RatingDto>> fetchMemberRatings(int memberId) async {
    final response = await _publicDio.get('/v7/members/$memberId/ratings');
    return parseRatingList(response.data);
  }

  // 201 + result 평점 객체. body에 memberId를 넣지 않는다.
  Future<RatingDto> createRating(CreateRatingRequest request) async {
    final response = await _authDio.post('/v7/ratings', data: request.toJson());
    return parseRatingResult(response.data);
  }

  // 200 + result 수정된 평점 전체. comment를 빼면 null로 덮이는 전체 교체 계약이다.
  Future<RatingDto> updateRating({
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    final response = await _authDio.patch(
      '/v7/ratings/$ratingId',
      data: request.toJson(),
    );
    return parseRatingResult(response.data);
  }

  // v6의 204와 달리 200 + 공통 형식(result null)이다.
  Future<void> deleteRating(int ratingId) async {
    final response = await _authDio.delete('/v7/ratings/$ratingId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

// 쓰기 실패 문구. 서버 message를 그대로 쓰고, 공통 형식이 아니면 연결 상태로 안내한다.
String writeErrorMessage(DioException error) {
  final common = CommonResponse.tryParse(error.response?.data);
  if (common != null) return common.message;
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.receiveTimeout =>
      '서버에 연결하지 못했습니다. 네트워크를 확인해 주세요.',
    _ => '요청에 실패했습니다. 잠시 후 다시 시도해 주세요.',
  };
}
