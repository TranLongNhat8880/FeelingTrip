import '../models/bank_account_model.dart';
import '../models/profile_form_data.dart';
import '../models/profile_model.dart';
import '../models/trust_score_model.dart';

// ============================================================================
// REPOSITORY CONTRACT: Profile
//
// ViewModel chỉ phụ thuộc interface này, không gọi ApiClient trực tiếp.
// ============================================================================

abstract class ProfileRepository {
  /// Lấy hồ sơ đầy đủ của người dùng đang đăng nhập.
  Future<ProfileModel> getProfile();

  /// Cập nhật thông tin hồ sơ và có thể kèm avatar mới.
  Future<ProfileModel> updateProfile({
    required ProfileFormData data,
    List<int>? avatarBytes,
    String? avatarFileName,
  });

  /// Nộp hoặc nộp lại hồ sơ eKYC.
  Future<void> submitEkyc({
    required String cccdNumber,
    required List<int> frontImageBytes,
    required String frontImageFileName,
    required List<int> backImageBytes,
    required String backImageFileName,
    required List<int> selfieImageBytes,
    required String selfieImageFileName,
  });

  /// Lấy điểm tín nhiệm công khai của một người dùng.
  Future<TrustScoreModel> getTrustScore(String userId);

  /// Lấy các tài khoản ngân hàng đã từng liên kết qua Bank Hub.
  Future<List<BankAccountModel>> getBankAccounts();

  /// Tạo Hosted Link để liên kết, hủy hoặc khôi phục tài khoản ngân hàng.
  Future<BankHostedLink> createBankHostedLink({
    required BankLinkPurpose purpose,
    String? accountId,
  });
}
