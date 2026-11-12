import 'package:dio/dio.dart';
import 'package:movielog/data/models/check_result.dart';
import 'package:movielog/data/models/common_response.dart';
import 'package:movielog/data/models/create_member_request.dart';
import 'package:movielog/data/models/sign_up_models.dart';

// 회원가입 관련 요청 (6주차 MemberCheckService에서 이름 변경). HTTP와 DTO 변환만 담당한다.
class SignUpService {
  SignUpService(this._dio);

  final Dio _dio;

  // 성공 응답은 v5와 같은 직접 객체({"available": bool})다.
  // 한글 닉네임과 이메일의 @를 path에 넣기 전에 인코딩한다.
  Future<bool> checkNickname(String nickname) async {
    final encoded = Uri.encodeComponent(nickname.trim());
    final response = await _dio.get('/v6/members/nickname/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  Future<bool> checkEmail(String email) async {
    final encoded = Uri.encodeComponent(email.trim());
    final response = await _dio.get('/v6/members/email/$encoded');
    return CheckResult.fromJson(response.data as Map<String, dynamic>)
        .available;
  }

  // 201 + 공통 응답. result 안에 memberId·email·nickname이 있다.
  Future<CommonResponse<SignUpResult>> signUp(
    CreateMemberRequest request,
  ) async {
    final response = await _dio.post('/v6/members', data: request.toJson());
    return CommonResponse<SignUpResult>.fromJson(
      response.data as Map<String, dynamic>,
      (value) => SignUpResult.fromJson(value as Map<String, dynamic>),
    );
  }
}

// 400(비밀번호 형식)·409(이메일/닉네임 중복) 모두 message가 사용자에게 보여줄 문장이라 그대로 쓴다.
String writeSignUpErrorMessage(DioException error) {
  final data = error.response?.data;
  final common = data is Map<String, dynamic>
      ? CommonResponse<Object?>.fromJson(data, (value) => value)
      : null;
  return common?.message ?? '회원가입에 실패했습니다. 잠시 후 다시 시도해 주세요.';
}
