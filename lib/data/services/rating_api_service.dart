import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_request.dart';

// 평점 조회·등록·수정·삭제 (v6). HTTP와 DTO 변환만 담당한다.
class RatingApiService {
  RatingApiService(this._dio);

  final Dio _dio;

  // 성공 응답은 Wrapper 없이 평점 배열 그대로다. (ratingId 내림차순)
  Future<List<RatingDto>> fetchMyRatings(int memberId) async {
    final response = await _dio.get('/v6/members/$memberId/ratings');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => RatingDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // 201 + 공통 응답. 명세 설명은 result가 ratingId 숫자라고 하지만 예시는 null이라
  // 계약이 확정되기 전에는 result를 파싱하지 않고, 등록 뒤 GET으로 목록을 다시 확인한다.
  Future<void> createRating({
    required int memberId,
    required CreateRatingRequest request,
  }) async {
    final response = await _dio.post(
      '/v6/members/$memberId/ratings',
      data: request.toJson(),
    );
    if (response.statusCode != 201) {
      throw StateError('예상하지 못한 등록 응답: ${response.statusCode}');
    }
  }

  // 200 + result null
  Future<void> updateRating({
    required int memberId,
    required int ratingId,
    required UpdateRatingRequest request,
  }) async {
    await _dio.patch(
      '/v6/members/$memberId/ratings/$ratingId',
      data: request.toJson(),
    );
  }

  // 204 + 본문 없음. 성공 응답을 JSON으로 파싱하지 않는다.
  Future<void> deleteRating({
    required int memberId,
    required int ratingId,
  }) async {
    final response =
        await _dio.delete('/v6/members/$memberId/ratings/$ratingId');
    if (response.statusCode != 204) {
      throw StateError('예상하지 못한 삭제 응답: ${response.statusCode}');
    }
  }
}

// 목록 조회(GET) 실패 문구. 빈 배열은 실패가 아니라 Empty다.
String writeMyRatingsErrorMessage(DioException error) {
  final status = error.response?.statusCode;
  if (status == 400) return 'memberId 형식을 다시 확인해 주세요.';
  if (status == 404) return '존재하지 않는 회원입니다.';
  return '평점을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
}

// 쓰기 실패 문구. 같은 COMMON404라도 등록은 "유저", 수정·삭제는 "평점"을 가리켜서
// code로 문구를 새로 만들지 않고 서버 message를 그대로 쓴다.
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

// code는 문구가 아니라 다음 UI 행동에만 쓴다. 403·404는 화면의 목록이 서버와
// 어긋났다는 뜻이라 다시 조회하고, 400·409는 값만 고쳐 다시 시도하면 되므로 조회하지 않는다.
// 본문을 파싱하지 못해도 HTTP 상태 코드가 403·404면 같은 의미로 본다.
bool shouldRefreshAfterRatingError(DioException error) {
  final code = CommonResponse.tryParse(error.response?.data)?.code;
  final status = error.response?.statusCode;
  return code == 'COMMON403' ||
      code == 'COMMON404' ||
      status == 403 ||
      status == 404;
}
