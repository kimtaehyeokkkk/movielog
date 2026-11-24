import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/session/session_guard.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

// 사용자별 데이터(즐겨찾기)를 다루는 Route의 시작점.
// 내 정보(member)가 준비되고 SessionGuard가 그 계정으로 세션을 시작할 때까지 로딩을 보여주고,
// 준비되면 builder로 ViewModel을 만든다. builder 쪽 Provider에는
// ValueKey('$email:$generation')를 붙여 계정·세션이 바뀌면 이전 ViewModel을 버리고 새로 만든다.
class SessionScoped extends StatelessWidget {
  const SessionScoped({
    super.key,
    required this.title,
    required this.builder,
  });

  final String title;
  final Widget Function(BuildContext context, String accountId, SessionGuard guard)
      builder;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final guard = context.read<SessionGuard>();
    final member = auth.member;

    if (member == null || guard.accountId != member.email) {
      // 내 정보 조회가 실패했으면 인디케이터만 계속 보여주지 않고 재시도를 준다.
      final failed = member == null &&
          auth.memberStatus == MemberLoadStatus.error;
      return Scaffold(
        appBar: CommonAppBar(
          title: title,
          centerTitle: true,
          onBack: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        body: Center(
          child: failed
              ? MovieLogButton(
                  label: '내 정보 다시 조회',
                  onPressed: () => auth.loadMember(force: true),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    return builder(context, member.email, guard);
  }
}
