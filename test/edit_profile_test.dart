import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movielog/edit_profile_screen.dart';
import 'package:movielog/login_screen.dart';
import 'package:movielog/profile_screen.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth.dart';

void main() {
  group('EditProfileViewModel', () {
    test('2~12자 규칙은 요청 전에 막는다', () async {
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: memberApi);
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('가'), isFalse);
      expect(viewModel.nicknameError, '닉네임은 2~12자로 입력해 주세요.');
      expect(memberApi.updatedNicknames, isEmpty);
    });

    test('글자 수는 String.length가 아니라 보이는 글자 기준으로 센다 (이모지)', () async {
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: memberApi);
      final viewModel = EditProfileViewModel(memberApi, auth);

      // 👨‍👩‍👧는 String.length가 8이지만 보이는 글자는 1개다.
      expect(viewModel.validateNickname('👨‍👩‍👧'), isNotNull);
      expect(viewModel.validateNickname('👨‍👩‍👧😀'), isNull);
      expect(viewModel.validateNickname('😀' * 12), isNull);
      expect(viewModel.validateNickname('😀' * 13), isNotNull);
    });

    test('지금 닉네임과 같으면 요청 없이 완료', () async {
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: memberApi);
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save(' 태혁 '), isTrue);
      expect(memberApi.updatedNicknames, isEmpty);
    });

    test('성공하면 응답으로 member를 교체한다', () async {
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: memberApi);
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('새닉네임'), isTrue);
      expect(auth.member?.nickname, '새닉네임');
      expect(viewModel.status, EditProfileStatus.success);
    });

    test('MEMBER409_1은 필드 오류로 보여주고 로그인은 유지한다', () async {
      final memberApi = FakeMemberApiService()
        ..updateResult = apiError(409, 'MEMBER409_1', '이미 사용 중인 닉네임입니다.');
      final auth = await signedInAuth(memberApi: memberApi);
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('영화광'), isFalse);
      expect(viewModel.nicknameError, '이미 사용 중인 닉네임입니다.');
      expect(viewModel.message, isNull);
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.member?.nickname, '태혁');
    });

    test('네트워크 실패는 Snackbar 문구로, 로그아웃하지 않는다', () async {
      final memberApi = FakeMemberApiService()..updateResult = networkError();
      final auth = await signedInAuth(memberApi: memberApi);
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('새닉네임'), isFalse);
      expect(viewModel.message, contains('네트워크'));
      expect(viewModel.nicknameError, isNull);
      expect(auth.status, AuthStatus.signedIn);
    });

    test('AUTH401_3이면 세션을 정리하고 만료 안내를 켠다', () async {
      final memberApi = FakeMemberApiService()
        ..updateResult = apiError(401, 'AUTH401_3', '유효하지 않은 토큰입니다.');
      final auth = await signedInAuth(memberApi: memberApi);
      final viewModel = EditProfileViewModel(memberApi, auth);

      expect(await viewModel.save('새닉네임'), isFalse);
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.sessionExpired, isTrue);
    });
  });

  group('화면', () {
    testWidgets('마이페이지는 내 정보·가입일·로그아웃을 보여준다', (tester) async {
      final auth = await signedInAuth();
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: auth,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      expect(find.text('내 프로필'), findsOneWidget);
      expect(find.text('태혁'), findsOneWidget);
      expect(find.text('taehyeok@umc.com'), findsOneWidget);
      expect(find.textContaining('가입'), findsOneWidget);
      expect(find.text('로그아웃'), findsOneWidget);
      expect(find.text('프로필 수정'), findsOneWidget);
    });

    testWidgets('프로필 수정은 높이가 줄어도(키보드) 넘치지 않고 저장 버튼까지 스크롤된다',
        (tester) async {
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: memberApi);
      tester.view.physicalSize = const Size(400, 260);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: auth,
          child: ChangeNotifierProvider<EditProfileViewModel>(
            create: (_) => EditProfileViewModel(memberApi, auth),
            child: const MaterialApp(home: EditProfileScreen()),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, '저장'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.widgetWithText(ElevatedButton, '저장'), findsOneWidget);
    });

    testWidgets('마이페이지는 내 정보 실패 시 재시도 버튼을 보여준다', (tester) async {
      final memberApi = FakeMemberApiService();
      final auth = await signedInAuth(memberApi: memberApi);
      await auth.logout();
      await auth.login('a@umc.com', 'Password1!');
      memberApi.meResult = networkError();
      await auth.loadMember();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: auth,
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      expect(find.text('내 정보를 불러오지 못했어요.'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('세션 만료로 로그인 화면이 열리면 Snackbar를 한 번만 보여준다', (tester) async {
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService()
          ..meResult = apiError(401, 'AUTH401_4', '토큰이 만료되었습니다.'),
        MemoryTokenStorage('expired'),
      );
      await auth.restoreSession();
      expect(auth.sessionExpired, isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: auth,
          child: MaterialApp(
            home: LoginScreen(savedEmailStorage: MemorySavedEmailStorage()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsOneWidget);
      expect(auth.sessionExpired, isFalse);
    });

    testWidgets('저장된 이메일 읽기가 늦게 끝나도 그 사이 입력한 이메일·체크를 덮어쓰지 않는다',
        (tester) async {
      final auth = AuthViewModel(
        FakeAuthApiService(),
        FakeMemberApiService(),
        MemoryTokenStorage(),
      );
      await auth.restoreSession();
      final savedEmail = MemorySavedEmailStorage()..pendingRead = Completer();

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: auth,
          child: MaterialApp(home: LoginScreen(savedEmailStorage: savedEmail)),
        ),
      );
      await tester.enterText(find.byType(TextFormField).first, 'new@umc.com');
      savedEmail.pendingRead!.complete('old@umc.com');
      await tester.pump();

      expect(find.text('new@umc.com'), findsOneWidget);
      expect(find.text('old@umc.com'), findsNothing);
      final checkbox =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkbox.value, isFalse);
    });

    testWidgets('로그인 실패(AUTH401_1)는 Form 문구만 보여주고 만료 Snackbar는 없다',
        (tester) async {
      final auth = AuthViewModel(
        FakeAuthApiService()
          ..result = apiError(401, 'AUTH401_1', '이메일 또는 비밀번호가 올바르지 않습니다.'),
        FakeMemberApiService(),
        MemoryTokenStorage(),
      );
      await auth.restoreSession();
      final savedEmail = MemorySavedEmailStorage()..email = 'a@umc.com';

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthViewModel>.value(
          value: auth,
          child: MaterialApp(home: LoginScreen(savedEmailStorage: savedEmail)),
        ),
      );
      await tester.pump();
      // Challenge: 저장된 이메일이 채워지고 체크박스가 켜져 있다.
      expect(find.text('a@umc.com'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
      await tester.tap(find.widgetWithText(ElevatedButton, '로그인'));
      await tester.pump();
      await tester.pump();

      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(find.text('로그인이 만료됐어요. 다시 로그인해 주세요.'), findsNothing);
      expect(savedEmail.email, 'a@umc.com'); // 실패하면 저장 상태를 바꾸지 않는다.
    });
  });
}
