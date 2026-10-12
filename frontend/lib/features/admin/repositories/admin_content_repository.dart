import 'dart:convert';
import 'dart:typed_data';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../models/admin_content_model.dart';
import '../../map/models/place_model.dart';
import '../../map/repositories/api_place_repository.dart';

// Mock chỉ dùng khi bật USE_MOCK_DATA, không thay thế API nếu mất mạng.
class AdminContentRepository {
  Future<PlacePage> searchTemplatePlaces({
    String keyword = '',
    String destination = '',
    int page = 1,
  }) async {
    if (ApiEndpoints.useMockData) {
      final places = [
        PlaceModel.fromJson({
          'id': '11111111-1111-4111-8111-111111111111',
          'name': 'Hồ Hoàn Kiếm',
          'destination': 'Hà Nội',
          'address': 'Hoàn Kiếm, Hà Nội',
          'category': 'ATTRACTION',
          'latitude': 21.0285,
          'longitude': 105.8542,
          'isActive': true,
        }),
      ];
      final matches = places
          .where(
            (p) => '${p.name} ${p.address}'.toLowerCase().contains(
              keyword.toLowerCase(),
            ),
          )
          .toList();
      return PlacePage(
        items: page == 1 ? matches : [],
        page: page,
        limit: 20,
        total: matches.length,
        totalPages: 1,
      );
    }
    return ApiPlaceRepository().searchPlaces(
      keyword: keyword,
      destination: destination,
      page: page,
      limit: 20,
    );
  }

  static final _mockReports = <Map<String, dynamic>>[
    {
      'id': 'report-demo',
      'reporterName': 'Ngọc Anh',
      'reportedUserName': 'Minh Khang',
      'reportedUserId': '22222222-2222-4222-8222-222222222222',
      'reportedUserRole': 'USER',
      'reportedUserStatus': 'ACTIVE',
      'reason':
          'Thu tiền trước nhưng không thực hiện chuyến đi như đã thỏa thuận.',
      'status': 'PENDING',
      'createdAt': '2026-10-12T09:00:00+07:00',
    },
  ];
  static final _mockPlans = <Map<String, dynamic>>[
    {
      'id': 'template-demo',
      'name': 'Một ngày khám phá Hội An',
      'destination': 'Hội An',
      'durationDays': 1,
      'estimatedBudget': 500000,
      'description': 'Gợi ý lịch trình nhẹ nhàng trong phố cổ.',
      'isActive': true,
      'version': '1',
      'source': 'SYSTEM',
      'usageCount': 0,
      'days': [
        {
          'dayNumber': 1,
          'title': 'Phố cổ Hội An',
          'items': [
            {
              'customName': 'Dạo phố cổ',
              'category': 'ATTRACTION',
              'startTime': '09:00',
              'endTime': '11:00',
              'estimatedCost': 100000,
              'note': 'Chuẩn bị giày đi bộ.',
            },
          ],
        },
      ],
    },
  ];
  Future<List<AdminReport>> reports(String status, String search) async {
    if (ApiEndpoints.useMockData) {
      return _mockReports
          .where(
            (r) =>
                (status.isEmpty || r['status'] == status) &&
                (r['reason'] as String).toLowerCase().contains(
                  search.toLowerCase(),
                ),
          )
          .map(AdminReport.new)
          .toList();
    }
    final items = <AdminReport>[];
    var page = 1;
    while (true) {
      final data =
          (await ApiClient.get(
                '/admin/reports?${Uri(queryParameters: {'status': status, 'search': search, 'page': '$page', 'limit': '50'}).query}',
              ))['data']
              as Map;
      items.addAll(
        (data['items'] as List).map(
          (r) => AdminReport(Map<String, dynamic>.from(r)),
        ),
      );
      if (page >= ((data['pagination']['totalPages'] as num?) ?? 1)) break;
      page++;
    }
    return items;
  }

  static final _mockModerationPosts = <Map<String, dynamic>>[
    {
      'id': 'moderation-1',
      'title': 'Tuyển bạn đi Hội An',
      'trip_name': 'Chuyến đi Hội An',
      'destination': 'Hội An',
      'creator_name': 'Ngọc Anh',
      'content': 'Cùng khám phá phố cổ và chia sẻ chi phí.',
      'current_members_count': 1,
      'target_members_count': 3,
      'status': 'OPEN',
      'report_count': 1,
    },
  ];

  Future<List<Map<String, dynamic>>> moderationPosts({
    String search = '',
    int page = 1,
  }) async {
    if (ApiEndpoints.useMockData) {
      return _mockModerationPosts
          .where(
            (r) =>
                r['status'] != 'CLOSED' &&
                (r['title'] as String).toLowerCase().contains(
                  search.toLowerCase(),
                ),
          )
          .skip((page - 1) * 20)
          .take(20)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    }
    final query = Uri(
      queryParameters: {'search': search, 'page': '$page', 'limit': '20'},
    ).query;
    final data = (await ApiClient.get(
      '/admin/moderation/posts?$query',
    ))['data'];
    return (data['items'] as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  Future<Map<String, dynamic>> moderationPost(String id) async {
    if (ApiEndpoints.useMockData) {
      return Map<String, dynamic>.from(
        _mockModerationPosts.firstWhere((r) => r['id'] == id),
      );
    }
    return Map<String, dynamic>.from(
      (await ApiClient.get('/admin/moderation/posts/$id'))['data'],
    );
  }

  Future<Map<String, dynamic>> moderatePost(
    String id,
    String action,
    String reason,
  ) async {
    if (ApiEndpoints.useMockData) {
      final row = _mockModerationPosts.firstWhere((r) => r['id'] == id);
      if (row['status'] == 'CLOSED') throw Exception('Bài đã đóng');
      if (action == 'HIDE') row['status'] = 'CLOSED';
      return Map<String, dynamic>.from(row);
    }
    return Map<String, dynamic>.from(
      (await ApiClient.put(
        '/admin/moderation/posts/$id',
        body: {'action': action, 'reason': reason},
      ))['data'],
    );
  }

  Future<AdminReport> warnReport(String id, String reason) async {
    if (ApiEndpoints.useMockData) {
      return resolve(id, 'RESOLVED', '[Cảnh cáo] $reason');
    }
    return AdminReport(
      Map<String, dynamic>.from(
        (await ApiClient.put(
          '/admin/reports/$id/warn',
          body: {'reason': reason},
        ))['data'],
      ),
    );
  }

  Future<AdminReport> report(String id) async {
    if (ApiEndpoints.useMockData) {
      return AdminReport(_mockReports.firstWhere((r) => r['id'] == id));
    }
    return AdminReport(
      Map<String, dynamic>.from(
        (await ApiClient.get('/admin/reports/$id'))['data'],
      ),
    );
  }

  Future<AdminReport> resolve(String id, String action, String notes) async {
    if (ApiEndpoints.useMockData) {
      final row = _mockReports.firstWhere((r) => r['id'] == id);
      if (row['status'] != 'PENDING') throw Exception('Báo cáo đã xử lý');
      row['status'] = action;
      row['adminNotes'] = notes;
      return AdminReport(row);
    }
    return AdminReport(
      Map<String, dynamic>.from(
        (await ApiClient.put(
          '/admin/reports/$id/resolve',
          body: {'action': action, 'adminNotes': notes},
        ))['data'],
      ),
    );
  }

  Future<void> ban(String userId, String reason) async {
    await ApiClient.put(
      '/admin/users/$userId/status',
      body: {'status': 'BANNED', 'reason': reason},
    );
  }

  Future<List<LibraryPlan>> plans({
    bool admin = false,
    String source = 'SYSTEM',
    String search = '',
    String sort = 'newest',
    String status = '',
  }) async {
    if (ApiEndpoints.useMockData) {
      return _mockPlans
          .where(
            (p) =>
                (admin || (p['isActive'] == true && source == 'SYSTEM')) &&
                (status.isEmpty || (status == 'ACTIVE') == p['isActive']) &&
                '${p['name']} ${p['destination']}'.toLowerCase().contains(
                  search.toLowerCase(),
                ),
          )
          .map(LibraryPlan.new)
          .toList();
    }
    final result = <LibraryPlan>[];
    var page = 1;
    while (true) {
      final data =
          (await ApiClient.get(
                '/admin/${admin ? 'templates' : 'library'}?${Uri(queryParameters: {'source': source, 'search': search, 'sortBy': sort, 'status': status, 'page': '$page', 'limit': '50'}).query}',
              ))['data']
              as Map;
      result.addAll(
        (data['items'] as List).map(
          (p) => LibraryPlan(Map<String, dynamic>.from(p)),
        ),
      );
      if (page >= ((data['pagination']['totalPages'] as num?) ?? 1)) break;
      page++;
    }
    return result;
  }

  Future<LibraryPlan> plan(
    String id, {
    bool admin = false,
    bool community = false,
  }) async {
    if (ApiEndpoints.useMockData) {
      return LibraryPlan(_mockPlans.firstWhere((p) => p['id'] == id));
    }
    final path = admin
        ? '/admin/templates/$id'
        : '/admin/library/${community ? 'community' : 'templates'}/$id';
    return LibraryPlan(
      Map<String, dynamic>.from((await ApiClient.get(path))['data']),
    );
  }

  Future<LibraryPlan> save(
    Map<String, dynamic> body, {
    LibraryPlan? previous,
    Uint8List? cover,
    String? fileName,
  }) async {
    if (previous != null) body['expectedVersion'] = previous.version;
    if (ApiEndpoints.useMockData) {
      final data = {
        ...body,
        'id': previous?.id ?? 'mock-${DateTime.now().microsecondsSinceEpoch}',
        'isActive': previous?.active ?? true,
        'usageCount': previous?.usage ?? 0,
        'version': '${DateTime.now().microsecondsSinceEpoch}',
        'source': 'SYSTEM',
      };
      _mockPlans.removeWhere((p) => p['id'] == data['id']);
      _mockPlans.add(data);
      return LibraryPlan(data);
    }
    final path = '/admin/templates${previous == null ? '' : '/${previous.id}'}';
    final response = cover == null
        ? (previous == null
              ? await ApiClient.post(path, body: body)
              : await ApiClient.put(path, body: body))
        : await ApiClient.multipart(
            previous == null ? 'POST' : 'PUT',
            path,
            fields: {
              for (final entry in body.entries)
                entry.key: entry.value is List
                    ? jsonEncode(entry.value)
                    : '${entry.value}',
            },
            files: [
              MultipartFileData(
                fieldName: 'coverImage',
                fileName: fileName ?? 'cover.png',
                bytes: cover,
              ),
            ],
          );
    return LibraryPlan(Map<String, dynamic>.from(response['data']));
  }

  Future<void> toggle(LibraryPlan plan) async {
    if (ApiEndpoints.useMockData) {
      _mockPlans.firstWhere((p) => p['id'] == plan.id)['isActive'] =
          !plan.active;
      return;
    }
    await ApiClient.put(
      '/admin/templates/${plan.id}/status',
      body: {'isActive': !plan.active, 'expectedVersion': plan.version},
    );
  }

  Future<void> delete(LibraryPlan plan) async {
    if (ApiEndpoints.useMockData) {
      if (plan.usage > 0) throw Exception('Mẫu đã được sử dụng');
      _mockPlans.removeWhere((p) => p['id'] == plan.id);
      return;
    }
    await ApiClient.delete(
      '/admin/templates/${plan.id}?expectedVersion=${plan.version}',
    );
  }

  Future<List<Map<String, dynamic>>> eligibleTrips(int days) async {
    if (ApiEndpoints.useMockData) {
      return [
        {
          'id': 'trip-demo',
          'name': 'Chuyến đi Hội An của bạn',
          'durationDays': days,
        },
      ];
    }
    final result = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final data =
          (await ApiClient.get('/trips/my-trips?page=$page&limit=50'))['data']
              as Map;
      for (final raw in data['items'] as List) {
        final t = Map<String, dynamic>.from(raw);
        if (t['memberRole'] == 'LEADER' &&
            t['membershipStatus'] == 'ACTIVE' &&
            ['UPCOMING', 'ONGOING'].contains(t['status']) &&
            t['durationDays'] == days) {
          result.add(t);
        }
      }
      if (page >= ((data['pagination']['totalPages'] as num?) ?? 1)) break;
      page++;
    }
    return result;
  }

  Future<void> apply(LibraryPlan plan, String tripId) async {
    if (ApiEndpoints.useMockData) {
      _mockPlans.firstWhere((p) => p['id'] == plan.id)['usageCount'] =
          plan.usage + 1;
      return;
    }
    await ApiClient.post(
      '/admin/library/${plan.community ? 'community' : 'templates'}/${plan.id}/apply',
      body: {'tripId': tripId},
    );
  }

  Future<void> importCommunity(String id) async {
    await ApiClient.post('/admin/templates/from-community/$id');
  }
}
