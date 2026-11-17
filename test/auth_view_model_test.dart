import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/view_models/auth_view_model.dart';

import 'support/fake_auth.dart';

void main() {
  group('restoreSession (앱 시작)', () {
    test('저장된 토큰이 없으면 GET me 없이 signedOut', () async {
      final memberApi = FakeMemberApiService();
      final auth = AuthViewModel(
        FakeAuthApiService(),
        memberApi,
        MemoryTokenStorage(),
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.signedOut);
      expect(memberApi.fetchCalls, 0);
    });

    test('토큰이 있어도 GET me 검증이 끝나기 전에는 signedIn이 아니다', () async {
      final memberApi = FakeMemberApiService()
        ..pendingMe = Completer();
      final auth = AuthViewModel(
        FakeAuthApiService(),
        memberApi,
        MemoryTokenStorage('token-a'),
      );

      final restoring = auth.restoreSession();
      await Future<void>.delayed(Duration.zero);
      expect(auth.status, AuthStatus.initializing);

      memberApi.pendingMe!.complete(member());
      await restoring;
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.member?.nickname, '태혁');
      expect(auth.memberStatus, MemberLoadStatus.success);
    });

    test('만료 토큰(AUTH401_4)이면 토큰을 지우고 만료 안내와 함께 signedOut', () async {
      final storage = MemoryTokenStorage('expired');
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService()
          ..meResult = apiError(401, 'AUTH401_4', '토큰이 만료되었습니다.'),
        storage,
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(storage.token, isNull);
    });

    test('네트워크 실패는 토큰을 지우지 않고 재시도 상태', () async {
      final storage = MemoryTokenStorage('token-a');
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService()..meResult = networkError(),
        storage,
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.retryRequired);
      expect(auth.message, contains('로그인 상태를 확인하지 못했어요'));
      expect(storage.token, 'token-a');
      expect(storage.deleteCalls, 0);
    });

    test('저장소 읽기 실패도 재시도 상태 (서버 401과 구분)', () async {
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        MemoryTokenStorage('token-a')..failRead = true,
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.retryRequired);
      expect(auth.message, contains('인증 저장소를 읽지 못했어요'));
    });
  });

  group('login', () {
    test('성공하면 토큰을 저장하고 signedIn. 내 정보는 아직 부르지 않는다', () async {
      final storage = MemoryTokenStorage();
      final memberApi = FakeMemberApiService();
      final auth = AuthViewModel(FakeAuthApiService(), memberApi, storage);
      await auth.restoreSession();

      await auth.login('taehyeok@umc.com', 'Password1!');

      expect(auth.status, AuthStatus.signedIn);
      expect(storage.token, 'token-a');
      expect(auth.member, isNull);
      expect(memberApi.fetchCalls, 0);
    });

    test('AUTH401_1은 Form 문구만 남기고 만료 안내는 켜지 않는다', () async {
      final auth = AuthViewModel(
        FakeAuthApiService()
          ..result = apiError(401, 'AUTH401_1', '이메일 또는 비밀번호가 올바르지 않습니다.'),
        FakeMemberApiService(),
        MemoryTokenStorage(),
      );
      await auth.restoreSession();

      await auth.login('taehyeok@umc.com', 'wrong');

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, '이메일 또는 비밀번호를 확인해 주세요.');
      expect(auth.sessionExpired, isFalse);
    });

    test('토큰 저장에 실패하면 signedIn이 되지 않는다', () async {
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        MemoryTokenStorage()..failWrite = true,
      );
      await auth.restoreSession();

      await auth.login('taehyeok@umc.com', 'Password1!');

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.message, '로그인 정보를 안전하게 저장하지 못했어요.');
    });

    test('로그인 요청 중에는 다시 요청하지 않는다', () async {
      final authApi = FakeAuthApiService()..pending = Completer();
      final auth = AuthViewModel(
        authApi,
        FakeMemberApiService(),
        MemoryTokenStorage(),
      );
      await auth.restoreSession();

      final first = auth.login('a@umc.com', 'Password1!');
      await auth.login('a@umc.com', 'Password1!');
      expect(auth.status, AuthStatus.authenticating);
      expect(authApi.calls, 1);

      authApi.pending!.completeError(networkError());
      await first;
      expect(auth.status, AuthStatus.signedOut);
    });
  });

  group('loadMember · 만료 · 로그아웃', () {
    test('MainScreen이 부르는 loadMember는 한 번만 GET me를 보낸다', () async {
      final memberApi = FakeMemberApiService();
      final auth = AuthViewModel(
        FakeAuthApiService(),
        memberApi,
        MemoryTokenStorage(),
      );
      await auth.restoreSession();
      await auth.login('a@umc.com', 'Password1!');

      await auth.loadMember();
      await auth.loadMember();

      expect(memberApi.fetchCalls, 1);
      expect(auth.member?.nickname, '태혁');
    });

    test('loadMember 네트워크 실패는 로그아웃하지 않고 error로 남긴다', () async {
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: memberApi);
      memberApi.meResult = networkError();

      await auth.loadMember(force: true);

      expect(auth.status, AuthStatus.signedIn);
      expect(auth.memberStatus, MemberLoadStatus.error);
    });

    test('loadMember가 AUTH401_3을 받으면 세션을 정리하고 만료 안내를 켠다', () async {
      final memberApi = FakeMemberApiService();
      final storage = MemoryTokenStorage('token-a');
      final auth = await signedInAuth(memberApi: memberApi, storage: storage);
      memberApi.meResult = apiError(401, 'AUTH401_3', '유효하지 않은 토큰입니다.');

      await auth.loadMember(force: true);

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
      expect(auth.member, isNull);
      expect(storage.token, isNull);
    });

    test('직접 로그아웃은 토큰·member를 지우지만 만료 안내는 켜지 않는다', () async {
      final storage = MemoryTokenStorage('token-a');
      final auth = await signedInAuth(storage: storage);

      await auth.logout();

      expect(auth.status, AuthStatus.signedOut);
      expect(auth.member, isNull);
      expect(auth.sessionExpired, isFalse);
      expect(storage.token, isNull);
    });

    test('동시에 401이 여러 번 와도 세션 정리는 한 번만 한다', () async {
      final storage = MemoryTokenStorage('token-a');
      final auth = await signedInAuth(storage: storage);
      final version = auth.sessionVersion;

      await Future.wait([
        auth.expireSession(sessionVersion: version),
        auth.expireSession(sessionVersion: version),
      ]);

      expect(storage.deleteCalls, 1);
    });

    test('이전 세션의 늦은 401은 새로 로그인한 세션을 지우지 않는다', () async {
      final storage = MemoryTokenStorage('token-a');
      final auth = await signedInAuth(storage: storage);
      final oldVersion = auth.sessionVersion;

      await auth.logout();
      await auth.login('b@umc.com', 'Password1!');
      await auth.expireSession(sessionVersion: oldVersion);

      expect(auth.status, AuthStatus.signedIn);
      expect(storage.token, 'token-a');
    });

    test('로그아웃 뒤 도착한 이전 GET me 응답은 반영하지 않는다', () async {
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: memberApi);
      memberApi.pendingMe = Completer();

      final loading = auth.loadMember(force: true);
      await auth.logout();
      memberApi.pendingMe!.complete(member(nickname: '이전회원'));
      await loading;

      expect(auth.member, isNull);
      expect(auth.status, AuthStatus.signedOut);
    });

    test('updateMember는 수정 응답으로 member만 교체한다', () async {
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: memberApi);

      auth.updateMember(member(nickname: '새닉네임'));

      expect(auth.member?.nickname, '새닉네임');
      expect(memberApi.fetchCalls, 1); // restoreSession의 GET me 한 번뿐
    });
  });
}
