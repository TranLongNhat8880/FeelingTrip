import 'package:flutter/material.dart';
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
    final busy = widget.isSubmitting || _submitting;
    return AppBottomSheet(
      title: 'Gửi yêu cầu tham gia',
      bottomAction: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomButton(
            text: 'Gửi yêu cầu',
            isLoading: busy,
            onPressed: busy
                ? null
                : () async {
                    final intro = _introController.text.trim();
                    if (intro.isEmpty || intro.length > 1000) {
                      AppFeedback.show(
                        context,
                        'Nhập lời giới thiệu từ 1 đến 1000 ký tự.',
                        tone: AppStatusTone.warning,
                      );
                      return;
                    }
                    setState(() => _submitting = true);
                    try {
                      await widget.onSubmit(intro);
                    } finally {
                      if (mounted) setState(() => _submitting = false);
                    }
                  },
          ),
          const SizedBox(height: 8),
          CustomButton(
            text: 'Hủy',
            variant: AppButtonVariant.text,
            onPressed: busy ? null : () => Navigator.pop(context),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.postTitle, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _introController,
            label: 'Lời giới thiệu bản thân *',
            hint: 'Kể ngắn gọn về bạn và lý do muốn tham gia...',
            helperText: 'Giới thiệu ngắn gọn, tối đa 1000 ký tự.',
            maxLines: 4,
            enabled: !busy,
          ),
        ],
      ),
    );
  }
}
