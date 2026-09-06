import 'package:flutter/material.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';

// ================================================================================
// VIEW: Màn hình Đăng nhập
// ================================================================================
// View chỉ làm 2 việc:
//   1. Hiển thị UI dựa trên state của ViewModel
//   2. Gọi ViewModel khi user tương tác (nhấn nút, nhập text)
//
// View KHÔNG chứa logic nghiệp vụ (không gọi API, không xử lý data).
// ================================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controller cho input fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ViewModel
  final _viewModel = AuthViewModel();

  // UI state
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Lắng nghe thay đổi từ ViewModel → rebuild UI
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onViewModelChanged() {
    // Gọi setState để rebuild UI khi ViewModel thay đổi
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Xử lý khi nhấn nút Đăng nhập
  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await _viewModel.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      // Chuyển sang màn hình chính
      // Navigator.pushReplacementNamed(context, AppRoutes.tripList);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng nhập thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),

                // === Logo / Title ===
                const Icon(
                  Icons.travel_explore,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSizes.spaceM),
                const Text(
                  'FeelingTrip',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSizes.spaceXS),
                const Text(
                  'Lên kế hoạch cho chuyến đi của bạn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 48),

                // === Error Message ===
                if (_viewModel.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSizes.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    ),
                    child: Text(
                      _viewModel.errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceM),
                ],

                // === Email Input ===
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Nhập email của bạn',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập email';
                    }
                    if (!value.contains('@')) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spaceM),

                // === Password Input ===
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mật khẩu',
                    hintText: 'Nhập mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Vui lòng nhập mật khẩu';
                    }
                    if (value.length < 6) {
                      return 'Mật khẩu tối thiểu 6 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.spaceS),

                // === Quên mật khẩu ===
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Navigator.pushNamed(context, AppRoutes.forgotPassword);
                    },
                    child: const Text('Quên mật khẩu?'),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceL),

                // === Nút Đăng nhập ===
                ElevatedButton(
                  onPressed: _viewModel.isLoading ? null : _onLoginPressed,
                  child: _viewModel.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Đăng nhập',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
                const SizedBox(height: AppSizes.spaceL),

                // === Chuyển sang Đăng ký ===
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Chưa có tài khoản? ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    GestureDetector(
                      onTap: () {
                        // Navigator.pushNamed(context, AppRoutes.register);
                      },
                      child: const Text(
                        'Đăng ký ngay',
                        style: TextStyle(
                          color: AppColors.primary,
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
    );
  }
}
