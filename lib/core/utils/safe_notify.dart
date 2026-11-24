import 'package:flutter/foundation.dart';

// 화면이 사라진(dispose) 뒤에 늦게 도착한 응답이 notifyListeners()를 부르지 않게 막는다.
// ViewModel에 with SafeNotify를 붙이고 notifyListeners() 대신 notifyIfAlive()를 쓴다.
mixin SafeNotify on ChangeNotifier {
  bool _disposed = false;
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void notifyIfAlive() {
    if (!_disposed) notifyListeners();
  }
}
