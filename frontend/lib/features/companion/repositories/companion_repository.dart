import '../models/companion_post_model.dart';
import '../models/companion_request_model.dart';

// ================================================================================
// REPOSITORY ABSTRACT: Companion
// ================================================================================
// "Hợp đồng" cho mọi nguồn dữ liệu Companion (API thật hoặc Mock giả).
// ViewModel chỉ biết abstract class này.
// ================================================================================

abstract class CompanionRepository {
  /// Lấy danh sách bài đăng tìm bạn (feed)
  Future<({List<CompanionPost> posts, PaginationInfo pagination})> getFeed({
    int page = 1,
    int limit = 10,
    String sortBy = 'newest',
    String status = 'OPEN',
    String? destination,
    String? genderPreference,
    int? minAge,
    int? maxAge,
  });

  /// Lấy chi tiết 1 bài đăng
  Future<CompanionPost> getPostDetail(String postId);

  /// Tạo bài đăng mới (leader)
  Future<CompanionPost> createPost({
    required String tripId,
    required String title,
    String? content,
    int? targetMembersCount,
    int? recruitmentCount,
    int? minAge,
    int? maxAge,
    String genderPreference = 'ANY',
    List<String> tags = const [],
  });

  /// Gửi yêu cầu tham gia
  Future<void> createJoinRequest({
    required String postId,
    String? introduction,
  });

  /// Lấy danh sách yêu cầu tham gia leader nhận được
  Future<({List<CompanionRequest> requests, PaginationInfo pagination})>
  getMyReceivedRequests({
    int page = 1,
    int limit = 20,
    String? status,
    String? postId,
  });

  /// Leader xét duyệt yêu cầu (ACCEPTED | REJECTED)
  Future<void> reviewJoinRequest(String requestId, String status);

  Future<void> updatePost(String postId, Map<String, dynamic> data);
  Future<void> closePost(String postId);
  Future<List<Map<String, dynamic>>> getMyPosts({int page = 1});
  Future<List<Map<String, dynamic>>> getPublicPosts({
    required String userId,
    int page = 1,
  });
  Future<List<Map<String, dynamic>>> getMySentRequests({
    String? status,
    int page = 1,
  });

  /// Người gửi hủy yêu cầu
  Future<void> deleteJoinRequest(String requestId);
}
