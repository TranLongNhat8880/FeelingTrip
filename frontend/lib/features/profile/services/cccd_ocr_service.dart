import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/cccd_qr_model.dart';
import '../models/ekyc_check_status.dart';

class CccdOcrResult {
  const CccdOcrResult({
    required this.status,
    this.detectedCccdNumber,
    this.detectedFullName,
    this.detectedDob,
    required this.feedbackMessage,
  });
  final EkycCheckStatus status;
  final String? detectedCccdNumber;
  final String? detectedFullName;
  final String? detectedDob;
  final String feedbackMessage;
  bool get isSuccess => status == EkycCheckStatus.passed;
  bool get isMatchedWithQr => isSuccess;

  factory CccdOcrResult.unsupportedWeb() => const CccdOcrResult(
    status: EkycCheckStatus.unsupported,
    feedbackMessage:
        'Thiết bị này chưa hỗ trợ đọc OCR. Ảnh chưa được đối chiếu; hồ sơ cần admin kiểm tra.',
  );
  factory CccdOcrResult.failure(String message) => CccdOcrResult(
    status: EkycCheckStatus.inconclusive,
    feedbackMessage: message,
  );
}

/// Checks consistency of supplied information, not authenticity of a card.
class CccdOcrService {
  TextRecognizer? _recognizer;
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Reuse a recognizer for a capture session; the owner must call close().
  Future<CccdOcrResult> recognizeFrontCard({
    required String imagePath,
    required CccdQrModel? qrData,
  }) async {
    if (!isSupported) return CccdOcrResult.unsupportedWeb();
    try {
      final recognizer = _recognizer ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final text = await recognizer.processImage(
        InputImage.fromFilePath(imagePath),
      );
      final rawLines = [
        for (final block in text.blocks)
          for (final line in block.lines) line.text,
      ];
      if (kDebugMode) {
        debugPrint('[CccdOcrService] OCR read ${rawLines.length} lines.');
      }
      return compareText(rawLines, qrData: qrData);
    } catch (_) {
      return CccdOcrResult.failure(
        'Chưa đọc được ảnh thẻ. Vui lòng chụp rõ nét, đủ sáng và thử lại.',
      );
    }
  }

  static Future<CccdOcrResult> processFrontCard({
    required String imagePath,
    required CccdQrModel? qrData,
  }) async {
    final service = CccdOcrService();
    try {
      return await service.recognizeFrontCard(
        imagePath: imagePath,
        qrData: qrData,
      );
    } finally {
      await service.close();
    }
  }

  Future<void> close() async {
    final recognizer = _recognizer;
    _recognizer = null;
    if (recognizer != null) {
      try {
        await recognizer.close();
      } catch (_) {
        /* Already released. */
      }
    }
  }

  static CccdOcrResult compareText(
    List<String> rawLines, {
    required CccdQrModel? qrData,
  }) {
    final lines = rawLines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final numbers = _extractCccdNumbers(lines, qrData: qrData);
    final number = numbers.length == 1 ? numbers.single : null;
    final name = _extractFullName(lines, qrData: qrData);
    final dob = _extractDob(lines, qrData: qrData);

    CccdOcrResult result(EkycCheckStatus status, String message) =>
        CccdOcrResult(
          status: status,
          detectedCccdNumber: number,
          detectedFullName: name,
          detectedDob: dob,
          feedbackMessage: message,
        );

    if (qrData == null) {
      return result(
        EkycCheckStatus.inconclusive,
        'Cần quét mã QR trước khi đối chiếu.',
      );
    }
    if (numbers.length > 1) {
      return result(
        EkycCheckStatus.inconclusive,
        'Đọc được nhiều số thẻ khác nhau. Vui lòng chụp riêng một thẻ CCCD.',
      );
    }
    if (number == null) {
      return result(
        EkycCheckStatus.inconclusive,
        'Chưa đọc rõ số CCCD 12 chữ số. Vui lòng chụp lại mặt trước.',
      );
    }
    if (number != qrData.cccdNumber.trim()) {
      return result(
        EkycCheckStatus.failed,
        'Số CCCD trên ảnh không khớp thông tin đã cung cấp. Vui lòng kiểm tra đúng thẻ.',
      );
    }
    if (name == null) {
      return result(
        EkycCheckStatus.inconclusive,
        'Đã đọc số thẻ nhưng chưa đọc rõ họ tên đầy đủ. Vui lòng chụp lại.',
      );
    }
    if (_normalize(name) != _normalize(qrData.fullName)) {
      return result(
        EkycCheckStatus.failed,
        'Họ tên trên ảnh không khớp thông tin đã cung cấp. Vui lòng kiểm tra lại.',
      );
    }
    if (qrData.dob != null) {
      if (dob == null) {
        return result(
          EkycCheckStatus.inconclusive,
          'Chưa đọc rõ ngày sinh trên thẻ. Vui lòng chụp lại để đối chiếu.',
        );
      }
      if (dob != qrData.formattedDob) {
        return result(
          EkycCheckStatus.failed,
          'Ngày sinh trên ảnh không khớp thông tin đã cung cấp.',
        );
      }
    }
    return result(
      EkycCheckStatus.passed,
      'Đã đối chiếu các thông tin đọc được trên ảnh. Kết quả này chưa xác minh tính thật của thẻ.',
    );
  }

  static Set<String> _extractCccdNumbers(
    List<String> lines, {
    CccdQrModel? qrData,
  }) {
    final candidates = <String>{};
    // Convert O/0 only inside a numeric token, never inside the No. label.
    final token = RegExp(
      r'(^|[^0-9A-Za-z])([0-9Oo](?:[ \t]*[0-9Oo]){11})(?=$|[^0-9A-Za-z])',
    );
    for (final line in lines) {
      for (final match in token.allMatches(line)) {
        final value = match.group(2)!.replaceAll(RegExp(r'\s'), '');
        if (RegExp(r'[0-9]').allMatches(value).length < 8) continue;
        candidates.add(value.replaceAll(RegExp('[Oo]'), '0'));
      }
    }

    if (qrData != null) {
      final target = qrData.cccdNumber.trim();
      if (candidates.contains(target)) {
        return {target};
      }
    }

    return candidates;
  }

  static final _nameLabel = RegExp(
    r'(họ(?:,\s*chữ\s*đệm)?\s*(?:và\s*)?tên(?:\s*khai\s*sinh)?|ho\s*(?:va\s*)?ten|full\s*name)\b',
    caseSensitive: false,
  );

  static const _systemLabels = {
    'CONG HOA',
    'DOC LAP',
    'VIET NAM',
    'CAN CUOC',
    'SOCIALIST',
    'INDEPENDENCE',
    'CITIZEN',
    'NATIONALITY',
    'GIOI TINH',
    'QUE QUAN',
    'NOI THUONG TRU',
    'DATE',
    'SEX',
    'QUOC TICH',
    'FULL NAME',
    'HO VA TEN',
    'HO TEN',
    'NOI DANG KY',
    'GIA TRI DEN',
  };

  static String? _extractFullName(List<String> lines, {CccdQrModel? qrData}) {
    // 1. Cross-matching with qrData if available
    if (qrData != null) {
      final expected = _normalize(qrData.fullName);
      final expectedTokens = expected
          .split(' ')
          .where((t) => t.isNotEmpty)
          .toList();

      for (final line in lines) {
        final clean = _cleanNoise(line);
        final norm = _normalize(clean);
        if (norm == expected || norm.contains(expected)) {
          return clean;
        }
      }

      if (expectedTokens.length >= 2) {
        for (final line in lines) {
          final clean = _cleanNoise(line);
          final norm = _normalize(clean);
          if (_isSystemLabel(norm)) continue;
          final words = norm.split(' ');
          final containsAll = expectedTokens.every(
            (token) => words.contains(token),
          );
          if (containsAll) {
            return clean;
          }
        }
      }
    }

    // 2. Search around name label
    for (var i = 0; i < lines.length; i++) {
      if (!_nameLabel.hasMatch(lines[i])) continue;

      final inline = _cleanNoise(
        lines[i]
            .replaceAll(_nameLabel, '')
            .replaceAll(RegExp(r'^[:/\s\-]+'), ''),
      );
      if (_isValidPersonName(inline)) return inline;

      for (var offset = 1; offset <= 3 && i + offset < lines.length; offset++) {
        final nextLine = _cleanNoise(lines[i + offset]);
        if (_isSystemLabel(nextLine)) continue;
        if (_isValidPersonName(nextLine)) return nextLine;
      }
    }

    // 3. Fallback: all-caps line candidate matching name format
    final candidates = lines.map(_cleanNoise).where((line) {
      return _isValidPersonName(line) &&
          line == line.toUpperCase() &&
          !_isSystemLabel(line);
    }).toList();

    return candidates.length == 1 ? candidates.single : null;
  }

  static String _cleanNoise(String value) {
    return value
        .replaceAll(RegExp(r'^[:/.\s\-"]+|[:/.\s\-"]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isSystemLabel(String value) {
    final norm = _normalize(value);
    for (final label in _systemLabels) {
      if (norm.contains(label)) return true;
    }
    return false;
  }

  static bool _isValidPersonName(String value) {
    final clean = _cleanNoise(value);
    final tokens = clean.split(RegExp(r'\s+'));
    if (tokens.length < 2 || tokens.length > 7) return false;
    if (_isSystemLabel(clean)) return false;
    return RegExp(r"^[A-Za-zÀ-ỹĐđ\u0300-\u036f '’\-]+$").hasMatch(clean);
  }

  static final _dobLabel = RegExp(
    r'(ng[aà]y(?:\s*,\s*th[aá]ng(?:\s*,\s*n[aă]m)?)?\s*sinh|date\s*of\s*birth|dob)\b',
    caseSensitive: false,
  );

  static String? _extractDob(List<String> lines, {CccdQrModel? qrData}) {
    // 1. Cross-matching with qrData if available
    if (qrData?.formattedDob != null) {
      final target = qrData!.formattedDob; // "DD/MM/YYYY"
      final parts = target.split('/');
      if (parts.length == 3) {
        final d = parts[0].replaceAll('0', '[0Oo]');
        final m = parts[1].replaceAll('0', '[0Oo]');
        final y = parts[2].replaceAll('0', '[0Oo]');
        final targetRegex = RegExp(
          '\\b$d[/.-]\\s*$m[/.-]\\s*$y\\b',
          caseSensitive: false,
        );
        final targetSpaceRegex = RegExp(
          '\\b$d\\s+$m\\s+$y\\b',
          caseSensitive: false,
        );

        for (final line in lines) {
          if (targetRegex.hasMatch(line) || targetSpaceRegex.hasMatch(line)) {
            return target;
          }
        }
      }
    }

    // 2. Search near DOB labels (checking current line and up to 3 subsequent lines)
    for (var i = 0; i < lines.length; i++) {
      if (!_dobLabel.hasMatch(_normalize(lines[i]))) continue;

      for (var offset = 0; offset <= 3 && i + offset < lines.length; offset++) {
        final parsed = _findDateInString(lines[i + offset]);
        if (parsed != null) return parsed;
      }
    }

    // 3. Fallback: inspect any line in document for a valid date
    for (final line in lines) {
      final parsed = _findDateInString(line);
      if (parsed != null) return parsed;
    }

    return null;
  }

  static String? _findDateInString(String text) {
    // Replace O/o with 0 when adjacent to digits or date separators
    final sanitized = text
        .replaceAllMapped(
          RegExp(r'([0-9/.-])[Oo]([0-9/.-])'),
          (m) => '${m[1]}0${m[2]}',
        )
        .replaceAllMapped(RegExp(r'\b[Oo]([0-9/.-])'), (m) => '0${m[1]}');

    final match = RegExp(
      r'\b(\d{2})[/.-](\d{2})[/.-](\d{4})\b',
    ).firstMatch(sanitized);

    if (match != null) {
      final day = int.tryParse(match[1]!) ?? 0;
      final month = int.tryParse(match[2]!) ?? 0;
      final year = int.tryParse(match[3]!) ?? 0;
      if (day >= 1 &&
          day <= 31 &&
          month >= 1 &&
          month <= 12 &&
          year >= 1900 &&
          year <= DateTime.now().year) {
        final dd = day.toString().padLeft(2, '0');
        final mm = month.toString().padLeft(2, '0');
        return '$dd/$mm/$year';
      }
    }

    final spaceMatch = RegExp(
      r'\b(\d{2})\s+(\d{2})\s+(\d{4})\b',
    ).firstMatch(sanitized);

    if (spaceMatch != null) {
      final day = int.tryParse(spaceMatch[1]!) ?? 0;
      final month = int.tryParse(spaceMatch[2]!) ?? 0;
      final year = int.tryParse(spaceMatch[3]!) ?? 0;
      if (day >= 1 &&
          day <= 31 &&
          month >= 1 &&
          month <= 12 &&
          year >= 1900 &&
          year <= DateTime.now().year) {
        final dd = day.toString().padLeft(2, '0');
        final mm = month.toString().padLeft(2, '0');
        return '$dd/$mm/$year';
      }
    }

    return null;
  }

  static String _normalize(String value) {
    const accented =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const plain =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var result = value.toLowerCase();
    for (var i = 0; i < accented.length; i++) {
      result = result.replaceAll(accented[i], plain[i]);
    }
    return result
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
