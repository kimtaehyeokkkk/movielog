import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:movielog/data/models/rating_dto.dart';
import 'package:movielog/data/services/member_service.dart';

enum MyRatingsLoadStatus { idle, loading, success, empty, error }

class MyRatingsViewModel extends ChangeNotifier {
  MyRatingsViewModel(this._service, {required this.memberId});

  final MemberService _service;
  final int memberId;

  List<RatingDto> ratings = const [];
  int totalElements = 0;
  MyRatingsLoadStatus status = MyRatingsLoadStatus.idle;
  String? message;

  bool _disposed = false;

  Future<void> load() async {
    if (status == MyRatingsLoadStatus.loading) return;

    status = MyRatingsLoadStatus.loading;
    message = null;
    notifyListeners();

    try {
      final page = await _service.fetchRatings(memberId);
      ratings = page.content;
      totalElements = page.totalElements;
      status = ratings.isEmpty
          ? MyRatingsLoadStatus.empty
          : MyRatingsLoadStatus.success;
    } on DioException catch (error) {
      status = MyRatingsLoadStatus.error;
      message = movieLogApiErrorMessage(error);
    } catch (error) {
      if (kDebugMode) debugPrint('[MyRatings] 응답 변환 실패: $error');
      status = MyRatingsLoadStatus.error;
      message = '평점 정보를 읽지 못했어요.';
    }

    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
