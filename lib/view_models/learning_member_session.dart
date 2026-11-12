import 'package:flutter/foundation.dart';

// 회원가입 결과의 memberId를 보관하는 학습용 현재 회원 상태.
// memberId를 안다는 것은 인증이 아니다. 메모리에만 있어 앱을 재시작하면 사라지고,
// JWT 주차에는 서버가 토큰으로 현재 회원을 식별하도록 바뀐다.
class LearningMemberSession extends ChangeNotifier {
  int? memberId;

  void setMemberId(int id) {
    memberId = id;
    notifyListeners();
  }

  void clear() {
    memberId = null;
    notifyListeners();
  }
}
