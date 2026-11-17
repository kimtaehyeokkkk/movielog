import 'package:flutter/material.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/view_models/edit_profile_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _controller;
  late final String _originalNickname;

  @override
  void initState() {
    super.initState();
    _originalNickname = context.read<AuthViewModel>().member?.nickname ?? '';
    _controller = TextEditingController(text: _originalNickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Challenge: 저장하지 않은 변경 내용이 있는지
  bool get _isDirty => _controller.text.trim() != _originalNickname;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final viewModel = context.read<EditProfileViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final success = await viewModel.save(_controller.text);
    if (!mounted) return;

    if (success) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('프로필을 수정했어요.')));
      // pop()은 PopScope를 거치지 않아 확인 Dialog 없이 마이페이지로 돌아간다.
      // 마이페이지에는 새 닉네임이 이미 반영되어 있다.
      navigator.pop();
    } else if (viewModel.message != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(viewModel.message!)));
    }
  }

  // Challenge: 변경 내용이 있을 때 뒤로가기(앱바·시스템) → 확인 Dialog
  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('변경 내용을 저장하지 않고 나갈까요?'),
        content: const Text('입력한 닉네임은 저장되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('계속 수정'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthViewModel, String?>((a) => a.member?.email);

    return Consumer<EditProfileViewModel>(
      builder: (context, viewModel, child) {
        final saving = viewModel.isSaving;
        return PopScope(
          // 저장 중에는 나갈 수 없고, 변경 내용이 있으면 먼저 확인한다.
          canPop: !saving && !_isDirty,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || saving) return;
            _confirmLeave();
          },
          child: Scaffold(
            appBar: CommonAppBar(
              title: '프로필 수정',
              centerTitle: true,
              // maybePop은 PopScope를 거치므로 시스템 뒤로가기와 같은 규칙을 따른다.
              onBack: saving ? null : () => Navigator.maybePop(context),
            ),
            // 키보드가 올라와 높이가 줄어도 저장 버튼까지 스크롤로 닿을 수 있게 한다.
            // 화면이 충분히 크면 minHeight로 늘려 저장 버튼을 아래쪽에 둔다.
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 48)
                          .clamp(0, double.infinity),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      initialValue: email,
                      enabled: false, // 이메일은 읽기 전용
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _controller,
                      enabled: !saving,
                      maxLength: 12,
                      onChanged: (_) {
                        setState(() {}); // 변경 여부(_isDirty) 갱신
                        viewModel.onNicknameChanged();
                      },
                      onSubmitted: (_) => saving ? null : _submit(),
                      decoration: InputDecoration(
                        labelText: '닉네임',
                        helperText: '2~12자',
                        errorText: viewModel.nicknameError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    MovieLogButton(
                      label: '저장',
                      width: double.infinity,
                      isLoading: saving,
                      onPressed: saving ? null : _submit,
                    ),
                  ],
                ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
