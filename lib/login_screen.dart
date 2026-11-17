import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:movielog/core/storage/saved_email_storage.dart';
import 'package:movielog/theme/app_colors.dart';
import 'package:movielog/view_models/auth_view_model.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:provider/provider.dart';

// 로그인 화면은 AuthViewModel.login()만 호출한다. 성공하면 status가 signedIn이 되고
// Router의 redirect가 /home으로 보낸다. (이 화면에서 직접 context.go('/home') 하지 않음)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.savedEmailStorage});

  // 테스트에서 바꿔 끼울 수 있게 주입받는다. 없으면 SharedPreferences 구현을 쓴다.
  final SavedEmailStorage? savedEmailStorage;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final AuthViewModel _auth;
  late final SavedEmailStorage _savedEmail;
  // Challenge: 이메일 저장 체크박스
  bool _rememberEmail = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthViewModel>();
    _savedEmail = widget.savedEmailStorage ?? SavedEmailStorage();
    // 화면이 열려 있는 동안 만료되는 경우와, 이미 만료된 상태로 처음 열리는 경우를 모두 처리한다.
    _auth.addListener(_showSessionExpired);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSessionExpired());
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final email = await _savedEmail.read();
      if (!mounted || email == null || email.isEmpty) return;
      setState(() {
        _email.text = email;
        _rememberEmail = true;
      });
    } catch (_) {
      // 저장된 이메일을 못 읽어도 로그인은 할 수 있다.
    }
  }

  // ViewModel은 "만료로 로그아웃됐다"는 사실만 들고, Snackbar는 화면이 띄운다.
  void _showSessionExpired() {
    if (!mounted || !_auth.sessionExpired) return;
    _auth.consumeSessionExpired(); // 먼저 꺼서 같은 안내가 반복되지 않게 한다.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('로그인이 만료됐어요. 다시 로그인해 주세요.')),
      );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final remember = _rememberEmail;

    await _auth.login(email, _password.text);

    // 로그인에 성공했을 때만 체크 상태를 반영한다. 비밀번호·토큰은 저장하지 않는다.
    if (_auth.status != AuthStatus.signedIn) return;
    try {
      if (remember) {
        await _savedEmail.save(email);
      } else {
        await _savedEmail.clear();
      }
    } catch (_) {
      // 이메일 저장은 편의 기능이라 실패해도 로그인 흐름을 막지 않는다.
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_showSessionExpired);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final loading = auth.status == AuthStatus.authenticating;
    final enabled = !loading && !auth.storageCleanupInProgress;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('로그인'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                SvgPicture.asset(
                  'assets/logos/movielog_logo.svg',
                  width: 72,
                  height: 72,
                  colorFilter: const ColorFilter.mode(
                    AppColors.violet,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'MovieLog에 로그인',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _email,
                  enabled: enabled,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _decoration('이메일', Icons.email_outlined),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? '이메일을 입력해 주세요.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: enabled,
                  obscureText: true, // 비밀번호는 화면·캡처에 보이지 않게 항상 가린다.
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => enabled ? _submit() : null,
                  decoration: _decoration('비밀번호', Icons.lock_outline),
                  validator: (value) =>
                      (value?.isEmpty ?? true) ? '비밀번호를 입력해 주세요.' : null,
                ),
                // Challenge: 이메일만 저장한다. (비밀번호·토큰 X)
                CheckboxListTile(
                  value: _rememberEmail,
                  onChanged: enabled
                      ? (value) => setState(() => _rememberEmail = value ?? false)
                      : null,
                  title: const Text('이메일 저장'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
                // 로그인 실패(AUTH401_1)·저장 실패는 Form 아래 문구로 보여준다. (만료 안내와 구분)
                if (auth.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      auth.message!,
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 32),
                MovieLogButton(
                  label: '로그인',
                  width: double.infinity,
                  isLoading: loading,
                  onPressed: enabled ? _submit : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: enabled ? () => context.push('/register') : null,
                  child: const Text('회원가입'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
