import 'package:flutter/material.dart';

class TermsAgreement extends StatelessWidget {
  const TermsAgreement({
    super.key,
    required this.agreed,
    required this.onChanged,
  });

  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: agreed,
          onChanged: (value) => onChanged(value ?? false),
        ),
        const Expanded(
          child: Text('[필수] 이용약관 및 개인정보 처리방침에 동의합니다.'),
        ),
      ],
    );
  }
}