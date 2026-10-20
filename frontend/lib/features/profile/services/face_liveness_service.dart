import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/ekyc_check_status.dart';
import 'cccd_ocr_service.dart';

/// Experimental geometry helper, not an identity matcher or authentication score.
class FaceBiometricFeatures {
  const FaceBiometricFeatures({
    required this.eyeDistanceRatio,
    required this.eyeToNoseRatio,
    required this.noseToMouthRatio,
    required this.faceAspectRatio,
    required this.eyeMouthSpanRatio,
  });

  final double eyeDistanceRatio;
  final double eyeToNoseRatio;
  final double noseToMouthRatio;
  final double faceAspectRatio;
  final double eyeMouthSpanRatio;

  static FaceBiometricFeatures? extract(Face face) {
    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    final nose = face.landmarks[FaceLandmarkType.noseBase]?.position;
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final box = face.boundingBox;

    if (box.width <= 0 || box.height <= 0) return null;

    final boxW = box.width;
    final boxH = box.height;
    final aspect = boxW / boxH;

    if (leftEye != null && rightEye != null && nose != null) {
      final eyeDist = _dist(leftEye, rightEye);
      final midEyeX = (leftEye.x + rightEye.x) / 2.0;
      final midEyeY = (leftEye.y + rightEye.y) / 2.0;

      final midMouthX = leftMouth != null && rightMouth != null
          ? (leftMouth.x + rightMouth.x) / 2.0
          : (box.left + box.right) / 2.0;
      final midMouthY = leftMouth != null && rightMouth != null
          ? (leftMouth.y + rightMouth.y) / 2.0
          : box.bottom - boxH * 0.15;

      final eyeToNose = _distPoints(
        midEyeX,
        midEyeY,
        nose.x.toDouble(),
        nose.y.toDouble(),
      );
      final noseToMouth = _distPoints(
        nose.x.toDouble(),
        nose.y.toDouble(),
        midMouthX,
        midMouthY,
      );
      final eyeToMouth = _distPoints(midEyeX, midEyeY, midMouthX, midMouthY);

      final span = eyeToMouth > 0 ? eyeToMouth : boxH * 0.6;

      return FaceBiometricFeatures(
        eyeDistanceRatio: eyeDist / boxW,
        eyeToNoseRatio: eyeToNose / span,
        noseToMouthRatio: noseToMouth / span,
        faceAspectRatio: aspect,
        eyeMouthSpanRatio: span / boxH,
      );
    } else {
      return FaceBiometricFeatures(
        eyeDistanceRatio: 0.42,
        eyeToNoseRatio: 0.45,
        noseToMouthRatio: 0.55,
        faceAspectRatio: aspect,
        eyeMouthSpanRatio: 0.6,
      );
    }
  }

  static double _dist(math.Point<int> p1, math.Point<int> p2) {
    final dx = (p1.x - p2.x).toDouble();
    final dy = (p1.y - p2.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  static double _distPoints(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }

  double similarityWith(FaceBiometricFeatures other) {
    final diffEyeDist = (eyeDistanceRatio - other.eyeDistanceRatio).abs();
    final diffEyeNose = (eyeToNoseRatio - other.eyeToNoseRatio).abs();
    final diffNoseMouth = (noseToMouthRatio - other.noseToMouthRatio).abs();
    final diffAspect = (faceAspectRatio - other.faceAspectRatio).abs();
    final diffSpan = (eyeMouthSpanRatio - other.eyeMouthSpanRatio).abs();

    final distance =
        (diffEyeDist * 2.5) +
        (diffEyeNose * 2.0) +
        (diffNoseMouth * 2.0) +
        (diffAspect * 1.5) +
        (diffSpan * 1.0);

    final score = 1.0 - (distance / 1.5);
    return score.clamp(0.0, 1.0);
  }
}

/// Portrait quality result. Active liveness evidence is stored separately.
class FaceLivenessResult {
  const FaceLivenessResult({
    required this.status,
    this.faceCount,
    this.headEulerAngleX,
    this.headEulerAngleY,
    this.headEulerAngleZ,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.cccdFaceFound = false,
    this.faceMatchScore,
    required this.message,
  });

  final EkycCheckStatus status;
  final int? faceCount;
  final double? headEulerAngleX;
  final double? headEulerAngleY;
  final double? headEulerAngleZ;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final bool cccdFaceFound;
  final double? faceMatchScore;
  final String message;

  bool get isValid => status == EkycCheckStatus.passed;
  bool get isMatchPassed => faceMatchScore != null && faceMatchScore! >= 0.60;

  factory FaceLivenessResult.unsupportedWeb() => const FaceLivenessResult(
    status: EkycCheckStatus.unsupported,
    message:
        'Thiết bị này chưa hỗ trợ kiểm tra ảnh chân dung. Hồ sơ cần admin kiểm tra.',
  );

  factory FaceLivenessResult.failure(String message, {int? faceCount}) =>
      FaceLivenessResult(
        status: EkycCheckStatus.inconclusive,
        faceCount: faceCount,
        message: message,
      );
}

/// Portrait quality only. Active challenge verification lives in ActiveLivenessSession.
class FaceLivenessService {
  FaceDetector? _detector;

  Future<FaceLivenessResult> analyzeSelfie({
    required String imagePath,
    required Uint8List imageBytes,
    String? cccdFrontPath,
    Uint8List? cccdFrontBytes,
  }) async {
    if (!CccdOcrService.isSupported) return FaceLivenessResult.unsupportedWeb();
    try {
      final detector = _detector ??= FaceDetector(
        options: FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableClassification: true,
          enableLandmarks: true,
          minFaceSize: 0.08,
        ),
      );
      final faces = await detector.processImage(
        InputImage.fromFilePath(imagePath),
      );
      if (faces.length != 1) {
        return evaluateFaces(faces, imageWidth: 0, imageHeight: 0);
      }
      final codec = await ui.instantiateImageCodec(imageBytes);
      FaceLivenessResult liveness;
      try {
        final frame = await codec.getNextFrame();
        try {
          liveness = evaluateFaces(
            faces,
            imageWidth: frame.image.width,
            imageHeight: frame.image.height,
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }

      if (!liveness.isValid) {
        return liveness;
      }

      // Landmark ratios are not identity recognition. Active liveness is checked
      // separately on live frames; neither check grants VERIFIED on the server.
      return liveness;
    } catch (_) {
      return FaceLivenessResult.failure(
        'Chưa phân tích được ảnh chân dung. Vui lòng chụp lại rõ nét.',
      );
    }
  }

  static Future<FaceLivenessResult> verifySelfie({
    required String imagePath,
    Uint8List? imageBytes,
    String? cccdFrontPath,
    Uint8List? cccdFrontBytes,
  }) async {
    final service = FaceLivenessService();
    try {
      return await service.analyzeSelfie(
        imagePath: imagePath,
        imageBytes: imageBytes ?? Uint8List(0),
        cccdFrontPath: cccdFrontPath,
        cccdFrontBytes: cccdFrontBytes,
      );
    } finally {
      await service.close();
    }
  }

  Future<void> close() async {
    final detector = _detector;
    _detector = null;
    if (detector != null) {
      try {
        await detector.close();
      } catch (_) {
        /* Already released. */
      }
    }
  }

  static FaceLivenessResult evaluateFaces(
    List<Face> faces, {
    required int imageWidth,
    required int imageHeight,
  }) {
    if (faces.length != 1) {
      return FaceLivenessResult(
        status: EkycCheckStatus.failed,
        faceCount: faces.length,
        message: faces.isEmpty
            ? 'Không tìm thấy khuôn mặt. Vui lòng chụp lại nơi đủ sáng.'
            : 'Có nhiều khuôn mặt. Chỉ để một người trong khung hình.',
      );
    }
    final face = faces.single;
    final x = face.headEulerAngleX;
    final y = face.headEulerAngleY;
    final z = face.headEulerAngleZ;
    final left = face.leftEyeOpenProbability;
    final right = face.rightEyeOpenProbability;
    FaceLivenessResult result(EkycCheckStatus status, String message) =>
        FaceLivenessResult(
          status: status,
          faceCount: 1,
          headEulerAngleX: x,
          headEulerAngleY: y,
          headEulerAngleZ: z,
          leftEyeOpenProbability: left,
          rightEyeOpenProbability: right,
          message: message,
        );
    if ([
          x,
          y,
          z,
          left,
          right,
        ].any((value) => value == null || !value.isFinite) ||
        imageWidth <= 0 ||
        imageHeight <= 0) {
      return result(
        EkycCheckStatus.inconclusive,
        'Chưa đo đủ góc mặt và trạng thái mắt. Vui lòng chụp lại rõ nét.',
      );
    }
    final box = face.boundingBox;
    if (![box.left, box.top, box.right, box.bottom].every((v) => v.isFinite) ||
        box.width <= 0 ||
        box.height <= 0 ||
        box.left < 0 ||
        box.top < 0 ||
        box.right > imageWidth ||
        box.bottom > imageHeight ||
        box.width / imageWidth < 0.15 ||
        box.height / imageHeight < 0.15) {
      return result(
        EkycCheckStatus.failed,
        'Đưa toàn bộ khuôn mặt vào khung hình và tiến lại gần camera.',
      );
    }
    if (x!.abs() > 20 || y!.abs() > 18 || z!.abs() > 18) {
      return result(
        EkycCheckStatus.failed,
        'Giữ đầu thẳng, không cúi/ngửa hoặc quay nghiêng.',
      );
    }
    if (left! < 0 || left > 1 || right! < 0 || right > 1) {
      return result(
        EkycCheckStatus.inconclusive,
        'Chưa đo được trạng thái mắt đáng tin cậy. Vui lòng thử lại.',
      );
    }
    if (left < 0.5 || right < 0.5) {
      return result(
        EkycCheckStatus.failed,
        'Vui lòng mở cả hai mắt và nhìn thẳng vào camera.',
      );
    }
    return result(
      EkycCheckStatus.passed,
      'Ảnh có một khuôn mặt rõ, nhìn thẳng và mở mắt. Chưa kiểm tra danh tính hoặc chống giả mạo.',
    );
  }
}
