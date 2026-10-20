import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../models/cccd_qr_model.dart';
import '../models/profile_model.dart';
import '../models/ekyc_check_status.dart';
import '../services/cccd_ocr_service.dart';
import '../services/face_liveness_service.dart';
import '../services/active_liveness_session.dart';
import '../viewmodels/profile_viewmodel.dart';
import '../viewmodels/ekyc_verification_viewmodel.dart';
import 'cccd_qr_scanner_sheet.dart';
import 'face_liveness_screen.dart';

enum _EkycImageType { front, back, selfie }

class _SelectedImage {
  const _SelectedImage({required this.name, required this.bytes, this.path});

  final String name;
  final Uint8List bytes;
  final String? path;
}

class EkycScreen extends StatefulWidget {
  const EkycScreen({
    super.key,
    required this.viewModel,
    required this.initialProfile,
    this.verificationViewModel,
    this.imagePicker,
    this.scanQr,
    this.captureLiveness,
  });

  final ProfileViewModel viewModel;
  final ProfileModel initialProfile;
  final EkycVerificationViewModel? verificationViewModel;
  final ImagePicker? imagePicker;
  final Future<CccdQrModel?> Function(BuildContext context)? scanQr;
  final Future<LivenessCapture?> Function(BuildContext context)?
  captureLiveness;

  @override
  State<EkycScreen> createState() => _EkycScreenState();
}

class _EkycScreenState extends State<EkycScreen> {
  static const int _maxImageBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

  late final ImagePicker _imagePicker;

  CccdQrModel? _scannedQrData;
  _SelectedImage? _frontImage;
  _SelectedImage? _backImage;
  _SelectedImage? _selfieImage;
  LivenessCapture? _livenessCapture;

  late final EkycVerificationViewModel _verification;
  CccdOcrResult? get _ocrResult => _verification.frontResult;
  FaceLivenessResult? get _faceResult => _verification.portraitResult;
  bool get _isAnalyzingImage => _verification.isAnalyzing;
  String? get _analyzingStatus => _verification.progress;
  bool _captureInProgress = false;
  bool _flowInProgress = false;
  bool _submitPromptOpen = false;
  bool _qrEdited = false;
  bool get _isBusy =>
      _captureInProgress ||
      _flowInProgress ||
      _submitPromptOpen ||
      _isAnalyzingImage ||
      widget.viewModel.isSubmittingEkyc;
  bool get _canSendForReview =>
      _isAllStepsCompleted &&
      !_isBusy &&
      !_qrEdited &&
      _livenessCapture?.serverSessionId != null &&
      (_livenessCapture?.videoBytes?.isNotEmpty ?? false) &&
      _verification.checksAllowReview;

  @override
  void initState() {
    super.initState();
    _imagePicker = widget.imagePicker ?? ImagePicker();
    _verification = widget.verificationViewModel ?? EkycVerificationViewModel();
    _verification.addListener(_onVerificationChanged);
  }

  void _onVerificationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _verification.removeListener(_onVerificationChanged);
    if (widget.verificationViewModel == null) _verification.dispose();
    super.dispose();
  }

  bool get _hasAnyData =>
      _scannedQrData != null ||
      _frontImage != null ||
      _backImage != null ||
      _selfieImage != null;

  bool get _isAllStepsCompleted =>
      _scannedQrData != null &&
      _frontImage != null &&
      _backImage != null &&
      _selfieImage != null;

  void _setImage(_EkycImageType type, _SelectedImage? image) {
    setState(() {
      switch (type) {
        case _EkycImageType.front:
          _frontImage = image;
          _selfieImage = null;
          _livenessCapture = null;
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

  void _resetFlow() {
    if (_isBusy) return;
    _verification.reset();
    setState(() {
      _scannedQrData = null;
      _frontImage = null;
      _backImage = null;
      _selfieImage = null;
      _livenessCapture = null;
      _qrEdited = false;
    });
  }

  /// Only one picker/check/warning can be active. Retakes stay in this step.
  Future<_SelectedImage?> _captureStepImage({
    required String title,
    required String description,
    required _EkycImageType type,
    CameraDevice preferredCamera = CameraDevice.rear,
  }) async {
    if (!mounted || _captureInProgress || widget.viewModel.isSubmittingEkyc) {
      return null;
    }
    setState(() => _captureInProgress = true);
    try {
      while (mounted) {
        if (!mounted) return null;
        XFile? file;
        LivenessEvidence? evidence;
        if (type == _EkycImageType.selfie && !CccdOcrService.isSupported) {
          AppFeedback.show(
            context,
            'Hãy dùng ứng dụng Android/iOS để quay video xác minh trực tiếp.',
            tone: AppStatusTone.warning,
          );
          return null;
        }
        if (type == _EkycImageType.selfie && CccdOcrService.isSupported) {
          _verification.invalidatePortrait();
          setState(() {
            _livenessCapture = null;
            _selfieImage = null;
          });
          final capture =
              await (widget.captureLiveness ?? FaceLivenessScreen.show)(
                context,
              );
          if (capture == null || !mounted) return null;
          _livenessCapture = capture;
          evidence = capture.evidence;
          file = XFile.fromData(
            capture.bytes,
            path: capture.path,
            name: capture.name,
          );
        } else {
          final source = await showModalBottomSheet<ImageSource>(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            builder: (sheetContext) => type == _EkycImageType.selfie
                ? _buildSelfieCaptureSheet(sheetContext, title, description)
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(description),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Chụp ảnh ngay',
                            icon: Icons.camera_alt_outlined,
                            onPressed: () =>
                                Navigator.pop(sheetContext, ImageSource.camera),
                          ),
                          const SizedBox(height: 10),
                          CustomButton(
                            text: 'Chọn ảnh từ thư viện',
                            icon: Icons.photo_library_outlined,
                            variant: AppButtonVariant.secondary,
                            onPressed: () => Navigator.pop(
                              sheetContext,
                              ImageSource.gallery,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          );
          if (source == null || !mounted) return null;
          file = await _imagePicker.pickImage(
            source: source,
            preferredCameraDevice: preferredCamera,
            imageQuality: 90,
            maxWidth: 1600,
          );
        }
        if (file == null || !mounted) return null;
        final extension = file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : '';
        if (!_allowedExtensions.contains(extension)) {
          AppFeedback.show(
            context,
            'Ảnh phải có định dạng JPG, PNG hoặc WEBP.',
            tone: AppStatusTone.error,
          );
          continue;
        }
        final bytes = await file.readAsBytes();
        if (!mounted) return null;
        if (bytes.isEmpty || bytes.length > _maxImageBytes) {
          AppFeedback.show(
            context,
            'Ảnh phải có dữ liệu và không vượt quá 5 MB.',
            tone: AppStatusTone.error,
          );
          continue;
        }
        final selected = _SelectedImage(
          name: file.name,
          bytes: bytes,
          path: file.path,
        );
        _setImage(type, selected);
        EkycCheckStatus? status;
        String? message;
        if (type == _EkycImageType.front) {
          _verification.invalidatePortrait();
          final result = await _verification.analyzeFront(
            file.path,
            _scannedQrData,
          );
          status = result?.status;
          message = result?.feedbackMessage;
        } else if (type == _EkycImageType.selfie) {
          final result = await _verification.analyzePortrait(
            file.path,
            bytes,
            cccdFrontPath: _frontImage?.path,
            cccdFrontBytes: _frontImage?.bytes,
            liveness: evidence,
          );
          status = result?.status;
          message = result?.message;
        } else {
          return selected;
        }
        if (!mounted || status == null) return null;
        if (status == EkycCheckStatus.passed ||
            status == EkycCheckStatus.unsupported) {
          AppFeedback.show(
            context,
            message!,
            tone: status == EkycCheckStatus.passed
                ? AppStatusTone.success
                : AppStatusTone.warning,
          );
          return selected;
        }
        final retake = await _showImageWarning(
          title: type == _EkycImageType.front
              ? 'Cần kiểm tra lại ảnh CCCD'
              : 'Xác thực khuôn mặt chưa đạt',
          message: message!,
          retakeLabel: type == _EkycImageType.front
              ? 'Chụp lại mặt trước'
              : 'Quét lại khuôn mặt',
        );
        if (!retake) return null;
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.show(
          context,
          'Không thể xử lý ảnh. Vui lòng thử lại.',
          tone: AppStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _captureInProgress = false);
    }
    return null;
  }

  Widget _buildSelfieCaptureSheet(
    BuildContext sheetContext,
    String title,
    String description,
  ) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Xác minh trên điện thoại',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const AppInlineNotice(
              message:
                  'Xác minh tự động cần video liveness. Vui lòng dùng ứng dụng Android/iOS.',
              tone: AppStatusTone.warning,
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Đóng hướng dẫn',
              icon: Icons.camera_front_rounded,
              onPressed: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startGuidedFlow() async {
    if (!CccdOcrService.isSupported) {
      AppFeedback.show(
        context,
        'Xác minh tự động cần camera liveness trên ứng dụng Android/iOS. Vui lòng dùng điện thoại.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    if (_isBusy) return;
    setState(() => _flowInProgress = true);
    try {
      final qr = await (widget.scanQr ?? CccdQrScannerSheet.show)(context);
      if (qr == null || !mounted) return;
      _verification.reset();
      setState(() {
        _scannedQrData = qr;
        _qrEdited = false;
        _frontImage = null;
        _backImage = null;
        _selfieImage = null;
      });
      for (final step in [
        (
          type: _EkycImageType.front,
          title: 'Bước 2/4: Chụp mặt trước CCCD',
          description: 'Chụp rõ số CCCD, họ tên và ngày sinh, không lóa sáng.',
        ),
        (
          type: _EkycImageType.back,
          title: 'Bước 3/4: Chụp mặt sau CCCD',
          description: 'Chụp đầy đủ mặt sau thẻ CCCD.',
        ),
        (
          type: _EkycImageType.selfie,
          title: 'Bước 4/4: Chụp ảnh chân dung',
          description: 'Nhìn thẳng, mở cả hai mắt và chụp tại nơi đủ sáng.',
        ),
      ]) {
        if (!mounted) return;
        final image = await _captureStepImage(
          title: step.title,
          description: step.description,
          type: step.type,
          preferredCamera: step.type == _EkycImageType.selfie
              ? CameraDevice.front
              : CameraDevice.rear,
        );
        if (image == null || !mounted) return;
      }
      AppFeedback.show(
        context,
        'Đã thu thập ảnh và video. Kiểm tra hồ sơ rồi gửi xác minh tự động.',
        tone: AppStatusTone.success,
      );
    } finally {
      if (mounted) setState(() => _flowInProgress = false);
    }
  }

  /// Gửi hồ sơ xác minh hoàn chỉnh lên Backend
  Future<void> _rescanQr() async {
    if (_isBusy) return;
    setState(() => _flowInProgress = true);
    try {
      final qr = await (widget.scanQr ?? CccdQrScannerSheet.show)(context);
      if (!mounted || qr == null) return;
      _verification.invalidateFront();
      _livenessCapture = null;
      setState(() {
        _scannedQrData = qr;
        _qrEdited = false;
      });
      AppFeedback.show(
        context,
        'Đã quét QR mới. Chụp lại mặt trước để đối chiếu.',
        tone: AppStatusTone.warning,
      );
    } finally {
      if (mounted) setState(() => _flowInProgress = false);
    }
  }

  Future<void> _submit() async {
    if (!_canSendForReview) return;
    setState(() => _submitPromptOpen = true);
    try {
      if (!_verification.checksAllowReview ||
          !_isAllStepsCompleted ||
          !mounted) {
        return;
      }
      await _sendEkyc();
    } finally {
      if (mounted) setState(() => _submitPromptOpen = false);
    }
  }

  Future<void> _sendEkyc() async {
    FocusScope.of(context).unfocus();
    final auth = context.getInheritedWidgetOfExactType<AuthScope>()?.notifier;

    if (_scannedQrData == null) {
      AppFeedback.show(
        context,
        'Vui lòng quét mã QR trên thẻ CCCD trước khi gửi.',
        tone: AppStatusTone.error,
      );
      return;
    }

    if (_frontImage == null ||
        _backImage == null ||
        _selfieImage == null ||
        _livenessCapture?.serverSessionId == null ||
        _livenessCapture?.videoBytes == null) {
      AppFeedback.show(
        context,
        'Vui lòng chụp đầy đủ ảnh mặt trước, mặt sau CCCD và ảnh chân dung.',
        tone: AppStatusTone.error,
      );
      return;
    }

    final succeeded = await widget.viewModel.submitEkyc(
      cccdNumber: _scannedQrData!.cccdNumber,
      frontImageBytes: _frontImage!.bytes,
      frontImageFileName: _frontImage!.name,
      backImageBytes: _backImage!.bytes,
      backImageFileName: _backImage!.name,
      selfieImageBytes: _selfieImage!.bytes,
      selfieImageFileName: _selfieImage!.name,
      sessionId: _livenessCapture!.serverSessionId,
      qrData: _scannedQrData!.raw,
      livenessVideoBytes: _livenessCapture!.videoBytes,
    );

    if (!mounted) return;

    if (!succeeded) {
      _verification.invalidatePortrait();
      setState(() {
        _livenessCapture = null;
        _selfieImage = null;
      });
      AppFeedback.show(
        context,
        widget.viewModel.errorMessage ?? 'Không thể gửi hồ sơ xác minh.',
        tone: AppStatusTone.error,
      );
      return;
    }

    final sessionRefreshed = auth == null || await auth.refreshUser();
    if (!mounted) return;

    AppFeedback.show(
      context,
      sessionRefreshed
          ? 'Đối chiếu CCCD và khuôn mặt thành công. Tài khoản đã được xác minh!'
          : 'Tài khoản đã được xác minh. Chưa cập nhật được phiên đăng nhập; vui lòng đăng nhập lại để dùng các chức năng đã mở khóa.',
      tone: sessionRefreshed ? AppStatusTone.success : AppStatusTone.warning,
    );
    setState(() => _livenessCapture = null);
  }

  /// Cho phép người dùng chỉnh sửa thông tin CCCD nếu mã QR bị lỗi hoặc sai sót
  Future<void> _showEditQrDataSheet() async {
    if (_scannedQrData == null || _isBusy) return;

    final nameController = TextEditingController(
      text: _scannedQrData!.fullName,
    );
    final cccdController = TextEditingController(
      text: _scannedQrData!.cccdNumber,
    );
    final dobController = TextEditingController(
      text: _scannedQrData!.formattedDob,
    );
    final addressController = TextEditingController(
      text: _scannedQrData!.address ?? '',
    );
    String selectedGender = _scannedQrData!.gender ?? 'Nam';
    final editFormKey = GlobalKey<FormState>();
    ModalRoute<dynamic>? editRoute;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        editRoute = ModalRoute.of(sheetContext);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Form(
                key: editFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Chỉnh sửa thông tin CCCD',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Vui lòng điều chỉnh chính xác theo thông tin in trên thẻ CCCD của bạn.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Họ và tên *',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập họ và tên';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: cccdController,
                        decoration: const InputDecoration(
                          labelText: 'Số Căn cước công dân (12 số) *',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(12),
                        ],
                        validator: (val) {
                          final text = val?.trim() ?? '';
                          if (!RegExp(r'^[0-9]{12}$').hasMatch(text)) {
                            return 'Số CCCD phải gồm đúng 12 chữ số';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: dobController,
                        decoration: const InputDecoration(
                          labelText: 'Ngày sinh (dd/MM/yyyy)',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          hintText: 'Ví dụ: 15/08/2001',
                        ),
                        keyboardType: TextInputType.datetime,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedGender,
                        decoration: const InputDecoration(
                          labelText: 'Giới tính',
                          prefixIcon: Icon(Icons.wc_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                          DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                          DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedGender = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Nơi thường trú',
                          prefixIcon: Icon(Icons.home_outlined),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          if (!(editFormKey.currentState?.validate() ??
                              false)) {
                            return;
                          }

                          DateTime? parsedDob;
                          final dobText = dobController.text.trim();
                          if (dobText.isNotEmpty) {
                            final parts = dobText.split('/');
                            if (parts.length == 3) {
                              try {
                                parsedDob = DateTime(
                                  int.parse(parts[2]),
                                  int.parse(parts[1]),
                                  int.parse(parts[0]),
                                );
                                if (parsedDob.day != int.parse(parts[0]) ||
                                    parsedDob.month != int.parse(parts[1]) ||
                                    parsedDob.year != int.parse(parts[2]) ||
                                    parsedDob.year < 1900 ||
                                    parsedDob.isAfter(DateTime.now())) {
                                  parsedDob = null;
                                }
                              } catch (_) {}
                            }
                          }

                          if (dobText.isNotEmpty && parsedDob == null) {
                            AppFeedback.show(
                              context,
                              'Ngày sinh không hợp lệ. Dùng định dạng dd/MM/yyyy.',
                              tone: AppStatusTone.error,
                            );
                            return;
                          }

                          _verification.invalidateFront();
                          setState(() {
                            _qrEdited = true;
                            _scannedQrData = _scannedQrData!.copyWith(
                              fullName: nameController.text
                                  .trim()
                                  .toUpperCase(),
                              cccdNumber: cccdController.text.trim(),
                              dob: parsedDob ?? _scannedQrData!.dob,
                              gender: selectedGender,
                              address: addressController.text.trim().isEmpty
                                  ? null
                                  : addressController.text.trim(),
                            );
                          });

                          Navigator.pop(sheetContext);
                          AppFeedback.show(
                            context,
                            'Đã cập nhật thông tin. Chụp lại mặt trước để đối chiếu lại.',
                            tone: AppStatusTone.warning,
                          );
                        },
                        child: const Text(
                          'Lưu thay đổi',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    // The pop future completes before the closing animation removes the fields.
    await editRoute?.completed;
    nameController.dispose();
    cccdController.dispose();
    dobController.dispose();
    addressController.dispose();
  }

  Future<bool> _showImageWarning({
    required String title,
    required String message,
    required String retakeLabel,
  }) async {
    return await AppBottomSheet.show<bool>(
          context,
          title: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInlineNotice(message: message, tone: AppStatusTone.warning),
              const SizedBox(height: 12),
              CustomButton(
                text: retakeLabel,
                icon: Icons.refresh_rounded,
                onPressed: () => Navigator.pop(context, true),
              ),
              const SizedBox(height: 8),
              CustomButton(
                text: 'Tạm dừng',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.pop(context, false),
              ),
            ],
          ),
        ) ??
        false;
  }

  AppStatusTone _statusTone(ProfileModel profile) {
    if (profile.isEkycVerified) return AppStatusTone.success;
    if (profile.isEkycPending) return AppStatusTone.warning;
    if (profile.isEkycRejected) return AppStatusTone.error;
    return AppStatusTone.neutral;
  }

  Widget _buildStatusContent(ProfileModel profile) {
    if (profile.isEkycVerified) {
      return const AppInlineNotice(
        message:
            'Danh tính của bạn đã được xác minh thành công. '
            'Bạn đã nhận huy hiệu Tích xanh uy tín trên FeelingTrip.',
        tone: AppStatusTone.success,
      );
    }

    if (profile.isEkycPending) {
      return const AppInlineNotice(
        message:
            'Hồ sơ trước đang chờ xét duyệt. Bạn có thể thực hiện lại quy trình bên dưới để xác minh tự động.',
        tone: AppStatusTone.warning,
      );
    }

    if (profile.isEkycRejected) {
      final reason = profile.verificationRejectionReason?.trim();
      return AppInlineNotice(
        message: reason == null || reason.isEmpty
            ? 'Hồ sơ xác minh trước đã bị từ chối. Vui lòng thực hiện lại các bước bên dưới.'
            : 'Hồ sơ bị từ chối: $reason.\nVui lòng thực hiện lại các bước bên dưới.',
        tone: AppStatusTone.error,
      );
    }

    return const SizedBox.shrink();
  }

  /// Thanh chỉ báo tiến trình 4 bước (Step Indicator)
  Widget _buildStepIndicator() {
    final steps = [
      {'title': 'Quét QR', 'done': _scannedQrData != null},
      {'title': 'Mặt trước', 'done': _frontImage != null},
      {'title': 'Mặt sau', 'done': _backImage != null},
      {'title': 'Chân dung', 'done': _selfieImage != null},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (steps[i]['done'] as bool)
                            ? AppColors.success
                            : AppColors.inputSurface,
                        border: Border.all(
                          color: (steps[i]['done'] as bool)
                              ? AppColors.success
                              : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: (steps[i]['done'] as bool)
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              )
                            : Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                if (i < steps.length - 1)
                  Container(
                    width: 10,
                    height: 2,
                    color:
                        (steps[i]['done'] as bool) &&
                            (steps[i + 1]['done'] as bool)
                        ? AppColors.success
                        : AppColors.border,
                  ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Expanded(
                  child: Text(
                    steps[i]['title'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: (steps[i]['done'] as bool)
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: (steps[i]['done'] as bool)
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (i < steps.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Màn hình giới thiệu quy trình 4 bước khi người dùng chưa bắt đầu
  Widget _buildIntroCard({required bool isSubmitting}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xác minh danh tính tự động',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đọc CCCD, quay video liveness và đối chiếu khuôn mặt trên server',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),

          _buildIntroStepItem(
            stepNumber: '1',
            icon: Icons.qr_code_scanner_rounded,
            title: 'Quét mã QR thẻ CCCD',
            description: 'Đọc số CCCD, họ tên và ngày sinh từ mã QR trên thẻ.',
          ),
          const SizedBox(height: 14),
          _buildIntroStepItem(
            stepNumber: '2',
            icon: Icons.credit_card_rounded,
            title: 'Chụp mặt trước thẻ CCCD',
            description: 'Hệ thống tự mở camera để chụp rõ nét mặt trước thẻ.',
          ),
          const SizedBox(height: 14),
          _buildIntroStepItem(
            stepNumber: '3',
            icon: Icons.flip_to_back_rounded,
            title: 'Chụp mặt sau thẻ CCCD',
            description: 'Lật mặt sau (chứa vân tay & chip) để ghi nhận hồ sơ.',
          ),
          const SizedBox(height: 14),
          _buildIntroStepItem(
            stepNumber: '4',
            icon: Icons.face_rounded,
            title: 'Chụp ảnh chân dung chính chủ',
            description:
                'Thực hiện chớp mắt và quay đầu trực tiếp theo hướng dẫn của camera.',
          ),
          const SizedBox(height: 24),

          // Nút bấm lớn bắt đầu luồng tự động
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isBusy ? null : _startGuidedFlow,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill_rounded, size: 22),
                SizedBox(width: 10),
                Text(
                  'Bắt đầu xác minh eKYC',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroStepItem({
    required String stepNumber,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Icon(icon, color: AppColors.primary, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bước $stepNumber: $title',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Card tóm tắt thông tin đã trích xuất từ QR
  Widget _buildQrInfoCard() {
    if (_scannedQrData == null) {
      return InkWell(
        onTap: _rescanQr,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.qr_code_scanner_rounded,
                color: AppColors.error,
                size: 28,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Chưa quét mã QR CCCD. Bấm vào đây để quét mã.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.error,
              ),
            ],
          ),
        ),
      );
    }

    final qr = _scannedQrData!;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.successSurface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _qrEdited
                      ? 'Thông tin CCCD đã chỉnh sửa'
                      : 'Thông tin từ QR CCCD',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _showEditQrDataSheet,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Sửa',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _rescanQr,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Quét lại',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildInfoRow('Họ và tên:', qr.fullName),
          const SizedBox(height: 8),
          _buildInfoRow('Số CCCD:', qr.cccdNumber),
          if (qr.formattedDob.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Ngày sinh:', qr.formattedDob),
          ],
          if (qr.gender != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Giới tính:', qr.gender!),
          ],
          if (qr.address != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Nơi thường trú:', qr.address!),
          ],
          if (qr.formattedIssueDate.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Ngày cấp:', qr.formattedIssueDate),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// Lưới hiển thị 3 ảnh đã chụp (Mặt trước, Mặt sau, Chân dung)
  Widget _buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Hình ảnh xác thực',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildImageTile(
                title: 'Mặt trước',
                image: _frontImage,
                onTap: () => _captureStepImage(
                  title: 'Chụp mặt trước CCCD',
                  description: 'Căn chỉnh mặt trước rõ nét.',
                  type: _EkycImageType.front,
                  preferredCamera: CameraDevice.rear,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildImageTile(
                title: 'Mặt sau',
                image: _backImage,
                onTap: () => _captureStepImage(
                  title: 'Chụp mặt sau CCCD',
                  description: 'Lật mặt sau có vân tay & chip.',
                  type: _EkycImageType.back,
                  preferredCamera: CameraDevice.rear,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildImageTile(
                title: 'Chân dung',
                image: _selfieImage,
                isOval: true,
                onTap: () => _captureStepImage(
                  title: 'Chụp ảnh chân dung',
                  description: 'Nhìn thẳng vào camera.',
                  type: _EkycImageType.selfie,
                  preferredCamera: CameraDevice.front,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageTile({
    required String title,
    required _SelectedImage? image,
    required VoidCallback onTap,
    bool isOval = false,
  }) {
    final hasImage = image != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: hasImage ? Colors.black87 : AppColors.inputSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasImage ? AppColors.success : AppColors.border,
            width: hasImage ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.memory(image.bytes, fit: BoxFit.cover)
              else
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isOval
                              ? Icons.face_retouching_natural_rounded
                              : Icons.add_a_photo_outlined,
                          size: 26,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Chụp ngay',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Nhãn tiêu đề bên dưới
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasImage)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                          size: 12,
                        ),
                      if (hasImage) const SizedBox(width: 4),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Local preparation results; neither check verifies identity.
  Widget _buildAiVerificationCard() {
    final ocrDone = _ocrResult != null;
    final ocrMatched = _ocrResult?.isMatchedWithQr ?? false;

    final faceDone = _faceResult != null;
    final evidence = _verification.livenessEvidence;
    final faceValid = (_faceResult?.isValid ?? false) && evidence != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (ocrMatched && faceValid)
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.verified_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kiểm tra ảnh trước khi gửi',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Đối chiếu thông tin và chất lượng ảnh. Admin vẫn xét duyệt hồ sơ.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 22),

          // Mục 1: OCR Thẻ CCCD Mặt trước
          _buildVerificationItem(
            icon: Icons.document_scanner_rounded,
            title: 'OCR Thẻ CCCD Mặt trước',
            status: !ocrDone ? 'Chưa chụp ảnh' : _ocrResult!.status.label,
            isSuccess: ocrMatched,
            isWarning: ocrDone && !ocrMatched,
            description:
                _ocrResult?.feedbackMessage ??
                'Hệ thống sẽ đối chiếu số CCCD và Họ tên trên ảnh với mã QR.',
            details: ocrDone && _ocrResult!.detectedCccdNumber != null
                ? 'Số thẻ: ${_ocrResult!.detectedCccdNumber} • Tên: ${_ocrResult!.detectedFullName ?? "Chưa rõ"}'
                : null,
          ),

          const SizedBox(height: 14),

          // Active motion challenge; identity matching is a separate capability.
          _buildVerificationItem(
            icon: Icons.face_retouching_natural_rounded,
            title: 'Liveness theo thao tác',
            status: !faceDone
                ? 'Chưa quét chân dung'
                : faceValid
                ? 'Đã qua thao tác'
                : _faceResult!.isValid
                ? 'Chưa kiểm tra liveness'
                : _faceResult!.status.label,
            isSuccess: faceValid,
            isWarning: faceDone && !faceValid,
            description: faceValid
                ? 'Đã ghi lại thao tác trực tiếp. Server sẽ kiểm tra video, chống giả mạo và so khuôn mặt với ảnh CCCD khi gửi hồ sơ.'
                : _faceResult?.message ??
                      'Camera sẽ yêu cầu chớp mắt và quay đầu theo thứ tự ngẫu nhiên.',
            details: _faceResult?.faceCount != null
                ? 'Số mặt: ${_faceResult!.faceCount}${evidence != null ? " • Hoàn tất ${evidence.actions.length} thao tác" : ""}'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationItem({
    required IconData icon,
    required String title,
    required String status,
    required bool isSuccess,
    required bool isWarning,
    required String description,
    String? details,
  }) {
    Color badgeColor;
    Color badgeBg;
    IconData badgeIcon;

    if (isSuccess) {
      badgeColor = AppColors.success;
      badgeBg = AppColors.successSurface;
      badgeIcon = Icons.check_circle_rounded;
    } else if (isWarning) {
      badgeColor = AppColors.warning;
      badgeBg = AppColors.warningSurface;
      badgeIcon = Icons.error_outline_rounded;
    } else {
      badgeColor = AppColors.textSecondary;
      badgeBg = AppColors.inputSurface;
      badgeIcon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          if (details != null) ...[
            const SizedBox(height: 4),
            Text(
              details,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Khung xác nhận và gửi hồ sơ khi đã thu thập đủ dữ liệu
  Widget _buildReviewAndSubmitContent({required bool isSubmitting}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStepIndicator(),
        const SizedBox(height: 16),
        if (_isAnalyzingImage) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _analyzingStatus ?? 'Đang xử lý hình ảnh...',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_verification.hasUnsupportedCheck)
          const AppInlineNotice(
            message:
                'Thiết bị này chưa đủ điều kiện xác minh tự động. Vui lòng dùng ứng dụng Android/iOS.',
            tone: AppStatusTone.warning,
          ),
        if (_qrEdited)
          const AppInlineNotice(
            message:
                'Thông tin đã chỉnh sửa cần được quét lại từ mã QR gốc trước khi xác minh tự động.',
            tone: AppStatusTone.warning,
          ),
        AbsorbPointer(absorbing: _isBusy, child: _buildQrInfoCard()),
        const SizedBox(height: 16),
        AbsorbPointer(absorbing: _isBusy, child: _buildImageGallery()),
        const SizedBox(height: 16),
        _buildAiVerificationCard(),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _canSendForReview
                ? AppColors.primary
                : AppColors.border,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _canSendForReview ? _submit : null,
          icon: isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Icon(Icons.verified_user_rounded),
          label: Text(
            isSubmitting ? 'Đang đối chiếu và xác minh...' : 'Xác minh tự động',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 10),

        Center(
          child: TextButton.icon(
            onPressed: _isBusy ? null : _resetFlow,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Làm lại từ đầu'),
          ),
        ),
      ],
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
          showKoharu: false,
          title: 'Xác minh danh tính',
          scrollable: true,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Card trạng thái eKYC
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
                    const SizedBox(height: 16),
                    if (!_hasAnyData)
                      _buildIntroCard(isSubmitting: isSubmitting)
                    else
                      _buildReviewAndSubmitContent(isSubmitting: isSubmitting),
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
