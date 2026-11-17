import 'package:dio/dio.dart';
import 'package:movielog/data/models/member_info.dart';

// 내 정보 조회·수정. 둘 다 보호 API라 AuthInterceptor가 등록된 Client를 받는다.
class MemberApiService {
  MemberApiService(this._authDio);

  final Dio _authDio;

  Future<MemberInfo> fetchMe() async {
    final response = await _authDio.get('/v7/members/me');
    return parseMemberInfo(response.data);
  }

  // 성공 응답의 result가 수정된 내 정보 전체라 GET me를 다시 부를 필요가 없다.
  Future<MemberInfo> updateNickname(String nickname) async {
    final response = await _authDio.patch(
      '/v7/members/me',
      data: {'nickname': nickname},
    );
    return parseMemberInfo(response.data);
  }
}
