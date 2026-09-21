import 'package:flutter/material.dart';
import 'package:movielog/widgets/common_app_bar.dart';
import 'package:movielog/widgets/movielog_text_form_field.dart';
import 'package:movielog/widgets/terms_agreement.dart';

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

  bool _canSubmit() {
    final nickname = _nicknameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    return nickname.length >= 2 &&
        _emailRegex.hasMatch(email) &&
        password.length >= 8 &&
        _agreedToTerms;
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

  Widget? _buildStatusIcon(
    BuildContext context,
    bool touched,
    TextEditingController controller,
    String? Function(String?) validator,
  ) {
    if (!touched || controller.text.isEmpty) {
      return null;
    }

    final hasError = validator(controller.text) != null;

    return Icon(
      hasError ? Icons.error : Icons.check_circle,
      color: hasError
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nicknameHasError =
        _hasError(_nicknameTouched, _validateNickname, _nicknameController.text);
    final emailHasError =
        _hasError(_emailTouched, _validateEmail, _emailController.text);
    final passwordHasError =
        _hasError(_passwordTouched, _validatePassword, _passwordController.text);

    return Scaffold(
      appBar: CommonAppBar(
        title: '회원가입',
        onBack: () => Navigator.of(context).pop(),
      ),
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
                        MovieLogTextFormField(
                          controller: _nicknameController,
                          focusNode: _nicknameFocusNode,
                          labelText: '닉네임',
                          hintText: '닉네임을 입력해주세요',
                          prefixIcon: Icons.person_outline,
                          hasError: nicknameHasError,
                          suffixIcon: _buildStatusIcon(
                            context,
                            _nicknameTouched,
                            _nicknameController,
                            _validateNickname,
                          ),
                          validator: (value) =>
                              _nicknameTouched ? _validateNickname(value) : null,
                          autovalidateMode: _nicknameTouched
                              ? AutovalidateMode.always
                              : AutovalidateMode.disabled,
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) =>
                              _emailFocusNode.requestFocus(),
                        ),
                        const SizedBox(height: 16),
                        MovieLogTextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          labelText: '이메일',
                          hintText: '이메일 주소를 입력해주세요',
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          hasError: emailHasError,
                          suffixIcon: _buildStatusIcon(
                            context,
                            _emailTouched,
                            _emailController,
                            _validateEmail,
                          ),
                          validator: (value) =>
                              _emailTouched ? _validateEmail(value) : null,
                          autovalidateMode: _emailTouched
                              ? AutovalidateMode.always
                              : AutovalidateMode.disabled,
                          onChanged: (_) => setState(() {}),
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                        ),
                        const SizedBox(height: 16),
                        MovieLogTextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          labelText: '비밀번호',
                          hintText: '비밀번호를 입력해주세요',
                          prefixIcon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          hasError: passwordHasError,
                          suffixIcon: IconButton(
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
                          ),
                          textInputAction: TextInputAction.done,
                          validator: (value) =>
                              _passwordTouched ? _validatePassword(value) : null,
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
                        _SubmitButton(
                          enabled: _canSubmit(),
                          onPressed: () {
                            setState(() {
                              _nicknameTouched = true;
                              _emailTouched = true;
                              _passwordTouched = true;
                            });

                            final isValid =
                                _formKey.currentState?.validate() ?? false;
                            if (!isValid) return;

                            FocusScope.of(context).unfocus();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('회원가입이 완료되었습니다.'),
                              ),
                            );
                          },
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

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.enabled,
    required this.onPressed,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: enabled ? primary : primary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: enabled ? onPressed : null,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                '가입하기',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}