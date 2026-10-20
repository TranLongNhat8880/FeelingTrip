import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/cccd_qr_model.dart';
import '../models/ekyc_check_status.dart';
import '../services/cccd_ocr_service.dart';
import '../services/face_liveness_service.dart';
import '../services/active_liveness_session.dart';

/// Serializes native ML calls and ties every result to the current input.
class EkycVerificationViewModel extends ChangeNotifier {
  EkycVerificationViewModel({
    CccdOcrService? ocr,
    FaceLivenessService? portrait,
  }) : _ocr = ocr ?? CccdOcrService(),
       _portrait = portrait ?? FaceLivenessService();

  final CccdOcrService _ocr;
  final FaceLivenessService _portrait;
  Future<void> _pending = Future.value();
  int _frontVersion = 0;
  int _portraitVersion = 0;
  bool _disposed = false;
  bool _frontBusy = false;
  bool _portraitBusy = false;
  CccdOcrResult? _frontResult;
  FaceLivenessResult? _portraitResult;
  LivenessEvidence? _livenessEvidence;
  LivenessEvidence? get livenessEvidence => _livenessEvidence;

  CccdOcrResult? get frontResult => _frontResult;
  FaceLivenessResult? get portraitResult => _portraitResult;
  bool get isAnalyzing => _frontBusy || _portraitBusy;
  String? get progress => _frontBusy
      ? 'Đang đọc OCR và đối chiếu thông tin...'
      : _portraitBusy
      ? 'Đang kiểm tra chất lượng ảnh chân dung...'
      : null;
  bool get hasUnsupportedCheck =>
      _frontResult?.status == EkycCheckStatus.unsupported ||
      _portraitResult?.status == EkycCheckStatus.unsupported;
  bool get checksAllowReview =>
      !_disposed &&
      !isAnalyzing &&
      _allowsReview(_frontResult?.status) &&
      _allowsReview(_portraitResult?.status) &&
      (_portraitResult?.status == EkycCheckStatus.unsupported ||
          _livenessEvidence != null);

  // Unsupported devices can only submit for manual review, never claim a pass.
  static bool _allowsReview(EkycCheckStatus? status) =>
      status == EkycCheckStatus.passed || status == EkycCheckStatus.unsupported;

  void invalidateFront() {
    if (_disposed) return;
    _frontVersion++;
    _frontResult = null;
    _frontBusy = false;
    _portraitVersion++;
    _portraitResult = null;
    _livenessEvidence = null;
    _portraitBusy = false;
    notifyListeners();
  }

  void invalidatePortrait() {
    if (_disposed) return;
    _portraitVersion++;
    _portraitResult = null;
    _livenessEvidence = null;
    _portraitBusy = false;
    notifyListeners();
  }

  void reset() {
    if (_disposed) return;
    _frontVersion++;
    _portraitVersion++;
    _frontResult = null;
    _portraitResult = null;
    _livenessEvidence = null;
    _frontBusy = false;
    _portraitBusy = false;
    notifyListeners();
  }

  Future<CccdOcrResult?> analyzeFront(String path, CccdQrModel? qr) {
    if (_disposed) return Future.value();
    final version = ++_frontVersion;
    _frontResult = null;
    _frontBusy = true;
    notifyListeners();
    final operation = _pending.then((_) async {
      if (_disposed || version != _frontVersion) return null;
      CccdOcrResult result;
      try {
        result = await _ocr.recognizeFrontCard(imagePath: path, qrData: qr);
      } catch (_) {
        result = CccdOcrResult.failure(
          'Chưa đọc được ảnh thẻ. Vui lòng thử lại.',
        );
      }
      if (_disposed || version != _frontVersion) return null;
      _frontResult = result;
      _frontBusy = false;
      notifyListeners();
      return result;
    });
    _pending = operation.then<void>((_) {});
    return operation;
  }

  Future<FaceLivenessResult?> analyzePortrait(
    String path,
    Uint8List bytes, {
    String? cccdFrontPath,
    Uint8List? cccdFrontBytes,
    LivenessEvidence? liveness,
  }) {
    if (_disposed) return Future.value();
    final version = ++_portraitVersion;
    _portraitResult = null;
    _livenessEvidence = null;
    _portraitBusy = true;
    notifyListeners();
    final operation = _pending.then((_) async {
      if (_disposed || version != _portraitVersion) return null;
      FaceLivenessResult result;
      try {
        result = await _portrait.analyzeSelfie(
          imagePath: path,
          imageBytes: bytes,
          cccdFrontPath: cccdFrontPath,
          cccdFrontBytes: cccdFrontBytes,
        );
      } catch (_) {
        result = FaceLivenessResult.failure(
          'Chưa kiểm tra được ảnh chân dung. Vui lòng thử lại.',
        );
      }
      if (_disposed || version != _portraitVersion) return null;
      _portraitResult = result;
      if (result.isValid) _livenessEvidence = liveness;
      _portraitBusy = false;
      notifyListeners();
      return result;
    });
    _pending = operation.then<void>((_) {});
    return operation;
  }

  @override
  void dispose() {
    _disposed = true;
    _frontVersion++;
    _portraitVersion++;
    unawaited(
      _pending.then((_) async {
        await _ocr.close();
        await _portrait.close();
      }),
    );
    super.dispose();
  }
}
