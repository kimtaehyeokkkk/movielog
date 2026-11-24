import 'package:dio/dio.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/movie_record_models.dart';

// Challenge: 평점과 즐겨찾기를 한 번에 저장하는 영화 기록 API. 보호 API라 보호용 Client를 받는다.
// 서버가 한 트랜잭션으로 처리해 둘 중 하나라도 실패하면 모두 저장되지 않는다.
class MovieRecordApiService {
  MovieRecordApiService(this._authDio);

  final Dio _authDio;

  Future<MovieRecordResult> saveMovieRecord(
    CreateMovieRecordRequest request,
  ) async {
    final response = await _authDio.post(
      '/v8/movie-records',
      data: request.toJson(),
    );
    final body = CommonResponse<MovieRecordResult>.fromJson(
      response.data as Map<String, dynamic>,
      MovieRecordResult.fromJson,
    );
    final result = body.result;
    if (result == null) throw StateError('영화 기록 result가 없습니다.');
    return result;
  }
}
