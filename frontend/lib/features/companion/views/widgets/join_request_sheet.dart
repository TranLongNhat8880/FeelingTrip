import 'package:flutter/material.dart';
import 'package:feeling_trip/core/constants/app_colors.dart';
import 'package:feeling_trip/core/constants/app_sizes.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

// ================================================================================
// WIDGET: JoinRequestSheet
// ================================================================================
// Bottom sheet để gửi yêu cầu tham gia nhóm.
// ================================================================================

class JoinRequestSheet extends StatefulWidget {
  const JoinRequestSheet({
    super.key,
    required this.postTitle,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final String postTitle;
  final bool isSubmitting;
  final Future<void> Function(String? introduction) onSubmit;

  @override
  State<JoinRequestSheet> createState() => _JoinRequestSheetState();
}

class _JoinRequestSheetState extends State<JoinRequestSheet> {
  final _introController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSizes.sheetRadius),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPadding,
          16,
          AppSizes.screenPadding,
          24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
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
              const SizedBox(height: 20),

              Text('Gửi yêu cầu tham gia', style: text.titleLarge),
              const SizedBox(height: 6),
              Text(
                widget.postTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Lời giới thiệu
              CustomTextField(
                controller: _introController,
                label: 'Lời giới thiệu bản thân *',
                hint:
                    'Kể ngắn gọn về bạn: tính cách, sở thích du lịch, lý do muốn tham gia...',
                maxLines: 4,
                enabled: !(widget.isSubmitting || _submitting),
              ),
              const SizedBox(height: 8),
              Text(
                'Giới thiệu ngắn gọn, tối đa 1000 ký tự.',
                style: text.bodySmall?.copyWith(color: AppColors.textHint),
              ),
              const SizedBox(height: 28),

              CustomButton(
                text: 'Gửi yêu cầu',
                isLoading: widget.isSubmitting || _submitting,
                onPressed: _submitting
                    ? null
                    : () async {
                        final intro = _introController.text.trim();
                        if (intro.isEmpty || intro.length > 1000) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nhập lời giới thiệu từ 1 đến 1000 ký tự.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() => _submitting = true);
                        try {
                          await widget.onSubmit(
                            _introController.text.trim().isNotEmpty
                                ? _introController.text.trim()
                                : null,
                          );
                        } finally {
                          if (mounted) setState(() => _submitting = false);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: (widget.isSubmitting || _submitting)
                    ? null
                    : () => Navigator.pop(context),
                child: const Text(
                  'Hủy',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
