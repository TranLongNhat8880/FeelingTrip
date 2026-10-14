import '../../core/constants/app_assets.dart';
import 'package:flutter/material.dart';
import '../buttons/custom_button.dart';
import '../widgets/app_status_badge.dart';
import '../inputs/custom_text_field.dart';
import '../../core/constants/app_sizes.dart';
import 'package:flutter/services.dart';

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Xác nhận',
    this.cancelLabel = 'Hủy',
    this.destructive = false,
  });
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Xác nhận',
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) => AppConfirmDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          destructive: destructive,
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Đóng',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
          ExcludeSemantics(
            child: Image.asset(AppAssets.groupLuggage, height: 100),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          CustomButton(
            text: confirmLabel,
            variant: destructive
                ? AppButtonVariant.destructive
                : AppButtonVariant.primary,
            onPressed: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 8),
          CustomButton(
            text: cancelLabel,
            variant: AppButtonVariant.text,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    ),
  );
}

class AppMessageDialog extends StatelessWidget {
  const AppMessageDialog({
    super.key,
    required this.title,
    required this.message,
    this.tone = AppStatusTone.success,
    this.actionLabel = 'Đã hiểu',
  });
  final String title;
  final String message;
  final AppStatusTone tone;
  final String actionLabel;
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    AppStatusTone tone = AppStatusTone.success,
    String actionLabel = 'Đã hiểu',
  }) => showDialog<void>(
    context: context,
    builder: (_) => AppMessageDialog(
      title: title,
      message: message,
      tone: tone,
      actionLabel: actionLabel,
    ),
  );
  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Đóng',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (tone == AppStatusTone.success)
            ExcludeSemantics(
              child: Image.asset(AppAssets.successCheck, height: 90),
            )
          else
            CircleAvatar(
              radius: 28,
              backgroundColor: tone.background,
              child: Icon(tone.icon, color: tone.foreground, size: 30),
            ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          CustomButton(
            text: actionLabel,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class AppInputDialog extends StatefulWidget {
  const AppInputDialog({
    super.key,
    required this.title,
    required this.label,
    this.hint,
    this.confirmLabel = 'Lưu',
    this.initialValue = '',
    this.maxLines = 3,
    this.maxLength = 500,
    this.validator,
    this.destructive = false,
  });
  final String title;
  final String label;
  final String? hint;
  final String confirmLabel;
  final String initialValue;
  final int maxLines;
  final int maxLength;
  final FormFieldValidator<String>? validator;
  final bool destructive;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String label,
    String? hint,
    String confirmLabel = 'Lưu',
    String initialValue = '',
    int maxLines = 3,
    int maxLength = 500,
    FormFieldValidator<String>? validator,
    bool destructive = false,
  }) => showDialog<String>(
    context: context,
    builder: (_) => AppInputDialog(
      title: title,
      label: label,
      hint: hint,
      confirmLabel: confirmLabel,
      initialValue: initialValue,
      maxLines: maxLines,
      maxLength: maxLength,
      validator: validator,
      destructive: destructive,
    ),
  );

  @override
  State<AppInputDialog> createState() => _AppInputDialogState();
}

class _AppInputDialogState extends State<AppInputDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _controller;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.screenPadding),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            CustomTextField(
              controller: _controller,
              label: widget.label,
              hint: widget.hint,
              maxLines: widget.maxLines,
              inputFormatters: [
                LengthLimitingTextInputFormatter(widget.maxLength),
              ],
              validator: (value) {
                if ((value?.trim().length ?? 0) > widget.maxLength) {
                  return 'Nhập tối đa ${widget.maxLength} ký tự';
                }
                return widget.validator?.call(value);
              },
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: widget.confirmLabel,
              variant: widget.destructive
                  ? AppButtonVariant.destructive
                  : AppButtonVariant.primary,
              onPressed: () {
                if (_form.currentState!.validate()) {
                  Navigator.pop(context, _controller.text.trim());
                }
              },
            ),
            const SizedBox(height: 8),
            CustomButton(
              text: 'Hủy',
              variant: AppButtonVariant.text,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}
