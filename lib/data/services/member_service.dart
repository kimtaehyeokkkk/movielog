import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_page_dto.dart';

// MovieLog 자체 API의 회원 관련 요청. HTTP와 DTO 변환만 담당한다.
class MemberService {
  MemberService(this._dio);

  final Dio _dio;

  // 닉네임·이메일에 한글이나 @가 들어가므로 path에 넣기 전에 인코딩한다.
  Future<bool> isNicknameAvailable(String nickname) {
    return _fetchAvailable('/members/nickname/${Uri.encodeComponent(nickname)}');
  }

  Future<bool> isEmailAvailable(String email) {
    return _fetchAvailable('/members/email/${Uri.encodeComponent(email)}');
  }

  Future<RatingPageDto> fetchRatings(
    int memberId, {
    int page = 0,
    int size = 10,
  }) async {
    final response = await _dio.get(
      '/members/$memberId/ratings',
      queryParameters: {'page': page, 'size': size},
    );
    return RatingPageDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<bool> _fetchAvailable(String path) async {
    final response = await _dio.get(path);
    final data = response.data as Map<String, dynamic>;
    return data['available'] as bool;
  }
}

// 서버가 보낸 사용자용 message({"status": 400, "message": "..."})가 있으면 그대로 쓴다.
String movieLogApiErrorMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map<String, dynamic> && data['message'] is String) {
    return data['message'] as String;
  }

  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout =>
      '서버에 연결하지 못했어요. 서버가 켜져 있는지 확인해 주세요.',
    DioExceptionType.receiveTimeout => '서버 응답이 늦어지고 있어요.',
    _ => '요청을 처리하지 못했어요.',
  };
}
