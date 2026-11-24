import 'package:movielog/data/models/common_response.dart';

// GET·PATCH /v8/members/me의 result. memberId와 password는 담기지 않는다.
class MemberInfo {
  const MemberInfo({
    required this.email,
    required this.nickname,
    required this.createdAt,
  });

  final String email;
  final String nickname;
  final DateTime createdAt;

  factory MemberInfo.fromJson(Map<String, dynamic> json) {
    return MemberInfo(
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

// 내 정보 응답은 공통 형식으로 감싸져 있다. result가 없으면 계약 오류로 본다.
MemberInfo parseMemberInfo(Object? data) {
  if (data is! Map<String, dynamic>) {
    throw StateError('내 정보 응답 형식이 올바르지 않습니다.');
  }
  final common = CommonResponse<MemberInfo>.fromJson(
    data,
    (value) => MemberInfo.fromJson(value as Map<String, dynamic>),
  );
  final member = common.result;
  if (member == null) throw StateError('내 정보 result가 없습니다.');
  return member;
}

// "2026.10.10 가입" (기기 시간대 기준)
String formatJoinedDate(DateTime createdAt) {
  final local = createdAt.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}.$month.$day 가입';
}
