/// Local image checks prepare a review; they do not verify identity.
enum EkycCheckStatus { passed, failed, inconclusive, unsupported }

extension EkycCheckStatusLabel on EkycCheckStatus {
  String get label => switch (this) {
    EkycCheckStatus.passed => 'Đã kiểm tra',
    EkycCheckStatus.failed => 'Không đạt',
    EkycCheckStatus.inconclusive => 'Chưa đủ dữ liệu',
    EkycCheckStatus.unsupported => 'Chưa hỗ trợ',
  };
}
