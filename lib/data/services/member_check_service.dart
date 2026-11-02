import 'package:dio/dio.dart';
import 'package:movielog/data/models/check_result.dart';

// 닉네임·이메일 중복 확인 (v5). HTTP와 DTO 변환만 담당한다.
class MemberCheckService {
  MemberCheckService(this._dio);

  final Dio _dio;

  // 한글 닉네임과 이메일의 @를 path에 넣기 전에 인코딩한다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v5/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v5/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }
}
