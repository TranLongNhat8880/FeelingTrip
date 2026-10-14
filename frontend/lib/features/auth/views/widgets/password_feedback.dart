import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import '../../models/password_policy.dart';

class PasswordFeedback extends StatelessWidget {
  const PasswordFeedback({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<TextEditingValue>(
    valueListenable: controller,
    builder: (context, value, child) {
      if (value.text.isEmpty) return const SizedBox.shrink();
      final missing = PasswordPolicy.missing(value.text);
      final valid = missing.isEmpty;
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
        child: Semantics(
          liveRegion: true,
          child: Text(
            valid
                ? 'Mật khẩu đáp ứng yêu cầu'
                : 'Mật khẩu còn thiếu:\n${missing.map((item) => '• $item').join('\n')}',
            style: TextStyle(
              fontSize: AppSizes.fontCaption,
              height: 1.5,
              color: valid ? AppColors.success : AppColors.warning,
            ),
          ),
        ),
      );
    },
  );
}
