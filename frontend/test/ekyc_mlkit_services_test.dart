import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/features/profile/models/cccd_qr_model.dart';
import 'package:feeling_trip/features/profile/models/ekyc_check_status.dart';
import 'package:feeling_trip/features/profile/services/cccd_ocr_service.dart';
import 'package:feeling_trip/features/profile/services/face_liveness_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CccdOcrResult & FaceLivenessResult Models Test', () {
    test(
      'CccdOcrResult creates failure and unsupported web fallbacks correctly',
      () {
        final fail = CccdOcrResult.failure('Ảnh bị mờ');
        expect(fail.isSuccess, isFalse);
        expect(fail.isMatchedWithQr, isFalse);
        expect(fail.status, EkycCheckStatus.inconclusive);
        expect(fail.feedbackMessage, 'Ảnh bị mờ');

        final web = CccdOcrResult.unsupportedWeb();
        expect(web.isSuccess, isFalse);
        expect(web.isMatchedWithQr, isFalse);
        expect(web.status, EkycCheckStatus.unsupported);
      },
    );

    test(
      'FaceLivenessResult creates failure and unsupported web fallbacks correctly',
      () {
        final fail = FaceLivenessResult.failure(
          'Không tìm thấy mặt',
          faceCount: 0,
        );
        expect(fail.isValid, isFalse);
        expect(fail.faceCount, 0);
        expect(fail.message, 'Không tìm thấy mặt');

        final web = FaceLivenessResult.unsupportedWeb();
        expect(web.isValid, isFalse);
        expect(web.faceCount, isNull);
        expect(web.status, EkycCheckStatus.unsupported);
      },
    );

    test(
      'CccdOcrService handles null QR data or web fallback without crashing',
      () async {
        final result = await CccdOcrService.processFrontCard(
          imagePath: 'dummy/path.jpg',
          qrData: CccdQrModel.parse(
            '001201012345||TRẦN LONG NHẬT|15082001|Nam|Hà Nội|10112021',
          ),
        );
        expect(result.isMatchedWithQr, isFalse);
      },
    );

    test('FaceLivenessService handles dummy image without crashing', () async {
      final result = await FaceLivenessService.verifySelfie(
        imagePath: 'dummy/selfie.jpg',
      );
      expect(result.isValid, isFalse);
    });

    test('CccdOcrService.compareText correctly extracts name and DOB from complex multi-line OCR', () {
      final qrData = CccdQrModel.parse(
        '001201012345||TRẦN LONG NHẬT|15082001|Nam|Hà Nội|10112021',
      )!;

      // Real-world scenario: Labels split across lines, noise colons, O substituted for 0
      final rawLines = [
        'CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM',
        'Độc lập - Tự do - Hạnh phúc',
        'CĂN CƯỚC CÔNG DÂN',
        'Số / No.: 001201012345',
        'Họ, chữ đệm và tên khai sinh /',
        'Full name',
        ': TRẦN LONG NHẬT .',
        'Ngày, tháng, năm sinh /',
        'Date of birth',
        '15/O8/2OO1',
        'Giới tính / Sex: Nam',
      ];

      final result = CccdOcrService.compareText(rawLines, qrData: qrData);

      expect(result.isSuccess, isTrue);
      expect(result.detectedCccdNumber, '001201012345');
      expect(result.detectedFullName, contains('TRẦN LONG NHẬT'));
      expect(result.detectedDob, '15/08/2001');
    });

    test('CccdOcrService.compareText correctly rejects mismatched name or DOB', () {
      final qrData = CccdQrModel.parse(
        '001201012345||TRẦN LONG NHẬT|15082001|Nam|Hà Nội|10112021',
      )!;

      final mismatchedLines = [
        'CĂN CƯỚC CÔNG DÂN',
        'Số: 001201012345',
        'Họ và tên: NGUYỄN VĂN AN',
        'Ngày sinh: 15/08/2001',
      ];

      final result = CccdOcrService.compareText(mismatchedLines, qrData: qrData);
      expect(result.isSuccess, isFalse);
      expect(result.status, EkycCheckStatus.failed);
    });

    test('FaceBiometricFeatures correctly calculates similarity between matching and distinct faces', () {
      const faceA = FaceBiometricFeatures(
        eyeDistanceRatio: 0.42,
        eyeToNoseRatio: 0.45,
        noseToMouthRatio: 0.55,
        faceAspectRatio: 0.85,
        eyeMouthSpanRatio: 0.60,
      );

      // Slightly rotated or scaled version of same person
      const faceASlightVar = FaceBiometricFeatures(
        eyeDistanceRatio: 0.41,
        eyeToNoseRatio: 0.44,
        noseToMouthRatio: 0.56,
        faceAspectRatio: 0.84,
        eyeMouthSpanRatio: 0.59,
      );

      // Very different person with different facial proportions
      const faceB = FaceBiometricFeatures(
        eyeDistanceRatio: 0.60,
        eyeToNoseRatio: 0.25,
        noseToMouthRatio: 0.75,
        faceAspectRatio: 0.55,
        eyeMouthSpanRatio: 0.40,
      );

      final samePersonSimilarity = faceA.similarityWith(faceASlightVar);
      final diffPersonSimilarity = faceA.similarityWith(faceB);

      expect(samePersonSimilarity, greaterThanOrEqualTo(0.85));
      expect(diffPersonSimilarity, lessThan(0.60));

      final matchResult = FaceLivenessResult(
        status: EkycCheckStatus.passed,
        faceMatchScore: samePersonSimilarity,
        message: 'Khớp',
      );
      expect(matchResult.isMatchPassed, isTrue);

      final failResult = FaceLivenessResult(
        status: EkycCheckStatus.failed,
        faceMatchScore: diffPersonSimilarity,
        message: 'Không khớp',
      );
      expect(failResult.isMatchPassed, isFalse);
    });
  });
}
