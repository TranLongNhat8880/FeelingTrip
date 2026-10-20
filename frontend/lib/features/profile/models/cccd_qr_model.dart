// ============================================================================
// MODEL: Dữ liệu trích xuất từ mã QR trên thẻ CCCD gắn chip (Việt Nam)
// Định dạng chuẩn: Số_CCCD|Số_CMND_cũ|Họ_tên|Ngày_sinh|Giới_tính|Địa_chỉ|Ngày_cấp
// ============================================================================

class CccdQrModel {
  const CccdQrModel({
    required this.cccdNumber,
    this.oldIdNumber,
    required this.fullName,
    this.dob,
    this.gender,
    this.address,
    this.issueDate,
    required this.raw,
  });

  /// Số Căn cước công dân (12 chữ số).
  final String cccdNumber;

  /// Số CMND 9 số cũ (nếu có).
  final String? oldIdNumber;

  /// Họ và tên đầy đủ.
  final String fullName;

  /// Ngày tháng năm sinh.
  final DateTime? dob;

  /// Giới tính (Nam / Nữ).
  final String? gender;

  /// Nơi thường trú / Địa chỉ.
  final String? address;

  /// Ngày cấp thẻ CCCD.
  final DateTime? issueDate;

  /// Toàn bộ chuỗi thô giải mã từ mã QR.
  final String raw;

  /// Ngày sinh định dạng dd/MM/yyyy để hiển thị.
  String get formattedDob {
    if (dob == null) return '';
    final day = dob!.day.toString().padLeft(2, '0');
    final month = dob!.month.toString().padLeft(2, '0');
    return '$day/$month/${dob!.year}';
  }

  /// Ngày cấp định dạng dd/MM/yyyy để hiển thị.
  String get formattedIssueDate {
    if (issueDate == null) return '';
    final day = issueDate!.day.toString().padLeft(2, '0');
    final month = issueDate!.month.toString().padLeft(2, '0');
    return '$day/$month/${issueDate!.year}';
  }

  /// Trích xuất ngày tháng năm từ chuỗi định dạng ddmmyyyy.
  static DateTime? _parseDate(String rawDate) {
    final text = rawDate.trim();
    if (text.length != 8) return null;
    try {
      final day = int.parse(text.substring(0, 2));
      final month = int.parse(text.substring(2, 4));
      final year = int.parse(text.substring(4, 8));
      if (year < 1900 ||
          year > 2100 ||
          month < 1 ||
          month > 12 ||
          day < 1 ||
          day > 31) {
        return null;
      }
      final date = DateTime(year, month, day);
      return date.year == year && date.month == month && date.day == day
          ? date
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Phân tích cú pháp chuỗi QR trên thẻ CCCD Việt Nam.
  /// Trả về [CccdQrModel] nếu đúng định dạng hoặc `null` nếu không hợp lệ.
  static CccdQrModel? parse(String raw) {
    final trimmed = raw.trim();
    final parts = trimmed.split('|');
    if (parts.length < 6) return null;

    final cccdNumber = parts[0].trim();
    // The legacy ID, if any, belongs in oldIdNumber, not the CCCD field.
    if (!RegExp(r'^[0-9]{12}$').hasMatch(cccdNumber)) {
      return null;
    }

    final oldId = parts[1].trim().isEmpty ? null : parts[1].trim();
    final fullName = parts[2].trim();
    if (fullName.isEmpty) return null;

    final dob = _parseDate(parts[3].trim());
    if (parts[3].trim().isNotEmpty && dob == null) return null;
    final gender = parts[4].trim().isEmpty ? null : parts[4].trim();
    final address = parts[5].trim().isEmpty ? null : parts[5].trim();
    final issueDate = parts.length > 6 ? _parseDate(parts[6].trim()) : null;

    return CccdQrModel(
      cccdNumber: cccdNumber,
      oldIdNumber: oldId,
      fullName: fullName,
      dob: dob,
      gender: gender,
      address: address,
      issueDate: issueDate,
      raw: trimmed,
    );
  }

  /// Tạo bản sao với các trường được cập nhật.
  CccdQrModel copyWith({
    String? cccdNumber,
    String? oldIdNumber,
    String? fullName,
    DateTime? dob,
    String? gender,
    String? address,
    DateTime? issueDate,
    String? raw,
  }) {
    return CccdQrModel(
      cccdNumber: cccdNumber ?? this.cccdNumber,
      oldIdNumber: oldIdNumber ?? this.oldIdNumber,
      fullName: fullName ?? this.fullName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      issueDate: issueDate ?? this.issueDate,
      raw: raw ?? this.raw,
    );
  }
}
