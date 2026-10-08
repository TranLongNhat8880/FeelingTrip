import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/bank_account_model.dart';
import '../models/profile_form_data.dart';
import '../models/profile_model.dart';
import '../models/trust_score_model.dart';
import 'profile_repository.dart';

// ============================================================================
// API REPOSITORY: Profile
// Kết nối frontend với backend Users và Bank Hub.
// ============================================================================

class ApiProfileRepository implements ProfileRepository {
  @override
  Future<ProfileModel> getProfile() async {
    final response = await ApiClient.get(ApiEndpoints.profile);
    final data = _requireDataMap(response);

    return ProfileModel.fromJson(data);
  }

  @override
  Future<ProfileModel> updateProfile({
    required ProfileFormData data,
    List<int>? avatarBytes,
    String? avatarFileName,
  }) async {
    final hasAvatar =
        avatarBytes != null &&
        avatarBytes.isNotEmpty &&
        avatarFileName != null &&
        avatarFileName.trim().isNotEmpty;

    final response = await ApiClient.multipart(
      'PUT',
      ApiEndpoints.profile,
      fields: data.toMultipartFields(),
      files: hasAvatar
          ? [
              MultipartFileData(
                fieldName: 'avatar',
                fileName: avatarFileName,
                bytes: avatarBytes,
              ),
            ]
          : const [],
    );

    return ProfileModel.fromJson(_requireDataMap(response));
  }

  @override
  Future<void> submitEkyc({
    required String cccdNumber,
    required List<int> frontImageBytes,
    required String frontImageFileName,
    required List<int> backImageBytes,
    required String backImageFileName,
    required List<int> selfieImageBytes,
    required String selfieImageFileName,
  }) async {
    await ApiClient.multipart(
      'POST',
      '${ApiEndpoints.users}/ekyc-verify',
      fields: {'cccdNumber': cccdNumber.trim()},
      files: [
        MultipartFileData(
          fieldName: 'cccdFrontImage',
          fileName: frontImageFileName,
          bytes: frontImageBytes,
        ),
        MultipartFileData(
          fieldName: 'cccdBackImage',
          fileName: backImageFileName,
          bytes: backImageBytes,
        ),
        MultipartFileData(
          fieldName: 'selfieImage',
          fileName: selfieImageFileName,
          bytes: selfieImageBytes,
        ),
      ],
    );
  }

  @override
  Future<TrustScoreModel> getTrustScore(String userId) async {
    final normalizedId = userId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Mã người dùng bị trống');
    }

    final response = await ApiClient.get(
      '${ApiEndpoints.users}/trust-score/'
      '${Uri.encodeComponent(normalizedId)}',
    );

    return TrustScoreModel.fromJson(_requireDataMap(response));
  }

  @override
  Future<List<BankAccountModel>> getBankAccounts() async {
    final response = await ApiClient.get(
      '${ApiEndpoints.users}/me/bank/accounts',
    );

    final data = response['data'];

    if (data is! List) {
      throw const FormatException(
        'Backend trả danh sách tài khoản ngân hàng không hợp lệ',
      );
    }

    return data
        .whereType<Map>()
        .map(
          (item) => BankAccountModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  @override
  Future<BankHostedLink> createBankHostedLink({
    required BankLinkPurpose purpose,
    String? accountId,
  }) async {
    final normalizedAccountId = accountId?.trim();

    if (purpose != BankLinkPurpose.link &&
        (normalizedAccountId == null || normalizedAccountId.isEmpty)) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'Cần mã tài khoản ngân hàng cho thao tác này',
      );
    }

    final response = await ApiClient.post(
      '${ApiEndpoints.users}/me/bank/link',
      body: {
        'purpose': purpose.apiValue,
        if (purpose != BankLinkPurpose.link) 'accountId': normalizedAccountId,
      },
    );

    return BankHostedLink.fromJson(_requireDataMap(response));
  }

  Map<String, dynamic> _requireDataMap(Map<String, dynamic> response) {
    final data = response['data'];

    if (data is! Map) {
      throw const FormatException('Backend trả dữ liệu hồ sơ không hợp lệ');
    }

    return Map<String, dynamic>.from(data);
  }
}
