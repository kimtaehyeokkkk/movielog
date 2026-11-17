import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/view_models/auth_view_model.dart';

// 현재 로그인 세션에서 등록 응답으로 받은 평점 목록.
// v7에는 토큰 기반 "내 평점 목록" GET이 없고 로그인·내 정보 응답에 memberId도 없어서,
// 재시작 뒤 기존 내 평점 전체를 복원할 수 없다. 이번 세션에서 만든 평점만 들고 수정·삭제한다.
// 로그아웃·만료·다른 계정 로그인으로 sessionVersion이 바뀌면 비운다.
class SessionRatings extends ChangeNotifier {
  SessionRatings(this._auth) : _version = _auth.sessionVersion {
    _auth.addListener(_onAuthChanged);
  }

  final AuthViewModel _auth;
  int _version;
  List<RatingDto> _items = const [];

  // 최근에 등록한 평점이 위로 온다.
  List<RatingDto> get items => _items;

  void _onAuthChanged() {
    if (_auth.sessionVersion == _version) return;
    _version = _auth.sessionVersion;
    if (_items.isEmpty) return;
    _items = const [];
    notifyListeners();
  }

  // 요청을 보낼 때의 세션과 지금 세션이 같을 때만 반영한다. (이전 세션의 늦은 응답 무시)
  bool _accepts(int sessionVersion) =>
      sessionVersion == _auth.sessionVersion &&
      _auth.status == AuthStatus.signedIn;

  void add(RatingDto rating, {required int sessionVersion}) {
    if (!_accepts(sessionVersion)) return;
    _items = [
      rating,
      for (final item in _items)
        if (item.ratingId != rating.ratingId) item,
    ];
    notifyListeners();
  }

  // 수정 응답(수정된 평점 전체)으로 교체한다.
  void replace(RatingDto rating, {required int sessionVersion}) {
    if (!_accepts(sessionVersion)) return;
    _items = [
      for (final item in _items)
        item.ratingId == rating.ratingId ? rating : item,
    ];
    notifyListeners();
  }

  void remove(int ratingId, {required int sessionVersion}) {
    if (!_accepts(sessionVersion)) return;
    if (!_items.any((item) => item.ratingId == ratingId)) return;
    _items = [
      for (final item in _items)
        if (item.ratingId != ratingId) item,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
