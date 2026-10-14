import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/ui_kit.dart';
import '../models/profile_model.dart';
import '../viewmodels/profile_viewmodel.dart';

enum _EkycImageType { front, back, selfie }

class _SelectedImage {
  const _SelectedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class EkycScreen extends StatefulWidget {
  const EkycScreen({
    super.key,
    required this.viewModel,
    required this.initialProfile,
  });

  final ProfileViewModel viewModel;
  final ProfileModel initialProfile;

  @override
  State<EkycScreen> createState() => _EkycScreenState();
}

class _EkycScreenState extends State<EkycScreen> {
  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  final _formKey = GlobalKey<FormState>();
  final _cccdController = TextEditingController();
  final _imagePicker = ImagePicker();

  _SelectedImage? _frontImage;
  _SelectedImage? _backImage;
  _SelectedImage? _selfieImage;

  @override
  void dispose() {
    _cccdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(_EkycImageType type) async {
    try {
      final source = await _selectImageSource(type);

      if (source == null) return;

      final file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
      );

      if (file == null) return;

      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';

      if (!_allowedExtensions.contains(extension)) {
        if (!mounted) return;

        AppFeedback.show(
          context,
          'Ảnh phải có định dạng JPG, PNG hoặc WEBP.',
          tone: AppStatusTone.error,
        );
        return;
      }

      final bytes = await file.readAsBytes();

      if (bytes.length > _maxImageBytes) {
        if (!mounted) return;

        AppFeedback.show(
          context,
          'Mỗi ảnh không được vượt quá 5 MB.',
          tone: AppStatusTone.error,
        );
        return;
      }

      if (!mounted) return;

      _setImage(type, _SelectedImage(name: file.name, bytes: bytes));
    } catch (_) {
      if (!mounted) return;

      AppFeedback.show(
        context,
        'Không thể chọn ảnh. Vui lòng thử lại.',
        tone: AppStatusTone.error,
      );
    }
  }

  Future<ImageSource?> _selectImageSource(_EkycImageType type) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  type == _EkycImageType.selfie
                      ? 'Chọn ảnh chân dung'
                      : 'Chọn ảnh CCCD',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Chọn từ thư viện'),
                  onTap: () {
                    Navigator.pop(context, ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Chụp ảnh mới'),
                  onTap: () {
                    Navigator.pop(context, ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _setImage(_EkycImageType type, _SelectedImage? image) {
    setState(() {
      switch (type) {
        case _EkycImageType.front:
          _frontImage = image;
          break;
        case _EkycImageType.back:
          _backImage = image;
          break;
        case _EkycImageType.selfie:
          _selfieImage = image;
          break;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_frontImage == null || _backImage == null || _selfieImage == null) {
      AppFeedback.show(
        context,
        'Vui lòng chọn đầy đủ ảnh mặt trước, mặt sau CCCD và ảnh chân dung.',
        tone: AppStatusTone.error,
      );
      return;
    }

    final succeeded = await widget.viewModel.submitEkyc(
      cccdNumber: _cccdController.text.trim(),
      frontImageBytes: _frontImage!.bytes,
      frontImageFileName: _frontImage!.name,
      backImageBytes: _backImage!.bytes,
      backImageFileName: _backImage!.name,
      selfieImageBytes: _selfieImage!.bytes,
      selfieImageFileName: _selfieImage!.name,
    );

    if (!mounted) return;

    if (!succeeded) {
      AppFeedback.show(
        context,
        widget.viewModel.errorMessage ?? 'Không thể gửi hồ sơ xác minh.',
        tone: AppStatusTone.error,
      );
      return;
    }

    AppFeedback.show(
      context,
      'Đã gửi hồ sơ eKYC. Vui lòng chờ Admin xét duyệt.',
      tone: AppStatusTone.success,
    );
  }

  String? _validateCccd(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Vui lòng nhập số CCCD';
    }

    if (!RegExp(r'^[0-9]{12}$').hasMatch(text)) {
      return 'Số CCCD phải gồm đúng 12 chữ số';
    }

    return null;
  }

  AppStatusTone _statusTone(ProfileModel profile) {
    if (profile.isEkycVerified) {
      return AppStatusTone.success;
    }

    if (profile.isEkycPending) {
      return AppStatusTone.warning;
    }

    if (profile.isEkycRejected) {
      return AppStatusTone.error;
    }

    return AppStatusTone.neutral;
  }

  Widget _buildSelectedImage(_SelectedImage image, VoidCallback onRemove) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.memory(image.bytes, fit: BoxFit.cover),
          ),
        ),
        AttachmentPreview(name: image.name, onRemove: onRemove),
      ],
    );
  }

  Widget _buildSubmissionForm({required bool isSubmitting}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppInlineNotice(
            message:
                'Ảnh phải rõ nét, không bị che góc, lóa sáng hoặc chỉnh sửa. '
                'Mỗi ảnh tối đa 5 MB.',
            tone: AppStatusTone.info,
          ),
          const SizedBox(height: 20),

          CustomTextField(
            label: 'Số Căn cước công dân',
            hint: 'Nhập đúng 12 chữ số',
            controller: _cccdController,
            prefixIcon: Icons.credit_card_outlined,
            keyboardType: TextInputType.number,
            enabled: !isSubmitting,
            validator: _validateCccd,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(12),
            ],
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),

          ImagePickerField(
            label: _frontImage == null
                ? 'Chọn ảnh mặt trước CCCD'
                : 'Chọn lại ảnh mặt trước',
            enabled: !isSubmitting,
            onPick: () => _pickImage(_EkycImageType.front),
            preview: _frontImage == null
                ? null
                : _buildSelectedImage(
                    _frontImage!,
                    () => _setImage(_EkycImageType.front, null),
                  ),
          ),
          const SizedBox(height: 20),

          ImagePickerField(
            label: _backImage == null
                ? 'Chọn ảnh mặt sau CCCD'
                : 'Chọn lại ảnh mặt sau',
            enabled: !isSubmitting,
            onPick: () => _pickImage(_EkycImageType.back),
            preview: _backImage == null
                ? null
                : _buildSelectedImage(
                    _backImage!,
                    () => _setImage(_EkycImageType.back, null),
                  ),
          ),
          const SizedBox(height: 20),

          ImagePickerField(
            label: _selfieImage == null
                ? 'Chọn ảnh chân dung'
                : 'Chọn lại ảnh chân dung',
            enabled: !isSubmitting,
            onPick: () => _pickImage(_EkycImageType.selfie),
            preview: _selfieImage == null
                ? null
                : _buildSelectedImage(
                    _selfieImage!,
                    () => _setImage(_EkycImageType.selfie, null),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusContent(ProfileModel profile) {
    if (profile.isEkycVerified) {
      return const AppInlineNotice(
        message:
            'Danh tính của bạn đã được xác minh. Bạn không cần nộp lại hồ sơ.',
        tone: AppStatusTone.success,
      );
    }

    if (profile.isEkycPending) {
      return const AppInlineNotice(
        message:
            'Hồ sơ đang được Admin xét duyệt. '
            'Bạn chưa thể gửi thêm hồ sơ trong thời gian này.',
        tone: AppStatusTone.warning,
      );
    }

    if (profile.isEkycRejected) {
      final reason = profile.verificationRejectionReason?.trim();

      return AppInlineNotice(
        message: reason == null || reason.isEmpty
            ? 'Hồ sơ trước đã bị từ chối. '
                  'Vui lòng kiểm tra lại thông tin và nộp lại.'
            : 'Hồ sơ trước đã bị từ chối.\nLý do: $reason',
        tone: AppStatusTone.error,
      );
    }

    return const AppInlineNotice(
      message:
          'Tài khoản của bạn chưa được xác minh danh tính. '
          'Hãy cung cấp đầy đủ thông tin bên dưới.',
      tone: AppStatusTone.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final profile = widget.viewModel.profile ?? widget.initialProfile;
        final isSubmitting = widget.viewModel.isSubmittingEkyc;
        final canSubmit = profile.canSubmitEkyc;

        return AppScaffold(
          title: 'Xác minh danh tính',
          scrollable: true,
          bottomAction: canSubmit
              ? CustomButton(
                  text: profile.isEkycRejected
                      ? 'Nộp lại hồ sơ'
                      : 'Gửi hồ sơ xác minh',
                  icon: Icons.verified_user_outlined,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting ? null : _submit,
                )
              : null,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 42,
                          color: _statusTone(profile).foreground,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trạng thái eKYC',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              AppStatusBadge(
                                label: profile.verificationLabel,
                                tone: _statusTone(profile),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildStatusContent(profile),

                  if (canSubmit) ...[
                    const SizedBox(height: 24),
                    Text(
                      profile.isEkycRejected
                          ? 'Nộp lại hồ sơ'
                          : 'Thông tin xác minh',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildSubmissionForm(isSubmitting: isSubmitting),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
