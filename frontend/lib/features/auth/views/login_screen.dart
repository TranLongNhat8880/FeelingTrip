import '../../../shared/feedback/app_feedback.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/inputs/custom_text_field.dart';
import '../../../shared/buttons/custom_button.dart';
import '../models/password_policy.dart';
import 'widgets/password_feedback.dart';
import 'verify_email_screen.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _rememberMe = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final auth = AuthScope.of(context);
    await auth.login(_email.text, _password.text);
    if (!mounted) return;
    final email = auth.pendingVerificationEmail;
    if (email != null) {
      auth.clearError();
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => VerifyEmailScreen(email: email),
        ),
      );
    }
  }

  void _showForgotPasswordSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ForgotPasswordFlowSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'Đăng nhập',
                      style: TextStyle(
                        fontSize: AppSizes.fontAuthTitle,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 36),

                    // E-mail Input
                    CustomTextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !auth.isLoading,
                      label: 'Email',
                      hint: 'Nhập email của bạn',

                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Vui lòng nhập email';
                        if (!RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(email)) {
                          return 'Email không đúng định dạng';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Password Input
                    CustomTextField(
                      controller: _password,
                      isPassword: true,
                      textInputAction: TextInputAction.done,
                      enabled: !auth.isLoading,
                      onFieldSubmitted: (_) {
                        if (!auth.isLoading) _login();
                      },
                      label: 'Mật khẩu',
                      hint: 'Nhập mật khẩu',

                      validator: (value) => value == null || value.isEmpty
                          ? 'Vui lòng nhập mật khẩu'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Remember Me & Forgot Password Row
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        InkWell(
                          onTap: auth.isLoading
                              ? null
                              : () =>
                                    setState(() => _rememberMe = !_rememberMe),
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Checkbox(
                                  value: _rememberMe,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.border,
                                    width: 1.2,
                                  ),
                                  onChanged: auth.isLoading
                                      ? null
                                      : (val) => setState(
                                          () => _rememberMe = val ?? false,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Flexible(
                                child: Text(
                                  'Ghi nhớ đăng nhập',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: AppSizes.fontSmall,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: auth.isLoading
                              ? null
                              : _showForgotPasswordSheet,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Quên mật khẩu?',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: AppSizes.fontSmall,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Error Message
                    if (auth.errorMessage != null) ...[
                      AppInlineNotice(
                        message: auth.errorMessage!,
                        tone: AppStatusTone.error,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Sign In Button
                    CustomButton(
                      text: 'Đăng nhập',
                      onPressed: _login,
                      isLoading: auth.isLoading,
                    ),
                    const SizedBox(height: 32),

                    // or continue with Divider
                    const Row(
                      children: [
                        Expanded(
                          child: Divider(color: AppColors.border, thickness: 1),
                        ),
                        Flexible(
                          flex: 4,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'hoặc tiếp tục với',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: AppSizes.fontSmall,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: AppColors.border, thickness: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Chỉ Google được dự kiến hỗ trợ.
                    Center(
                      child: Semantics(
                        button: true,
                        label: 'Đăng nhập bằng Google',
                        child: _socialCard(
                          onTap: auth.isLoading
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Đăng nhập Google chưa được kết nối. Vui lòng dùng email và mật khẩu.',
                                      ),
                                    ),
                                  );
                                },
                          child: Image.asset(
                            'assets/images/google_logo.png',
                            width: 24,
                            height: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // or Create account Footer
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'hoặc ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppSizes.fontBody,
                          ),
                        ),
                        GestureDetector(
                          onTap: auth.isLoading
                              ? null
                              : () {
                                  auth.clearError();
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.register,
                                  );
                                },
                          child: const Text(
                            'Tạo tài khoản',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: AppSizes.fontBody,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _socialCard({required Widget child, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: Container(
        width: 76,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// 3-Step Forgot Password Flow Sheet matching Image 1
class _ForgotPasswordFlowSheet extends StatefulWidget {
  const _ForgotPasswordFlowSheet();

  @override
  State<_ForgotPasswordFlowSheet> createState() =>
      _ForgotPasswordFlowSheetState();
}

class _ForgotPasswordFlowSheetState extends State<_ForgotPasswordFlowSheet> {
  int _step =
      0; // 0: Forgot Password?, 1: Create new Password, 2: Password Changed
  final _email = TextEditingController();
  final _newPass = TextEditingController();
  final _retypePass = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _newPass.dispose();
    _retypePass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.sheetRadius),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Back button if in step 0 or 1
              if (_step < 2)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                    ),
                    onPressed: () {
                      if (_step > 0) {
                        setState(() => _step--);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              const SizedBox(height: 12),

              // STEP 0: Forgot Password?
              if (_step == 0) ...[
                const Text(
                  'Quên mật khẩu?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nhập email đã liên kết với tài khoản của bạn.',
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  controller: _email,
                  label: 'Email',
                  hint: 'Nhập email của bạn',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.cardRadius,
                        ),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Quên mật khẩu chưa được kết nối. Cần xác thực OTP trước khi đổi mật khẩu.',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Gửi yêu cầu',
                      style: TextStyle(
                        fontSize: AppSizes.fontControl,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Đã nhớ mật khẩu? ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: AppSizes.fontSmall,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Đăng nhập',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: AppSizes.fontSmall,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ]
              // STEP 1: Create new Password
              else if (_step == 1) ...[
                const Text(
                  'Đặt mật khẩu mới',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nhập mã OTP từ email và đặt mật khẩu mới.',
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  controller: _newPass,
                  isPassword: true,
                  label: 'Mật khẩu',
                  hint: 'Nhập mật khẩu mới',
                ),
                PasswordFeedback(controller: _newPass),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _retypePass,
                  isPassword: true,
                  label: 'Mật khẩu',
                  hint: 'Nhập lại mật khẩu mới',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.cardRadius,
                        ),
                      ),
                    ),
                    onPressed: () {
                      if (PasswordPolicy.missing(_newPass.text).isEmpty &&
                          _newPass.text == _retypePass.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Chưa cập nhật mật khẩu. Cần xác thực OTP và phản hồi thành công từ hệ thống.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text(
                      'Đặt lại mật khẩu',
                      style: TextStyle(
                        fontSize: AppSizes.fontControl,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ]
              // STEP 2: Password Changed
              else ...[
                const SizedBox(height: 20),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Đã đổi mật khẩu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mật khẩu đã được cập nhật. Vui lòng đăng nhập lại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppSizes.fontBody,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: AppSizes.buttonHeight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.cardRadius,
                        ),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Về đăng nhập',
                      style: TextStyle(
                        fontSize: AppSizes.fontControl,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
