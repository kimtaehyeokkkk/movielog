import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/favorite_check_dto.dart';
import 'package:movielog/data/models/favorite_response_dto.dart';

// MovieLog 즐겨찾기 API(/v8/favorites). 모두 보호 API라 AuthInterceptor가 있는 Client를 받는다.
// 경로의 숫자는 favoriteId가 아니라 TMDB movieId다. (상세 화면이 가진 값)
class FavoriteApiService {
  FavoriteApiService(this._dio);

  final Dio _dio;

  // 201, result에 FavoriteResponseDto
  Future<FavoriteResponseDto> addFavorite({required int movieId}) async {
    final response = await _dio.post(
      '/v8/favorites',
      data: {'movieId': movieId},
    );
    final body = CommonResponse<FavoriteResponseDto>.fromJson(
      response.data as Map<String, dynamic>,
      FavoriteResponseDto.fromJson,
    );
    final result = body.result;
    if (result == null) throw StateError('즐겨찾기 등록 result가 없습니다.');
    return result;
  }

  // 200, result가 배열(favoriteId 내림차순). 없으면 빈 배열.
  Future<List<FavoriteResponseDto>> fetchMyFavorites() async {
    final response = await _dio.get('/v8/favorites');
    final body = CommonResponse<List<FavoriteResponseDto>>.fromJson(
      response.data as Map<String, dynamic>,
      (value) =>
          (value as List<dynamic>).map(FavoriteResponseDto.fromJson).toList(),
    );
    return body.result ?? const [];
  }

  // 200, result {isFavorite}. 응답에 movieId가 없어 요청한 값을 함께 넘긴다.
  Future<FavoriteCheckDto> checkFavorite({required int movieId}) async {
    final response = await _dio.get('/v8/favorites/$movieId');
    final body = CommonResponse<FavoriteCheckDto>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => FavoriteCheckDto.fromJson(value, movieId: movieId),
    );
    final result = body.result;
    if (result == null) throw StateError('즐겨찾기 여부 result가 없습니다.');
    return result;
  }

  // 200, result null. 평점 삭제처럼 본문을 DTO로 파싱하지 않고, 예외가 없으면 성공이다.
  Future<void> deleteFavorite({required int movieId}) async {
    final response = await _dio.delete('/v8/favorites/$movieId');
    if (response.statusCode != 200) {
      throw StateError('예상하지 못한 즐겨찾기 해제 응답: ${response.statusCode}');
    }
  }
}
