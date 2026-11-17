import 'dart:async';

import 'package:dio/dio.dart';
import 'package:movielog/core/storage/saved_email_storage.dart';
import 'package:movielog/core/storage/token_storage.dart';
import 'package:movielog/data/models/login_models.dart';
import 'package:movielog/data/models/member_info.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/auth_api_service.dart';
import 'package:movielog/data/services/member_api_service.dart';
import 'package:movielog/view_models/auth_view_model.dart';

// v7 공통 오류 응답을 가진 DioException
DioException apiError(int statusCode, String code, String message) {
  final options = RequestOptions(path: '/v7');
  return DioException(
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: statusCode,
      data: {
        'isSuccess': false,
        'code': code,
        'message': message,
        'result': null,
      },
    ),
    type: DioExceptionType.badResponse,
  );
}

DioException networkError() => DioException(
      requestOptions: RequestOptions(path: '/v7'),
      type: DioExceptionType.connectionError,
    );

MemberInfo member({String nickname = '태혁'}) => MemberInfo(
      email: 'taehyeok@umc.com',
      nickname: nickname,
      createdAt: DateTime.utc(2026, 10, 10, 3),
    );

RatingDto ratingDto(int ratingId, int movieId,
        {int score = 4, String? comment = '좋아요'}) =>
    RatingDto(
      ratingId: ratingId,
      movieId: movieId,
      score: score,
      comment: comment,
      createdAt: DateTime.utc(2026, 11, 16),
    );

// 메모리 토큰 저장소. 읽기·쓰기·삭제 실패를 주입할 수 있다.
class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.token]);

  String? token;
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  int deleteCalls = 0;

  @override
  Future<String?> readAccessToken() async {
    if (failRead) throw StateError('read failed');
    return token;
  }

  @override
  Future<void> saveAccessToken(String value) async {
    if (failWrite) throw StateError('write failed');
    token = value;
  }

  @override
  Future<void> deleteAccessToken() async {
    deleteCalls++;
    if (failDelete) throw StateError('delete failed');
    token = null;
  }
}

class FakeAuthApiService extends AuthApiService {
  FakeAuthApiService() : super(Dio());

  Object? result = const LoginResult(nickname: '태혁', accessToken: 'token-a');
  Completer<LoginResult>? pending;
  int calls = 0;

  @override
  Future<LoginResult> login(LoginRequest request) async {
    calls++;
    final pending = this.pending;
    if (pending != null) return pending.future;
    final result = this.result;
    if (result is Exception) throw result;
    return result as LoginResult;
  }
}

class FakeMemberApiService extends MemberApiService {
  FakeMemberApiService() : super(Dio());

  // MemberInfo 또는 DioException
  Object meResult = member();
  Object? updateResult;
  Completer<MemberInfo>? pendingMe;
  int fetchCalls = 0;
  final updatedNicknames = <String>[];

  @override
  Future<MemberInfo> fetchMe() async {
    fetchCalls++;
    final pending = pendingMe;
    if (pending != null) return pending.future;
    final result = meResult;
    if (result is Exception) throw result;
    return result as MemberInfo;
  }

  @override
  Future<MemberInfo> updateNickname(String nickname) async {
    updatedNicknames.add(nickname);
    final result = updateResult;
    if (result is Exception) throw result;
    return (result as MemberInfo?) ?? member(nickname: nickname);
  }
}

class MemorySavedEmailStorage extends SavedEmailStorage {
  String? email;

  @override
  Future<String?> read() async => email;

  @override
  Future<void> save(String value) async => email = value;

  @override
  Future<void> clear() async => email = null;
}

// 로그인된 AuthViewModel을 만든다.
Future<AuthViewModel> signedInAuth({
  FakeMemberApiService? memberApi,
  MemoryTokenStorage? storage,
  FakeAuthApiService? authApi,
}) async {
  final auth = AuthViewModel(
    authApi ?? FakeAuthApiService(),
    memberApi ?? FakeMemberApiService(),
    storage ?? MemoryTokenStorage('token-a'),
  );
  await auth.restoreSession();
  return auth;
}
