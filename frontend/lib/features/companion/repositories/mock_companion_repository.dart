import '../models/companion_post_model.dart';
import '../models/companion_request_model.dart';
import 'companion_repository.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ================================================================================
// MOCK REPOSITORY: Companion (DỮ LIỆU GIẢ)
// ================================================================================
// Dùng khi chưa kết nối API. Có delay giả lập loading.
// Đổi sang ApiCompanionRepository() trong ViewModel khi backend sẵn sàng.
// ================================================================================

class MockCompanionRepository implements CompanionRepository {
  Future<bool> hasPostForTrip(String tripId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('mock_companion_trip_$tripId') ?? false;
  }

  Future<String> _requestKey(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final session = jsonDecode(prefs.getString('auth_session') ?? '{}') as Map;
    final userId = (session['user'] as Map?)?['id'] ?? 'current-user';
    return 'mock_join_request_${userId}_$postId';
  }

  // ─── Dữ liệu mẫu ──────────────────────────────────────────────────────────

  static final _mockPosts = <CompanionPost>[
    CompanionPost(
      id: 'post-1',
      title: 'Tìm 3 người đồng hành khám phá Hội An – Tháng 11',
      content:
          'Mình có chuyến đi Hội An 4 ngày 3 đêm, hiện nhóm còn 3 chỗ trống. '
          'Ưu tiên người thích nhiếp ảnh, yêu văn hóa và không ngủ nướng 😄. '
          'Chi phí chia đều, ăn uống thoải mái, không ép theo tour.',
      targetMembersCount: 6,
      currentMembersCount: 3,
      genderPreference: 'ANY',
      tags: ['Nhiếp ảnh', 'Văn hóa', 'Phượt'],
      status: 'OPEN',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      trip: TripInfo(
        id: 'trip-1',
        name: 'Khám phá Hội An mùa lồng đèn',
        destination: 'Hội An, Quảng Nam',
        startDate: DateTime.now().add(const Duration(days: 20)),
        endDate: DateTime.now().add(const Duration(days: 24)),
        durationDays: 4,
        estimatedBudget: 3500000,
        coverImageUrl:
            'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=600&q=80',
        status: 'UPCOMING',
      ),
      creator: const CreatorInfo(
        id: 'user-1',
        fullName: 'Nguyễn Minh Tuấn',
        nickname: 'TuanTravel',
        avatarUrl: 'https://i.pravatar.cc/150?img=12',
        isVerified: true,
        trustScore: 4.8,
        reviewCount: 15,
      ),
    ),
    CompanionPost(
      id: 'post-2',
      title: 'Nhóm leo núi Fansipan – Cuối tuần tháng 10',
      content:
          'Đây là chuyến leo Fansipan bằng cáp treo kết hợp đi bộ Trạm Tôn. '
          'Nhóm cần thêm 2 bạn nữ để cân bằng. Có HDV dẫn đường, '
          'đồ ăn và lều ngủ chuẩn bị sẵn.',
      targetMembersCount: 8,
      currentMembersCount: 6,
      genderPreference: 'FEMALE',
      tags: ['Leo núi', 'Phiêu lưu', 'Sapa'],
      status: 'OPEN',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      trip: TripInfo(
        id: 'trip-2',
        name: 'Fansipan – Nóc nhà Đông Dương',
        destination: 'Sapa, Lào Cai',
        startDate: DateTime.now().add(const Duration(days: 8)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        durationDays: 3,
        estimatedBudget: 2800000,
        coverImageUrl:
            'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600&q=80',
        status: 'UPCOMING',
      ),
      creator: const CreatorInfo(
        id: 'user-2',
        fullName: 'Trần Thị Lan',
        nickname: 'LanAdventure',
        avatarUrl: 'https://i.pravatar.cc/150?img=47',
        isVerified: true,
        trustScore: 4.5,
        reviewCount: 8,
      ),
    ),
    CompanionPost(
      id: 'post-3',
      title: 'Road trip Hà Giang 5N4Đ – Tìm thêm 1 tay lái xe máy',
      content:
          'Chuyến loop Hà Giang kinh điển: Đồng Văn, Mã Pì Lèng, Lũng Cú. '
          'Cần thêm 1 bạn nam biết lái xe tay ga, có giấy phép lái xe.',
      targetMembersCount: 4,
      currentMembersCount: 3,
      genderPreference: 'MALE',
      tags: ['Road trip', 'Xe máy', 'Hà Giang', 'Thác'],
      status: 'OPEN',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      trip: TripInfo(
        id: 'trip-3',
        name: 'Hà Giang Loop – Mùa tam giác mạch',
        destination: 'Hà Giang',
        startDate: DateTime.now().add(const Duration(days: 15)),
        endDate: DateTime.now().add(const Duration(days: 20)),
        durationDays: 5,
        estimatedBudget: 4200000,
        coverImageUrl:
            'https://images.unsplash.com/photo-1540973126739-e34e73e8e3fe?w=600&q=80',
        status: 'UPCOMING',
      ),
      creator: const CreatorInfo(
        id: 'user-3',
        fullName: 'Phạm Quang Hùng',
        nickname: null,
        avatarUrl: 'https://i.pravatar.cc/150?img=7',
        isVerified: false,
        trustScore: 3.9,
        reviewCount: 4,
      ),
    ),
    CompanionPost(
      id: 'post-4',
      title: 'Du lịch Phú Quốc 4N3Đ – Nhóm gia đình thân thiện',
      content:
          'Chuyến đi Phú Quốc nghỉ dưỡng, có trẻ em đi cùng. Cần thêm 1-2 '
          'cặp gia đình hoặc nhóm bạn trưởng thành, thích biển, không thích '
          'nhậu nhẹt khuya. Resort 3 sao, đặt tour trọn gói.',
      targetMembersCount: 10,
      currentMembersCount: 10,
      genderPreference: 'ANY',
      tags: ['Nghỉ dưỡng', 'Biển', 'Gia đình', 'Resort'],
      status: 'FULL',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      trip: TripInfo(
        id: 'trip-4',
        name: 'Phú Quốc – Đảo Ngọc',
        destination: 'Phú Quốc, Kiên Giang',
        startDate: DateTime.now().add(const Duration(days: 30)),
        endDate: DateTime.now().add(const Duration(days: 34)),
        durationDays: 4,
        estimatedBudget: 6500000,
        coverImageUrl:
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&q=80',
        status: 'UPCOMING',
      ),
      creator: const CreatorInfo(
        id: 'user-4',
        fullName: 'Lê Thị Hoa',
        nickname: 'HoaFamilyTrip',
        avatarUrl: 'https://i.pravatar.cc/150?img=32',
        isVerified: true,
        trustScore: 4.9,
        reviewCount: 22,
      ),
    ),
    CompanionPost(
      id: 'post-5',
      title: 'Backpack Đà Lạt 3N2Đ – Budget dưới 2 triệu',
      content:
          'Chuyến đi Đà Lạt siêu tiết kiệm: ở homestay, đi thuê xe máy khám '
          'phá, ăn quán bình dân. Không cần chi phí xa xỉ, chỉ cần vui. '
          'Cần thêm 2 bạn cùng phòng giảm chi phí.',
      targetMembersCount: 4,
      currentMembersCount: 2,
      genderPreference: 'ANY',
      tags: ['Budget', 'Backpack', 'Đà Lạt', 'Homestay'],
      status: 'OPEN',
      createdAt: DateTime.now().subtract(const Duration(hours: 10)),
      trip: TripInfo(
        id: 'trip-5',
        name: 'Đà Lạt budget trip',
        destination: 'Đà Lạt, Lâm Đồng',
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 8)),
        durationDays: 3,
        estimatedBudget: 1800000,
        coverImageUrl:
            'https://images.unsplash.com/photo-1598135753163-6167c1a1ad65?w=600&q=80',
        status: 'UPCOMING',
      ),
      creator: const CreatorInfo(
        id: 'user-5',
        fullName: 'Võ Văn Nam',
        nickname: 'NamBudgetTrip',
        avatarUrl: 'https://i.pravatar.cc/150?img=25',
        isVerified: false,
        trustScore: 4.1,
        reviewCount: 6,
      ),
    ),
  ];

  static final _mockRequests = <CompanionRequest>[
    CompanionRequest(
      id: 'req-1',
      postId: 'post-1',
      introduction:
          'Mình là dân nhiếp ảnh nghiệp dư, rất thích chụp ảnh đường phố và '
          'kiến trúc cổ. Đã đi Hội An 1 lần nhưng chưa đủ thời gian khám phá. '
          'Mình không ồn ào, thích chill và tôn trọng schedule của nhóm.',
      status: 'PENDING',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      requester: const RequesterInfo(
        id: 'user-10',
        fullName: 'Đặng Thị Thu',
        nickname: 'ThuPhoto',
        avatarUrl: 'https://i.pravatar.cc/150?img=44',
        phone: '0912345678',
        isVerified: true,
        trustScore: 4.6,
        reviewCount: 9,
      ),
    ),
    CompanionRequest(
      id: 'req-2',
      postId: 'post-1',
      introduction:
          'Hi, mình đang làm freelancer và có thể linh hoạt lịch. '
          'Mình thích ăn uống địa phương và thích khám phá ngõ hẻm hơn là '
          'đi theo tour. Nếu nhóm chill thì mình fit lắm!',
      status: 'PENDING',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      requester: const RequesterInfo(
        id: 'user-11',
        fullName: 'Bùi Quang Minh',
        nickname: null,
        avatarUrl: 'https://i.pravatar.cc/150?img=15',
        phone: '0987654321',
        isVerified: false,
        trustScore: 3.8,
        reviewCount: 2,
      ),
    ),
    CompanionRequest(
      id: 'req-3',
      postId: 'post-1',
      introduction: 'Mình đã đi nhiều tỉnh miền Trung, rất muốn được tham gia.',
      status: 'ACCEPTED',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      requester: const RequesterInfo(
        id: 'user-12',
        fullName: 'Ngô Thị Bình',
        nickname: 'BinhExplorer',
        avatarUrl: 'https://i.pravatar.cc/150?img=38',
        phone: '0901111222',
        isVerified: true,
        trustScore: 4.3,
        reviewCount: 11,
      ),
    ),
  ];

  // ─── Implementations ───────────────────────────────────────────────────────

  @override
  Future<({List<CompanionPost> posts, PaginationInfo pagination})> getFeed({
    int page = 1,
    int limit = 10,
    String sortBy = 'newest',
    String status = 'OPEN',
    String? destination,
    String? genderPreference,
    int? minAge,
    int? maxAge,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    var filtered = _mockPosts.where((p) {
      if (status.isNotEmpty && p.status != status) return false;
      if (destination != null &&
          destination.isNotEmpty &&
          !(p.trip.destination?.toLowerCase().contains(
                destination.toLowerCase(),
              ) ??
              false)) {
        return false;
      }
      if (genderPreference != null &&
          genderPreference.isNotEmpty &&
          p.genderPreference != 'ANY' &&
          p.genderPreference != genderPreference) {
        return false;
      }
      return true;
    }).toList();

    // Sort
    if (sortBy == 'rating') {
      filtered.sort(
        (a, b) => b.creator.trustScore.compareTo(a.creator.trustScore),
      );
    } else if (sortBy == 'departure_date') {
      filtered.sort(
        (a, b) => (a.trip.startDate ?? DateTime(9999)).compareTo(
          b.trip.startDate ?? DateTime(9999),
        ),
      );
    } else if (sortBy == 'oldest') {
      filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final total = filtered.length;
    final offset = (page - 1) * limit;
    final paged = filtered.skip(offset).take(limit).toList();

    return (
      posts: paged,
      pagination: PaginationInfo(
        totalItems: total,
        totalPages: (total / limit).ceil().clamp(1, 999),
        currentPage: page,
        limit: limit,
      ),
    );
  }

  @override
  Future<CompanionPost> getPostDetail(String postId) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final post = _mockPosts.firstWhere(
      (p) => p.id == postId,
      orElse: () => throw Exception('Bài đăng không tồn tại'),
    );
    final prefs = await SharedPreferences.getInstance();
    final requestStatus = prefs.getString(await _requestKey(postId));
    // Trả về post với members mô phỏng
    return CompanionPost(
      id: post.id,
      myRequestStatus: requestStatus,
      myRequestId: requestStatus == null ? null : 'mock-$postId',
      title: post.title,
      content: post.content,
      targetMembersCount: post.targetMembersCount,
      currentMembersCount: post.currentMembersCount,
      minAge: post.minAge,
      maxAge: post.maxAge,
      genderPreference: post.genderPreference,
      tags: post.tags,
      status: post.status,
      createdAt: post.createdAt,
      updatedAt: post.updatedAt,
      creator: post.creator,
      trip: TripInfo(
        id: post.trip.id,
        name: post.trip.name,
        destination: post.trip.destination,
        startDate: post.trip.startDate,
        endDate: post.trip.endDate,
        durationDays: post.trip.durationDays,
        estimatedBudget: post.trip.estimatedBudget,
        coverImageUrl: post.trip.coverImageUrl,
        status: post.trip.status,
        itinerary: post.trip.itinerary,
        members: [
          TripMemberInfo(
            userId: post.creator.id,
            displayName: post.creator.displayName,
            avatarUrl: post.creator.avatarUrl,
            role: 'LEADER',
            joinedAt: post.createdAt.subtract(const Duration(days: 5)),
          ),
          const TripMemberInfo(
            userId: 'member-mock-1',
            displayName: 'Thành viên 2',
            avatarUrl: 'https://i.pravatar.cc/150?img=20',
            role: 'MEMBER',
          ),
          const TripMemberInfo(
            userId: 'member-mock-2',
            displayName: 'Thành viên 3',
            avatarUrl: 'https://i.pravatar.cc/150?img=22',
            role: 'MEMBER',
          ),
        ],
      ),
    );
  }

  @override
  Future<CompanionPost> createPost({
    required String tripId,
    required String title,
    String? content,
    required int targetMembersCount,
    int? minAge,
    int? maxAge,
    String genderPreference = 'ANY',
    List<String> tags = const [],
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    var trip = TripInfo(
      id: tripId,
      destination: 'Điểm đến (Mock)',
      status: 'UPCOMING',
    );
    for (final post in _mockPosts) {
      if (post.trip.id == tripId) {
        trip = post.trip;
        break;
      }
    }
    final newPost = CompanionPost(
      id: 'post-mock-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      content: content,
      targetMembersCount: targetMembersCount,
      currentMembersCount: 1,
      genderPreference: genderPreference,
      minAge: minAge,
      maxAge: maxAge,
      tags: tags,
      status: 'OPEN',
      createdAt: DateTime.now(),
      trip: trip,
      creator: const CreatorInfo(
        id: 'current-user',
        fullName: 'Bạn',
        isVerified: true,
      ),
    );
    _mockPosts.insert(0, newPost);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mock_companion_trip_$tripId', true);
    return newPost;
  }

  @override
  Future<void> createJoinRequest({
    required String postId,
    String? introduction,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(await _requestKey(postId), 'PENDING');
  }

  @override
  Future<({List<CompanionRequest> requests, PaginationInfo pagination})>
  getMyReceivedRequests({
    int page = 1,
    int limit = 20,
    String? status,
    String? postId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    var filtered = _mockRequests.where((r) {
      if (status != null && status.isNotEmpty && r.status != status) {
        return false;
      }
      if (postId != null && postId.isNotEmpty && r.postId != postId) {
        return false;
      }
      return true;
    }).toList();

    final total = filtered.length;
    final offset = (page - 1) * limit;
    final paged = filtered.skip(offset).take(limit).toList();

    return (
      requests: paged,
      pagination: PaginationInfo(
        totalItems: total,
        totalPages: (total / limit).ceil().clamp(1, 999),
        currentPage: page,
        limit: limit,
      ),
    );
  }

  @override
  Future<void> reviewJoinRequest(String requestId, String status) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final idx = _mockRequests.indexWhere((r) => r.id == requestId);
    if (idx == -1) throw Exception('Yêu cầu không tồn tại');
    _mockRequests[idx] = CompanionRequest(
      id: _mockRequests[idx].id,
      postId: _mockRequests[idx].postId,
      introduction: _mockRequests[idx].introduction,
      status: status,
      createdAt: _mockRequests[idx].createdAt,
      requester: _mockRequests[idx].requester,
    );
  }

  @override
  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    final index = _mockPosts.indexWhere((p) => p.id == postId);
    if (index < 0) throw Exception('Bài đăng không tồn tại');
    final p = _mockPosts[index];
    final target = data['targetMembersCount'] as int? ?? p.targetMembersCount;
    if (target < p.currentMembersCount) {
      throw Exception('Số lượng mục tiêu nhỏ hơn số thành viên hiện có');
    }
    _mockPosts[index] = CompanionPost(
      id: p.id,
      title: data['title'] ?? p.title,
      content: data['content'] ?? p.content,
      targetMembersCount: target,
      currentMembersCount: p.currentMembersCount,
      minAge: data.containsKey('minAge') ? data['minAge'] : p.minAge,
      maxAge: data.containsKey('maxAge') ? data['maxAge'] : p.maxAge,
      genderPreference: data['genderPreference'] ?? p.genderPreference,
      tags: List<String>.from(data['tags'] ?? p.tags),
      status: target <= p.currentMembersCount ? 'FULL' : 'OPEN',
      createdAt: p.createdAt,
      updatedAt: DateTime.now(),
      trip: p.trip,
      creator: p.creator,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMyPosts({int page = 1}) async =>
      _mockPosts
          .where((p) => p.creator.id == 'current-user')
          .skip((page - 1) * 20)
          .take(20)
          .map(
            (p) => {
              'id': p.id,
              'title': p.title,
              'status': p.status,
              'trip_name': p.trip.name,
              'destination': p.trip.destination,
            },
          )
          .toList();

  @override
  Future<void> closePost(String postId) async {
    final p = _mockPosts.firstWhere((p) => p.id == postId);
    _mockPosts.removeWhere((p) => p.id == postId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('mock_companion_trip_${p.trip.id}');
  }

  @override
  Future<List<Map<String, dynamic>>> getMySentRequests({
    String? status,
    int page = 1,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rows = <Map<String, dynamic>>[];
    for (final p in _mockPosts) {
      final state = prefs.getString(await _requestKey(p.id));
      if (state != null &&
          (status == null || status.isEmpty || state == status)) {
        rows.add({
          'id': 'mock-${p.id}',
          'postId': p.id,
          'title': p.title,
          'tripName': p.trip.name,
          'postStatus': p.status,
          'status': state,
        });
      }
    }
    final offset = (page - 1) * 20;
    return rows.skip(offset).take(20).toList();
  }

  @override
  Future<void> deleteJoinRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (requestId.startsWith('mock-')) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(await _requestKey(requestId.substring(5)));
    }
    _mockRequests.removeWhere((r) => r.id == requestId);
  }
}
