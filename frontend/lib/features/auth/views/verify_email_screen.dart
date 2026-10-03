import '../../../shared/feedback/app_feedback.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/buttons/custom_button.dart';
import '../../../core/constants/app_sizes.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../shared/inputs/app_otp_field.dart';
import '../../../core/constants/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../viewmodels/auth_viewmodel.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    this.initialMessage,
    this.initialCooldown = 0,
  });

  final String email;
  final String? initialMessage;
  final int initialCooldown;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _otp = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;
  DateTime? _resendAt;
  int _seconds = 0;
  String? _message;

  @override
  void initState() {
    super.initState();
    _message = widget.initialMessage;
    _startCooldown(widget.initialCooldown);
    // Auto-focus on entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    _seconds = seconds;
    _resendAt = DateTime.now().add(Duration(seconds: seconds));
    if (seconds == 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _resendAt!.difference(DateTime.now()).inMilliseconds;
      if (!mounted) return;
      setState(() => _seconds = remaining <= 0 ? 0 : (remaining / 1000).ceil());
      if (_seconds == 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (code.length != 6) return;
    FocusScope.of(context).unfocus();

    final success = await AuthScope.of(context).verifyOtp(widget.email, code);
    if (!mounted || !success) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  Future<void> _resend() async {
    final result = await AuthScope.of(context).resendOtp(widget.email);
    if (!mounted) return;
    setState(() {
      if (result.success) {
        _message = result.message;
        _otp.clear();
      }
      _startCooldown(60);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: auth.isLoading
              ? null
              : () {
                  auth.clearError();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  );
                },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppSizes.formMaxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top illustration badge
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.mark_email_read_outlined,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Xác thực email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle & Email Chip
                  const Text(
                    'Nhập mã OTP 6 chữ số để xác thực email:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppSizes.fontBody,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mail_outline,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                fontSize: AppSizes.fontBody,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Mã có hiệu lực trong 5 phút. Vui lòng kiểm tra cả hộp thư rác (Spam).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppSizes.fontSmall,
                      color: AppColors.textHint,
                      height: 1.4,
                    ),
                  ),

                  // Success/Info Message
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    AppInlineNotice(
                      message: _message!,
                      tone: _message!.contains('chưa gửi được email')
                          ? AppStatusTone.warning
                          : AppStatusTone.success,
                    ),
                  ],

                  // Error Message
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    AppInlineNotice(
                      message: auth.errorMessage!,
                      tone: AppStatusTone.error,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 6-Cell Modern OTP Input
                  AppOtpField(
                    controller: _otp,
                    focusNode: _focusNode,
                    enabled: !auth.isLoading,
                    hasError: auth.errorMessage != null,
                    onCompleted: (_) => _verify(),
                  ),

                  const SizedBox(height: 32),

                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _otp,
                    builder: (_, value, _) => CustomButton(
                      text: 'Xác thực tài khoản',
                      onPressed: value.text.length == 6 ? _verify : null,
                      isLoading: auth.isLoading,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Resend code option
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    runSpacing: 8,
                    children: [
                      const Text(
                        'Chưa nhận được mã? ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppSizes.fontBody,
                        ),
                      ),
                      TextButton(
                        onPressed: auth.isLoading || _seconds > 0
                            ? null
                            : _resend,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _seconds > 0
                              ? 'Gửi lại sau ${_seconds}s'
                              : 'Gửi lại mã OTP',
                          style: TextStyle(
                            color: _seconds > 0
                                ? AppColors.textHint
                                : AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: AppSizes.fontBody,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Back to login button
                  Center(
                    child: TextButton.icon(
                      onPressed: auth.isLoading
                          ? null
                          : () {
                              auth.clearError();
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.login,
                                (_) => false,
                              );
                            },
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      label: const Text(
                        'Quay lại Đăng nhập',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppSizes.fontBody,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
