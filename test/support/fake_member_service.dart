import 'package:dio/dio.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/models/rating_page_dto.dart';
import 'package:movielog/data/services/member_service.dart';

// 실제 서버 없이 응답을 돌려주는 MemberService. 사용 중인 닉네임·이메일과 실패 주입을 지원한다.
class FakeMemberService extends MemberService {
  FakeMemberService({
    this.takenNicknames = const {},
    this.takenEmails = const {},
    this.ratings = const [],
  }) : super(Dio());

  final Set<String> takenNicknames;
  final Set<String> takenEmails;
  final List<RatingDto> ratings;
  DioException? error;

  @override
  Future<bool> isNicknameAvailable(String nickname) async {
    _throwIfNeeded();
    return !takenNicknames.contains(nickname);
  }

  @override
  Future<bool> isEmailAvailable(String email) async {
    _throwIfNeeded();
    return !takenEmails.contains(email);
  }

  @override
  Future<RatingPageDto> fetchRatings(
    int memberId, {
    int page = 0,
    int size = 10,
  }) async {
    _throwIfNeeded();
    return RatingPageDto(
      content: ratings,
      page: page,
      size: size,
      totalElements: ratings.length,
      totalPages: 1,
      hasNext: false,
    );
  }

  void _throwIfNeeded() {
    final error = this.error;
    if (error != null) throw error;
  }
}
