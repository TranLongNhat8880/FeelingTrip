// ============================================================================
// MODEL: Tài khoản ngân hàng đã liên kết qua SePay Bank Hub
// ============================================================================

class BankAccountModel {
  const BankAccountModel({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolderName,
    required this.isLinked,
    required this.isDefault,
  });

  final String id;
  final String bankName;
  final String accountNumber;
  final String accountHolderName;
  final bool isLinked;
  final bool isDefault;

  String get maskedAccountNumber {
    if (accountNumber.length <= 4) {
      return accountNumber;
    }

    return '•••• ${accountNumber.substring(accountNumber.length - 4)}';
  }

  factory BankAccountModel.fromJson(Map<String, dynamic> json) {
    return BankAccountModel(
      id: json['id']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountHolderName: json['accountHolderName']?.toString() ?? '',
      isLinked: _toBool(json['isLinked']) ?? false,
      isDefault: _toBool(json['isDefault']) ?? false,
    );
  }

  static bool? _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    switch (value?.toString().toLowerCase()) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
      default:
        return null;
    }
  }
}

// ============================================================================
// MODEL: Hosted Link do Bank Hub cấp
// ============================================================================

class BankHostedLink {
  const BankHostedLink({required this.url, this.expiresAt});

  final Uri url;
  final DateTime? expiresAt;

  factory BankHostedLink.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['hostedLinkUrl']?.toString() ?? '';
    final uri = Uri.tryParse(rawUrl);

    if (uri == null || !uri.hasScheme) {
      throw const FormatException('Bank Hub trả về liên kết không hợp lệ');
    }

    return BankHostedLink(
      url: uri,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.tryParse(json['expiresAt'].toString()),
    );
  }
}

// ============================================================================
// Loại thao tác yêu cầu Bank Hub thực hiện
// ============================================================================

enum BankLinkPurpose { link, unlink, reactivate }

extension BankLinkPurposeApiValue on BankLinkPurpose {
  String get apiValue {
    switch (this) {
      case BankLinkPurpose.link:
        return 'LINK_BANK_ACCOUNT';
      case BankLinkPurpose.unlink:
        return 'UNLINK_BANK_ACCOUNT';
      case BankLinkPurpose.reactivate:
        return 'REACTIVATE_BANK_ACCOUNT';
    }
  }
}
