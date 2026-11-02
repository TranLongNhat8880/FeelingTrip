import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../models/cccd_qr_model.dart';
import '../models/profile_model.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'cccd_qr_scanner_sheet.dart';

class _DocumentImage {
  const _DocumentImage(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

/// Manual review uses photographs only. No AI session or liveness video is sent.
class EkycScreen extends StatefulWidget {
  const EkycScreen({
    super.key,
    required this.viewModel,
    required this.initialProfile,
    this.imagePicker,
    this.scanQr,
  });
  final ProfileViewModel viewModel;
  final ProfileModel initialProfile;
  final ImagePicker? imagePicker;
  final Future<CccdQrModel?> Function(BuildContext)? scanQr;

  @override
  State<EkycScreen> createState() => _EkycScreenState();
}

class _EkycScreenState extends State<EkycScreen> {
  final _number = TextEditingController();
  final _form = GlobalKey<FormState>();
  final List<_DocumentImage?> _images = List.filled(3, null);
  late final ImagePicker _picker;
  bool _picking = false;
  bool _sent = false;
  bool _consent = false;
  ProfileModel get _profile =>
      widget.viewModel.profile ?? widget.initialProfile;
  bool get _busy => _picking || widget.viewModel.isSubmittingEkyc;
  static const _labels = ['Mặt trước CCCD', 'Mặt sau CCCD', 'Ảnh chân dung'];
  static const _hints = [
    'Chụp rõ toàn bộ thẻ, không cắt góc và không che thông tin.',
    'Chụp rõ mặt sau, tránh ánh sáng phản chiếu lên thẻ.',
    'Ảnh rõ mặt, nhìn thẳng, không đeo khẩu trang hoặc kính râm.',
  ];

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    if (_busy) return;
    setState(() => _picking = true);
    try {
      final qr = await (widget.scanQr ?? CccdQrScannerSheet.show)(context);
      if (mounted && qr != null) {
        _number.text = qr.cccdNumber;
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.show(
          context,
          'Chưa quét được mã QR. Bạn có thể nhập số CCCD bên dưới.',
          tone: AppStatusTone.warning,
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pick(int index) async {
    if (_busy) return;
    setState(() => _picking = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Chụp ảnh'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (!mounted || source == null) return;
      final file = await _picker.pickImage(
        source: source,
        preferredCameraDevice: index == 2
            ? CameraDevice.front
            : CameraDevice.rear,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final extension = file.name.split('.').last.toLowerCase();
      if (bytes.isEmpty ||
          bytes.length > 5 * 1024 * 1024 ||
          !{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
        AppFeedback.show(
          context,
          'Chọn ảnh JPG, PNG hoặc WEBP, tối đa 5 MB.',
          tone: AppStatusTone.error,
        );
        return;
      }
      setState(() => _images[index] = _DocumentImage(file.name, bytes));
    } catch (_) {
      if (mounted) {
        AppFeedback.show(
          context,
          'Không mở được ảnh hoặc camera. Vui lòng thử lại.',
          tone: AppStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    await widget.viewModel.loadProfile();
    if (!mounted) return;
    final auth = context.getInheritedWidgetOfExactType<AuthScope>()?.notifier;
    await auth?.refreshUser();
    if (mounted && widget.viewModel.profileErrorMessage != null) {
      AppFeedback.show(
        context,
        widget.viewModel.profileErrorMessage!,
        tone: AppStatusTone.error,
      );
    }
  }

  Future<void> _submit() async {
    if (_busy || !_profile.canSubmitEkyc || !_form.currentState!.validate()) {
      return;
    }
    if (_images.any((image) => image == null) || !_consent) return;
    final success = await widget.viewModel.submitEkyc(
      cccdNumber: _number.text.trim(),
      frontImageBytes: _images[0]!.bytes,
      frontImageFileName: _images[0]!.name,
      backImageBytes: _images[1]!.bytes,
      backImageFileName: _images[1]!.name,
      selfieImageBytes: _images[2]!.bytes,
      selfieImageFileName: _images[2]!.name,
    );
    if (!mounted) return;
    if (success) {
      setState(() {
        _sent = true;
        _images.fillRange(0, 3, null);
        _number.clear();
        _consent = false;
      });
      final auth = context.getInheritedWidgetOfExactType<AuthScope>()?.notifier;
      await auth?.refreshUser();
    } else {
      AppFeedback.show(
        context,
        widget.viewModel.errorMessage ?? 'Chưa gửi được hồ sơ.',
        tone: AppStatusTone.error,
      );
    }
  }

  Widget _status(ProfileModel profile) {
    final verified = profile.isEkycVerified;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            verified
                ? Icons.verified_user_outlined
                : Icons.hourglass_top_rounded,
            size: 52,
            color: verified ? const Color(0xFF008A60) : const Color(0xFFB77900),
          ),
          const SizedBox(height: 16),
          Text(
            verified
                ? 'Danh tính đã được xác minh'
                : _sent
                ? 'Đã gửi hồ sơ thành công'
                : 'Hồ sơ đang chờ xét duyệt',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            verified
                ? 'Bạn có thể sử dụng các chức năng yêu cầu tài khoản đã xác minh.'
                : 'Quản trị viên sẽ kiểm tra ảnh CCCD và chân dung. Bạn sẽ nhận được thông báo sau khi có kết quả; hiện tài khoản chưa được xác minh.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          CustomButton(
            text: 'Cập nhật trạng thái',
            icon: Icons.refresh,
            variant: AppButtonVariant.secondary,
            isLoading: widget.viewModel.isLoadingProfile,
            onPressed: widget.viewModel.isLoadingProfile ? null : _refresh,
          ),
        ],
      ),
    );
  }

  Widget _imageCard(int index) {
    final image = _images[index];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                child: image == null
                    ? Text('${index + 1}')
                    : const Icon(Icons.check, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _labels[index],
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (image != null)
                IconButton(
                  tooltip: 'Xóa ${_labels[index].toLowerCase()}',
                  onPressed: _busy
                      ? null
                      : () => setState(() => _images[index] = null),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_hints[index]),
          const SizedBox(height: 12),
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                image.bytes,
                height: 170,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 100,
                  child: Center(
                    child: Text('Không đọc được ảnh. Vui lòng chọn lại.'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          CustomButton(
            text: image == null
                ? [
                    'Thêm mặt trước CCCD',
                    'Thêm mặt sau CCCD',
                    'Thêm ảnh chân dung',
                  ][index]
                : 'Chọn lại ảnh',
            icon: Icons.add_a_photo_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: _busy ? null : () => _pick(index),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (context, _) {
      final profile = _profile;
      final statusOnly = profile.isEkycVerified || profile.isEkycPending;
      final complete = _images.every((image) => image != null);
      return PopScope(
        canPop: !_busy,
        child: AppScaffold(
          title: 'Xác minh CCCD',
          showKoharu: false,
          scrollable: true,
          actions: [
            IconButton(
              tooltip: 'Cập nhật trạng thái',
              onPressed: _busy || widget.viewModel.isLoadingProfile
                  ? null
                  : _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: statusOnly
                  ? _status(profile)
                  : Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            profile.isEkycRejected
                                ? 'Bổ sung hồ sơ xác minh'
                                : 'Gửi hồ sơ xác minh',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Chuẩn bị ảnh hai mặt CCCD và ảnh chân dung. Quản trị viên sẽ kiểm tra hồ sơ trước khi cấp trạng thái đã xác minh.',
                          ),
                          if (profile.isEkycRejected) ...[
                            const SizedBox(height: 16),
                            AppInlineNotice(
                              message:
                                  'Lý do từ chối: ${profile.verificationRejectionReason ?? 'Vui lòng chụp rõ thông tin và gửi lại hồ sơ.'}',
                              tone: AppStatusTone.error,
                            ),
                          ],
                          const SizedBox(height: 20),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Thông tin CCCD',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                CustomTextField(
                                  label: 'Số CCCD',
                                  hint: 'Nhập 12 chữ số trên thẻ',
                                  controller: _number,
                                  keyboardType: TextInputType.number,
                                  enabled: !_busy,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(12),
                                  ],
                                  validator: (value) =>
                                      RegExp(
                                        r'^\d{12}$',
                                      ).hasMatch(value?.trim() ?? '')
                                      ? null
                                      : 'Số CCCD phải gồm đúng 12 chữ số.',
                                ),
                                const SizedBox(height: 10),
                                CustomButton(
                                  text: 'Quét QR để điền số CCCD',
                                  icon: Icons.qr_code_scanner,
                                  variant: AppButtonVariant.secondary,
                                  onPressed: _busy ? null : _scan,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          for (var index = 0; index < 3; index++) ...[
                            _imageCard(index),
                            const SizedBox(height: 12),
                          ],
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _consent,
                            onChanged: _busy
                                ? null
                                : (value) =>
                                      setState(() => _consent = value ?? false),
                            title: const Text(
                              'Tôi xác nhận đây là giấy tờ và ảnh của mình, đồng ý cung cấp để xét duyệt danh tính.',
                            ),
                            subtitle: const Text(
                              'Ảnh chỉ phục vụ xét duyệt, không hiển thị trên hồ sơ công khai.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          CustomButton(
                            text: 'Gửi hồ sơ xét duyệt',
                            icon: Icons.send_outlined,
                            isLoading: widget.viewModel.isSubmittingEkyc,
                            onPressed: !_busy && complete && _consent
                                ? _submit
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Đã thêm ${_images.where((image) => image != null).length}/3 ảnh · JPG, PNG, WEBP · tối đa 5 MB/ảnh',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      );
    },
  );
}
