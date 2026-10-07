import '../models/user_model.dart';
import '../../../core/network/api_client.dart';
import 'auth_repository.dart';

// ================================================================================
// MOCK REPOSITORY: Authentication (DỮ LIỆU GIẢ)
// ================================================================================
// Trả về dữ liệu giả để phát triển UI khi Backend chưa sẵn sàng.
// Có delay giả lập để UI hiển thị loading giống thật.
//
// Khi nào dùng:
//   - Backend chưa code xong API
//   - Test UI offline (không cần mạng)
//   - Demo app cho khách hàng/giảng viên
// ================================================================================

class MockAuthRepository implements AuthRepository {
  /// 1. Tài khoản Quản trị viên (Admin)
  static final adminUser = UserModel(
    id: 'usr-admin-001',
    email: 'admin@feelingtrip.com',
    fullName: 'Quản Trị Viên (Admin)',
    phone: '0988888888',
    avatarUrl:
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    role: 'ADMIN',
    isVerified: true,
    verificationStatus: 'VERIFIED',
  );

  /// 2. Tài khoản User ĐÃ eKYC (Có tích xanh)
  static final verifiedUser = UserModel(
    id: 'usr-verified-002',
    email: 'user.ekyc@feelingtrip.com',
    fullName: 'Lê Hoàng Long (Đã eKYC)',
    phone: '0901234567',
    avatarUrl:
        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    role: 'USER',
    isVerified: true,
    verificationStatus: 'VERIFIED',
  );

  /// 3. Tài khoản User CHƯA eKYC
  static final unverifiedUser = UserModel(
    id: 'usr-unverified-003',
    email: 'user.noekyc@feelingtrip.com',
    fullName: 'Phạm Thu Hà (Chưa eKYC)',
    phone: '0912345678',
    avatarUrl:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
    role: 'USER',
    isVerified: false,
    verificationStatus: 'UNVERIFIED',
  );

  @override
  Future<({UserModel user, String token})> login(
    String email,
    String password,
  ) async {
    // Giả lập thời gian chờ API (0.5 giây)
    await Future.delayed(const Duration(milliseconds: 500));

    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail == 'user.banned@feelingtrip.com') {
      throw ApiException(
        statusCode: 403,
        message: 'Tài khoản đã bị khóa',
        code: 'ACCOUNT_BANNED',
      );
    }

    UserModel selectedUser;

    if (normalizedEmail == 'admin@feelingtrip.com') {
      selectedUser = adminUser;
    } else if (normalizedEmail == 'user.ekyc@feelingtrip.com') {
      selectedUser = verifiedUser;
    } else if (normalizedEmail == 'user.noekyc@feelingtrip.com') {
      selectedUser = unverifiedUser;
    } else {
      throw Exception(
        'Email hoặc mật khẩu không đúng. Vui lòng chọn 1 trong 3 tài khoản mẫu.',
      );
    }

    return (user: selectedUser, token: 'mock_jwt_token_${selectedUser.id}');
  }

  @override
  Future<({UserModel user, String token, String? message})> register({
    required String email,
    required String password,
    required String fullName,
    required bool termsAccepted,
    required String termsVersion,
    String? phone,
  }) async {
    await Future.delayed(const Duration(seconds: 1));

    if (email == 'exists@test.com') {
      throw Exception('Email đã được đăng ký');
    }

    return (
      user: UserModel(
        id: '2',
        email: email,
        fullName: fullName,
        phone: phone,
        role: 'USER',
      ),
      token: 'mock_jwt_token_new_user_456',
      message: 'Đăng ký thành công. Vui lòng kiểm tra email để xác thực.',
    );
  }

  @override
  Future<({UserModel user, String token})> verifyOtp(
    String email,
    String otp,
  ) async {
    throw UnsupportedError(
      'OTP cần backend thật, không xác thực bằng dữ liệu giả.',
    );
  }

  @override
  Future<String> resendOtp(String email) async {
    throw UnsupportedError('OTP cần backend thật để gửi email.');
  }

  @override
  Future<({UserModel user, String token})> googleLogin(String idToken) async {
    await Future.delayed(const Duration(seconds: 1));

    return (
      user: UserModel(
        id: '3',
        email: 'google_user@gmail.com',
        fullName: 'Google User',
        avatarUrl: 'https://via.placeholder.com/150',
        role: 'USER',
      ),
      token: 'mock_jwt_token_google_789',
    );
  }
}
