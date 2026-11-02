import 'package:flutter/material.dart';
import 'package:movielog/view_models/sign_up_view_model.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movielog_button.dart';
import 'package:movielog/widgets/movielog_text_form_field.dart';
import 'package:movielog/widgets/terms_agreement.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nicknameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _nicknameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _agreedToTerms = false;
  bool _obscurePassword = true;

  bool _nicknameTouched = false;
  bool _emailTouched = false;
  bool _passwordTouched = false;

  static final _emailRegex =
      RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  @override
  void initState() {
    super.initState();
    _nicknameFocusNode.addListener(_handleNicknameFocusChange);
    _emailFocusNode.addListener(_handleEmailFocusChange);
    _passwordFocusNode.addListener(_handlePasswordFocusChange);
  }

  void _handleNicknameFocusChange() {
    if (!_nicknameFocusNode.hasFocus && !_nicknameTouched) {
      setState(() => _nicknameTouched = true);
    }
  }

  void _handleEmailFocusChange() {
    if (!_emailFocusNode.hasFocus && !_emailTouched) {
      setState(() => _emailTouched = true);
    }
  }

  void _handlePasswordFocusChange() {
    if (!_passwordFocusNode.hasFocus && !_passwordTouched) {
      setState(() => _passwordTouched = true);
    }
  }

  @override
  void dispose() {
    _nicknameFocusNode.removeListener(_handleNicknameFocusChange);
    _emailFocusNode.removeListener(_handleEmailFocusChange);
    _passwordFocusNode.removeListener(_handlePasswordFocusChange);

    _nicknameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // 형식 검증과 함께, 닉네임·이메일 모두 서버에서 "사용 가능"을 받아야 가입할 수 있다.
  bool _canSubmit(SignUpViewModel viewModel) {
    final password = _passwordController.text;

    return _validateNickname(_nicknameController.text) == null &&
        _validateEmail(_emailController.text) == null &&
        password.length >= 8 &&
        _agreedToTerms &&
        viewModel.nicknameCheckStatus == CheckStatus.available &&
        viewModel.emailCheckStatus == CheckStatus.available;
  }

  String? _validateNickname(String? value) {
    final nickname = value?.trim() ?? '';

    if (nickname.isEmpty) {
      return '닉네임을 입력해주세요.';
    }
    if (nickname.length < 2) {
      return '닉네임은 두 글자 이상 입력해주세요.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return '이메일을 입력해주세요.';
    }
    if (!_emailRegex.hasMatch(email)) {
      return '올바른 이메일 형식이 아닙니다.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return '비밀번호를 입력해주세요.';
    }
    if (password.length < 8) {
      return '비밀번호는 8자 이상 입력해주세요.';
    }
    return null;
  }

  bool _hasError(bool touched, String? Function(String?) validator, String text) {
    if (!touched) return false;
    return validator(text) != null;
  }

  // 입력창 안의 상태 아이콘. 서버 확인 결과가 있으면 그것을, 없으면 형식 검사 결과를 보여준다.
  Widget? _buildCheckIcon(
    BuildContext context, {
    required bool touched,
    required TextEditingController controller,
    required String? Function(String?) validator,
    required CheckStatus status,
    required String? serverErrorText,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    if (serverErrorText != null ||
        (touched && controller.text.isNotEmpty && validator(controller.text) != null)) {
      return Icon(Icons.error, color: colorScheme.error);
    }
    if (status == CheckStatus.available) {
      return Icon(Icons.check_circle, color: colorScheme.primary);
    }
    return null;
  }

  Widget _buildPasswordVisibilityButton() {
    return IconButton(
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
      ),
      onPressed: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
    );
  }

  void _submit() {
    setState(() {
      _nicknameTouched = true;
      _emailTouched = true;
      _passwordTouched = true;
    });

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    // 회원가입 POST는 v6부터라 이번 주차에는 요청을 보내지 않고 홈으로 이동만 한다.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('회원가입이 완료되었습니다.'),
      ),
    );
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    // 중복 확인 상태가 입력창 에러·버튼·가입 가능 여부에 모두 쓰여서 화면 전체가 구독한다.
    final viewModel = context.watch<SignUpViewModel>();
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final nicknameHasError =
        _hasError(_nicknameTouched, _validateNickname, _nicknameController.text) ||
            viewModel.nicknameErrorText != null;
    final emailHasError =
        _hasError(_emailTouched, _validateEmail, _emailController.text) ||
            viewModel.emailErrorText != null;
    final passwordHasError =
        _hasError(_passwordTouched, _validatePassword, _passwordController.text);

    Widget availableText(String text) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, top: 4),
        child: Text(
          text,
          style: textTheme.bodySmall?.copyWith(color: colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      appBar: const CommonAppBar(title: '회원가입'),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxFormWidth =
                constraints.maxWidth >= 700 ? 560.0 : double.infinity;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxFormWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '환영합니다!\n간단한 정보만 입력하고 시작해보세요.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        _FieldWithCheckButton(
                          field: MovieLogTextFormField(
                            controller: _nicknameController,
                            focusNode: _nicknameFocusNode,
                            labelText: '닉네임',
                            hintText: '닉네임을 입력해주세요',
                            prefixIcon: Icons.person_outline,
                            hasError: nicknameHasError,
                            errorText: viewModel.nicknameErrorText,
                            suffixIcon: _buildCheckIcon(
                              context,
                              touched: _nicknameTouched,
                              controller: _nicknameController,
                              validator: _validateNickname,
                              status: viewModel.nicknameCheckStatus,
                              serverErrorText: viewModel.nicknameErrorText,
                            ),
                            validator: (value) => _nicknameTouched
                                ? _validateNickname(value)
                                : null,
                            autovalidateMode: _nicknameTouched
                                ? AutovalidateMode.always
                                : AutovalidateMode.disabled,
                            onChanged: (value) {
                              setState(() {});
                              viewModel.onNicknameChanged(value);
                            },
                            onFieldSubmitted: (_) =>
                                _emailFocusNode.requestFocus(),
                          ),
                          // 입력창 옆 보조 버튼: width를 주지 않아 내용 기반 크기
                          button: MovieLogButton(
                            label: '중복 확인',
                            isLoading: viewModel.nicknameCheckStatus ==
                                CheckStatus.checking,
                            onPressed: viewModel.canCheckNickname &&
                                    _validateNickname(
                                          _nicknameController.text,
                                        ) ==
                                        null
                                ? () => viewModel
                                    .checkNickname(_nicknameController.text)
                                : null,
                          ),
                        ),
                        if (viewModel.nicknameCheckStatus ==
                            CheckStatus.available)
                          availableText('사용할 수 있는 닉네임입니다.'),
                        const SizedBox(height: 16),
                        _FieldWithCheckButton(
                          field: MovieLogTextFormField(
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            labelText: '이메일',
                            hintText: '이메일 주소를 입력해주세요',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            hasError: emailHasError,
                            errorText: viewModel.emailErrorText,
                            suffixIcon: _buildCheckIcon(
                              context,
                              touched: _emailTouched,
                              controller: _emailController,
                              validator: _validateEmail,
                              status: viewModel.emailCheckStatus,
                              serverErrorText: viewModel.emailErrorText,
                            ),
                            validator: (value) =>
                                _emailTouched ? _validateEmail(value) : null,
                            autovalidateMode: _emailTouched
                                ? AutovalidateMode.always
                                : AutovalidateMode.disabled,
                            onChanged: (value) {
                              setState(() {});
                              viewModel.onEmailChanged(value);
                            },
                            onFieldSubmitted: (_) =>
                                _passwordFocusNode.requestFocus(),
                          ),
                          button: MovieLogButton(
                            label: '중복 확인',
                            isLoading: viewModel.emailCheckStatus ==
                                CheckStatus.checking,
                            onPressed: viewModel.canCheckEmail &&
                                    _validateEmail(_emailController.text) ==
                                        null
                                ? () => viewModel
                                    .checkEmail(_emailController.text)
                                : null,
                          ),
                        ),
                        if (viewModel.emailCheckStatus == CheckStatus.available)
                          availableText('사용할 수 있는 이메일입니다.'),
                        const SizedBox(height: 16),
                        MovieLogTextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          labelText: '비밀번호',
                          hintText: '비밀번호를 입력해주세요',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          hasError: passwordHasError,
                          suffixIcon: _buildPasswordVisibilityButton(),
                          textInputAction: TextInputAction.done,
                          validator: (value) => _passwordTouched
                              ? _validatePassword(value)
                              : null,
                          autovalidateMode: _passwordTouched
                              ? AutovalidateMode.always
                              : AutovalidateMode.disabled,
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) {
                            FocusScope.of(context).unfocus();
                          },
                        ),
                        const SizedBox(height: 24),
                        TermsAgreement(
                          agreed: _agreedToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreedToTerms = value;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        // Form 하단 버튼: 부모가 허용하는 최대 너비
                        MovieLogButton(
                          label: '가입하기',
                          width: double.infinity,
                          onPressed: _canSubmit(viewModel) ? _submit : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// 입력창과 중복 확인 버튼을 Row의 형제로 8px 간격을 두고 나란히 놓는다.
class _FieldWithCheckButton extends StatelessWidget {
  const _FieldWithCheckButton({required this.field, required this.button});

  final Widget field;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Row(
      // 에러 문구가 생겨 입력창 높이가 바뀌어도 버튼은 입력창 줄에 맞춘다.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: button,
        ),
      ],
    );
  }
}
