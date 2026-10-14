import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../viewmodels/auth_viewmodel.dart';

const supportEmail = 'feelingtrip.official@gmail.com';

Uri buildAccountSupportEmail(String email) {
  const subject = '[FeelingTrip] Đề nghị xem xét tài khoản bị khóa';
  final body =
      'Chào đội ngũ FeelingTrip,\n'
      'Tôi muốn đề nghị xem xét lại việc khóa tài khoản.\n\n'
      'Email tài khoản: $email\n\n'
      'Nội dung giải thích:\n\n\n'
      'Thông tin hoặc bằng chứng bổ sung (nếu có):\n\n'
      'Cảm ơn đội ngũ hỗ trợ.';
  return Uri(
    scheme: 'mailto',
    path: supportEmail,
    query:
        'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
}

class BlockedAccountScreen extends StatefulWidget {
  const BlockedAccountScreen({super.key, required this.email});
  final String email;
  @override
  State<BlockedAccountScreen> createState() => _BlockedAccountScreenState();
}

class _BlockedAccountScreenState extends State<BlockedAccountScreen> {
  bool _openingEmail = false;
  Future<void> _contact() async {
    if (_openingEmail) return;
    setState(() => _openingEmail = true);
    var opened = false;
    try {
      opened = await launchUrl(
        buildAccountSupportEmail(widget.email),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() => _openingEmail = false);
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không mở được ứng dụng email. Bạn có thể sao chép địa chỉ hỗ trợ bên dưới.',
          ),
        ),
      );
    }
  }

  Future<void> _copyEmail() async {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã sao chép email hỗ trợ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const AppTopBar(title: 'FeelingTrip', showBack: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.documentMaxWidth,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.lock_outline,
                    size: 56,
                    color: AppColors.textPrimary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tài khoản đã bị khóa',
                    textAlign: TextAlign.center,
                    style: text.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Bạn hiện chưa thể sử dụng FeelingTrip. Nếu muốn đề nghị xem xét lại, hãy liên hệ hỗ trợ.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tài khoản: ${widget.email}',
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
                  ),
                  const Divider(height: 48, color: AppColors.divider),
                  Text(
                    'Bạn có thể gửi thông tin và nội dung giải thích qua email.',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Liên hệ hỗ trợ',
                    icon: Icons.mail_outline,
                    isLoading: _openingEmail,
                    onPressed: _contact,
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: 'Quay lại đăng nhập',
                    variant: AppButtonVariant.secondary,
                    onPressed: () async {
                      await AuthScope.of(context).logout();
                      if (context.mounted) {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Email hỗ trợ',
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const SelectableText(
                    supportEmail,
                    textAlign: TextAlign.center,
                  ),
                  TextButton.icon(
                    onPressed: _copyEmail,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Sao chép địa chỉ email'),
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
