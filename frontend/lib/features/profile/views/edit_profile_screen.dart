import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/ui_kit.dart';
import '../models/profile_form_data.dart';
import '../models/profile_model.dart';
import '../viewmodels/profile_viewmodel.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.viewModel,
    required this.initialProfile,
  });

  final ProfileViewModel viewModel;
  final ProfileModel initialProfile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _fullNameController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;
  late final TextEditingController _dobController;

  DateTime? _dob;
  String? _gender;

  Uint8List? _avatarBytes;
  String? _avatarFileName;

  @override
  void initState() {
    super.initState();

    final profile = widget.initialProfile;

    _fullNameController = TextEditingController(text: profile.fullName ?? '');
    _nicknameController = TextEditingController(text: profile.nickname ?? '');
    _phoneController = TextEditingController(text: profile.phone ?? '');
    _bioController = TextEditingController(text: profile.bio ?? '');

    _dob = profile.dob;
    _gender = _normalizeGender(profile.gender);

    _dobController = TextEditingController(
      text: _dob == null ? '' : _formatDate(_dob!),
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (file == null) return;

      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';

      if (!_allowedImageExtensions.contains(extension)) {
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
          'Dung lượng ảnh không được vượt quá 5 MB.',
          tone: AppStatusTone.error,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _avatarBytes = bytes;
        _avatarFileName = file.name;
      });
    } catch (_) {
      if (!mounted) return;

      AppFeedback.show(
        context,
        'Không thể chọn ảnh. Vui lòng thử lại.',
        tone: AppStatusTone.error,
      );
    }
  }

  Future<void> _pickDob() async {
    final selected = await AppPickers.date(
      context,
      initial: _dob ?? DateTime(2000),
      first: DateTime(1900),
      last: DateTime.now(),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _dob = selected;
      _dobController.text = _formatDate(selected);
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final succeeded = await widget.viewModel.updateProfile(
      data: ProfileFormData(
        fullName: _fullNameController.text.trim(),
        nickname: _nullableText(_nicknameController.text),
        phone: _nullableText(_phoneController.text),
        bio: _nullableText(_bioController.text),
        gender: _gender,
        dob: _dob,
        bankBin: widget.initialProfile.bankBin,
        bankName: widget.initialProfile.bankName,
        bankAccountNumber: widget.initialProfile.bankAccountNumber,
        bankAccountName: widget.initialProfile.bankAccountName,
      ),
      avatarBytes: _avatarBytes,
      avatarFileName: _avatarFileName,
    );

    if (!mounted) return;

    if (!succeeded) {
      AppFeedback.show(
        context,
        widget.viewModel.errorMessage ?? 'Không thể cập nhật hồ sơ.',
        tone: AppStatusTone.error,
      );
      return;
    }

    AppFeedback.show(
      context,
      'Cập nhật hồ sơ thành công.',
      tone: AppStatusTone.success,
    );

    Navigator.pop(context, true);
  }

  String? _validateFullName(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Vui lòng nhập họ và tên';
    }

    if (text.length < 2) {
      return 'Họ và tên phải có ít nhất 2 ký tự';
    }

    if (text.length > 100) {
      return 'Họ và tên không được vượt quá 100 ký tự';
    }

    return null;
  }

  String? _validateNickname(String? value) {
    final text = value?.trim() ?? '';

    if (text.length > 50) {
      return 'Biệt danh không được vượt quá 50 ký tự';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return null;

    final phonePattern = RegExp(r'^(?:0|\+84)[35789][0-9]{8}$');

    if (!phonePattern.hasMatch(text)) {
      return 'Số điện thoại Việt Nam không hợp lệ';
    }

    return null;
  }

  String? _validateBio(String? value) {
    final text = value?.trim() ?? '';

    if (text.length > 500) {
      return 'Giới thiệu không được vượt quá 500 ký tự';
    }

    return null;
  }

  Widget _buildAvatarPreview() {
    if (_avatarBytes != null) {
      return Semantics(
        image: true,
        label: 'Ảnh đại diện mới',
        child: ClipOval(
          child: Image.memory(
            _avatarBytes!,
            width: 112,
            height: 112,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return AvatarPlaceholder(
      name: widget.initialProfile.displayName,
      imageUrl: widget.initialProfile.avatarUrl,
      radius: 56,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        final isSaving = widget.viewModel.isSavingProfile;

        return AppScaffold(
          title: 'Chỉnh sửa hồ sơ',
          scrollable: true,
          bottomAction: CustomButton(
            text: 'Lưu thay đổi',
            icon: Icons.save_outlined,
            isLoading: isSaving,
            onPressed: isSaving ? null : _submit,
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ImagePickerField(
                      label: _avatarBytes == null
                          ? 'Chọn ảnh đại diện'
                          : 'Chọn ảnh khác',
                      enabled: !isSaving,
                      onPick: _pickAvatar,
                      preview: Center(child: _buildAvatarPreview()),
                    ),
                    const SizedBox(height: 24),

                    CustomTextField(
                      label: 'Họ và tên',
                      hint: 'Nhập họ và tên',
                      controller: _fullNameController,
                      prefixIcon: Icons.person_outline_rounded,
                      enabled: !isSaving,
                      validator: _validateFullName,
                      inputFormatters: [LengthLimitingTextInputFormatter(100)],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      label: 'Biệt danh',
                      hint: 'Tên hiển thị với mọi người',
                      controller: _nicknameController,
                      prefixIcon: Icons.badge_outlined,
                      enabled: !isSaving,
                      validator: _validateNickname,
                      inputFormatters: [LengthLimitingTextInputFormatter(50)],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      label: 'Số điện thoại',
                      hint: 'Ví dụ: 0912345678',
                      controller: _phoneController,
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      enabled: !isSaving,
                      validator: _validatePhone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                        LengthLimitingTextInputFormatter(12),
                      ],
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    CustomTextField(
                      label: 'Ngày sinh',
                      hint: 'Chọn ngày sinh',
                      controller: _dobController,
                      prefixIcon: Icons.cake_outlined,
                      readOnly: true,
                      enabled: !isSaving,
                      onTap: _pickDob,
                      suffixIcon: IconButton(
                        tooltip: _dob == null
                            ? 'Chọn ngày sinh'
                            : 'Xóa ngày sinh',
                        onPressed: isSaving
                            ? null
                            : () {
                                if (_dob == null) {
                                  _pickDob();
                                  return;
                                }

                                setState(() {
                                  _dob = null;
                                  _dobController.clear();
                                });
                              },
                        icon: Icon(
                          _dob == null
                              ? Icons.calendar_month_outlined
                              : Icons.close_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      'Giới tính',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),

                    AppChoiceChips<String>(
                      options: const {
                        'MALE': 'Nam',
                        'FEMALE': 'Nữ',
                        'OTHER': 'Khác',
                      },
                      selected: _gender == null
                          ? const <String>{}
                          : <String>{_gender!},
                      enabled: !isSaving,
                      onChanged: (value) {
                        setState(() {
                          _gender = _gender == value ? null : value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    CustomTextField(
                      label: 'Giới thiệu',
                      hint: 'Chia sẻ đôi chút về bản thân',
                      controller: _bioController,
                      prefixIcon: Icons.notes_rounded,
                      enabled: !isSaving,
                      validator: _validateBio,
                      maxLines: 5,
                      inputFormatters: [LengthLimitingTextInputFormatter(500)],
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Email được quản lý bởi hệ thống và không thể sửa tại đây.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String? _normalizeGender(String? value) {
    final normalized = value?.trim().toUpperCase();

    if (normalized == 'MALE' ||
        normalized == 'FEMALE' ||
        normalized == 'OTHER') {
      return normalized;
    }

    return null;
  }

  static String? _nullableText(String value) {
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static String _formatDate(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }
}
