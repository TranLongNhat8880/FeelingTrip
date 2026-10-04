import '../../../shared/layout/travel_decoration.dart';
import '../../../shared/feedback/app_feedback.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/inputs/custom_text_field.dart';
import '../../../shared/inputs/app_checkbox.dart';
import '../../../shared/buttons/custom_button.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../models/password_policy.dart';
import 'widgets/password_feedback.dart';
import 'verify_email_screen.dart';
import 'terms_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();

  bool _termsAccepted = false;
  String? _termsError;
  final _confirmPassword = TextEditingController();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    final auth = AuthScope.of(context);
    auth.clearError();
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  Future<void> _openTerms() async {
    final agreed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const TermsScreen()),
    );
    if (agreed == true && mounted) {
      setState(() {
        _termsAccepted = true;
        _termsError = null;
      });
    }
  }

  Future<void> _register() async {
    final isFormValid = _form.currentState!.validate();
    if (!_termsAccepted) {
      setState(() {
        _termsError =
            'Vui lòng đọc và đồng ý với Điều khoản sử dụng của FeelingTrip';
      });
    } else if (_termsError != null) {
      setState(() {
        _termsError = null;
      });
    }

    if (!isFormValid || !_termsAccepted) return;
    FocusScope.of(context).unfocus();

    final auth = AuthScope.of(context);
    final result = await auth.register(
      email: _email.text,
      password: _password.text,
      fullName: _fullName.text,
      termsAccepted: _termsAccepted,
      termsVersion: TermsScreen.version,
      phone: _phone.text.trim().isNotEmpty ? _phone.text.trim() : null,
    );

    if (!mounted) return;

    if (result.success) {
      auth.clearError();
      final email = _email.text.trim().toLowerCase();
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => VerifyEmailScreen(
            email: email,
            initialMessage: result.message,
            initialCooldown: 60,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    return TravelAuthLayout(
      title: 'Đăng ký',
      subtitle: 'Điền thông tin bên dưới để tạo tài khoản.',
      onBack: auth.isLoading ? null : _navigateToLogin,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text(
            'Đã có tài khoản? ',
            style: TextStyle(color: Color(0xFF5D6889), fontSize: 14),
          ),
          GestureDetector(
            onTap: auth.isLoading ? null : _navigateToLogin,
            child: const Text(
              'Đăng nhập',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _fullName,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              enabled: !auth.isLoading,
              label: 'Họ và tên',
              hint: 'Nhập họ và tên',
              prefixIcon: Icons.person_outline_rounded,
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Vui lòng nhập họ và tên';
                if (name.length < 2) {
                  return 'Họ và tên phải có ít nhất 2 ký tự';
                }
                if (name.length > 100) {
                  return 'Họ và tên không được vượt quá 100 ký tự';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // E-mail Input
            CustomTextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              enabled: !auth.isLoading,
              label: 'Email',
              hint: 'Nhập email của bạn',
              prefixIcon: Icons.mail_outline_rounded,
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Vui lòng nhập email';
                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                  return 'Email không đúng định dạng';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password Input
            CustomTextField(
              controller: _password,
              isPassword: true,
              textInputAction: TextInputAction.next,
              enabled: !auth.isLoading,
              label: 'Mật khẩu',
              hint: 'Nhập mật khẩu',
              prefixIcon: Icons.lock_outline_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng nhập mật khẩu';
                }
                return PasswordPolicy.missing(value).isEmpty
                    ? null
                    : 'Mật khẩu chưa đáp ứng yêu cầu bên dưới';
              },
            ),
            PasswordFeedback(controller: _password),
            const SizedBox(height: 16),

            // Xác nhận mật khẩu
            CustomTextField(
              controller: _confirmPassword,
              isPassword: true,
              textInputAction: TextInputAction.next,
              enabled: !auth.isLoading,
              label: 'Xác nhận mật khẩu',
              hint: 'Nhập lại mật khẩu',
              prefixIcon: Icons.lock_outline_rounded,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Vui lòng xác nhận mật khẩu';
                }
                if (value != _password.text) {
                  return 'Mật khẩu xác nhận không khớp';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone number Input
            CustomTextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              enabled: !auth.isLoading,
              label: 'Số điện thoại (không bắt buộc)',
              hint: 'Nhập số điện thoại',
              prefixIcon: Icons.phone_outlined,
              validator: (value) {
                final phone = value?.trim() ?? '';
                if (phone.isNotEmpty &&
                    !RegExp(r'^[0-9]{9,12}$').hasMatch(phone)) {
                  return 'Số điện thoại phải gồm 9–12 chữ số';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Error Message
            if (auth.errorMessage != null) ...[
              AppInlineNotice(
                message: auth.errorMessage!,
                tone: AppStatusTone.error,
              ),
              const SizedBox(height: 16),
            ],

            // Terms acceptance
            InkWell(
              onTap: auth.isLoading
                  ? null
                  : () {
                      setState(() {
                        _termsAccepted = !_termsAccepted;
                        if (_termsAccepted) _termsError = null;
                      });
                    },
              borderRadius: BorderRadius.circular(6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: AppCheckbox(
                      value: _termsAccepted,
                      hasError: _termsError != null,
                      onChanged: auth.isLoading
                          ? null
                          : (val) {
                              setState(() {
                                _termsAccepted = val;
                                if (_termsAccepted) _termsError = null;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tôi đã đọc và đồng ý với',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5D6889),
                            height: 1.4,
                          ),
                        ),
                        InkWell(
                          onTap: auth.isLoading ? null : _openTerms,
                          borderRadius: BorderRadius.circular(4),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              'Điều khoản sử dụng của FeelingTrip',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_termsError != null)
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 6),
                child: Text(
                  _termsError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.error,
                    height: 1.3,
                  ),
                ),
              ),
            const SizedBox(height: 22),

            // Create Account Button
            CustomButton(
              text: 'Tạo tài khoản',
              onPressed: _register,
              isLoading: auth.isLoading,
            ),
          ],
        ),
      ),
    );
  }
}
