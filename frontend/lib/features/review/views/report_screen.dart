import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../viewmodels/review_viewmodel.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    this.reportedUserId,
    this.reportedUserName,
    this.reportedTripId,
    this.reportedTripName,
  }) : assert(reportedUserId != null || reportedTripId != null);

  final String? reportedUserId;
  final String? reportedUserName;
  final String? reportedTripId;
  final String? reportedTripName;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const int _maxImageSize = 5 * 1024 * 1024;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  late final ReviewViewModel _viewModel;

  Uint8List? _evidenceBytes;
  String? _evidenceFileName;

  @override
  void initState() {
    super.initState();
    _viewModel = ReviewViewModel();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  String get _targetLabel {
    if (widget.reportedUserId != null) {
      return widget.reportedUserName ?? 'Người dùng';
    }
    return widget.reportedTripName ?? 'Chuyến đi';
  }

  Future<void> _pickEvidence() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );

    if (picked == null) return;

    final extension = picked.name.split('.').last.toLowerCase();
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        'Ảnh phải có định dạng JPG, JPEG, PNG hoặc WEBP.',
        tone: AppStatusTone.error,
      );
      return;
    }

    final bytes = await picked.readAsBytes();
    if (bytes.length > _maxImageSize) {
      if (!mounted) return;
      AppFeedback.show(
        context,
        'Ảnh bằng chứng không được vượt quá 5 MB.',
        tone: AppStatusTone.error,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _evidenceBytes = bytes;
      _evidenceFileName = picked.name;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final report = await _viewModel.submitReport(
      reportedUserId: widget.reportedUserId,
      reportedTripId: widget.reportedTripId,
      reason: _reasonController.text,
      evidenceBytes: _evidenceBytes,
      evidenceFileName: _evidenceFileName,
    );

    if (!mounted) return;
    if (report == null) {
      AppFeedback.show(
        context,
        _viewModel.errorMessage ?? 'Không thể gửi báo cáo.',
        tone: AppStatusTone.error,
      );
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => AppScaffold(
        title: 'Báo cáo vi phạm',
        scrollable: true,
        bottomAction: CustomButton(
          text: 'Gửi báo cáo',
          icon: Icons.report_outlined,
          width: double.infinity,
          variant: AppButtonVariant.destructive,
          isLoading: _viewModel.isSubmitting,
          onPressed: _viewModel.isSubmitting ? null : _submit,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: _targetLabel,
                    subtitle:
                        'Báo cáo sẽ được chuyển tới quản trị viên để xem xét.',
                  ),
                  const SizedBox(height: AppSizes.spaceL),
                  const AppInlineNotice(
                    message:
                        'Chỉ gửi thông tin đúng sự thật. Nội dung báo cáo phải có ít nhất 5 ký tự.',
                    tone: AppStatusTone.warning,
                  ),
                  const SizedBox(height: AppSizes.spaceL),
                  CustomTextField(
                    label: 'Lý do báo cáo',
                    hint: 'Mô tả hành vi vi phạm hoặc vấn đề đã xảy ra...',
                    controller: _reasonController,
                    prefixIcon: Icons.description_outlined,
                    enabled: !_viewModel.isSubmitting,
                    maxLines: 7,
                    inputFormatters: [LengthLimitingTextInputFormatter(2000)],
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.length < 5) {
                        return 'Lý do phải có ít nhất 5 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.spaceL),
                  ImagePickerField(
                    label: _evidenceBytes == null
                        ? 'Thêm ảnh bằng chứng (không bắt buộc)'
                        : 'Chọn ảnh khác',
                    enabled: !_viewModel.isSubmitting,
                    onPick: _pickEvidence,
                    preview: _evidenceBytes == null
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.cardRadius,
                                ),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.memory(
                                    _evidenceBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              AttachmentPreview(
                                name: _evidenceFileName ?? 'Ảnh bằng chứng',
                                onRemove: _viewModel.isSubmitting
                                    ? null
                                    : () => setState(() {
                                        _evidenceBytes = null;
                                        _evidenceFileName = null;
                                      }),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: AppSizes.spaceXL),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
