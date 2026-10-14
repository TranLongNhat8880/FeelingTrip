import 'package:feeling_trip/core/constants/api_endpoints.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import '../models/companion_post_model.dart';
import '../models/companion_request_model.dart';
import 'companion_repository.dart';

// ================================================================================
// REPOSITORY IMPLEMENTATION: ApiCompanionRepository
// ================================================================================
// Gọi trực tiếp các REST API của backend thông qua ApiClient.
// ================================================================================

class ApiCompanionRepository implements CompanionRepository {
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
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sortBy': sortBy,
      'status': status,
      if (destination != null && destination.isNotEmpty)
        'destination': destination,
      if (genderPreference != null && genderPreference.isNotEmpty)
        'genderPreference': genderPreference,
      if (minAge != null) 'minAge': minAge.toString(),
      if (maxAge != null) 'maxAge': maxAge.toString(),
    };

    final queryString = Uri(queryParameters: queryParams).query;
    final endpoint = '${ApiEndpoints.companions}/feed?$queryString';

    final response = await ApiClient.get(endpoint);
    final data = response['data'] as Map<String, dynamic>;

    final postsJson = (data['posts'] as List<dynamic>?) ?? [];
    final posts = postsJson
        .map((item) => CompanionPost.fromJson(item as Map<String, dynamic>))
        .toList();

    final paginationJson = (data['pagination'] as Map<String, dynamic>?) ?? {};
    final pagination = PaginationInfo.fromJson(paginationJson);

    return (posts: posts, pagination: pagination);
  }

  @override
  Future<CompanionPost> getPostDetail(String postId) async {
    final endpoint = '${ApiEndpoints.companions}/posts/$postId';
    final response = await ApiClient.get(endpoint);
    final data = response['data'] as Map<String, dynamic>;
    return CompanionPost.fromJson(data);
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
    final endpoint = '${ApiEndpoints.companions}/posts';
    final body = <String, dynamic>{
      'tripId': tripId,
      'title': title,
      'content': ?content,
      'targetMembersCount': targetMembersCount,
      'minAge': ?minAge,
      'maxAge': ?maxAge,
      'genderPreference': genderPreference,
      'tags': tags,
    };

    final response = await ApiClient.post(endpoint, body: body);
    final data = response['data'] as Map<String, dynamic>;
    return getPostDetail(data['id'].toString());
  }

  @override
  Future<void> createJoinRequest({
    required String postId,
    String? introduction,
  }) async {
    final endpoint = '${ApiEndpoints.companions}/join-request';
    final body = <String, dynamic>{
      'postId': postId,
      'introduction': ?introduction,
    };

    await ApiClient.post(endpoint, body: body);
  }

  @override
  Future<({List<CompanionRequest> requests, PaginationInfo pagination})>
  getMyReceivedRequests({
    int page = 1,
    int limit = 20,
    String? status,
    String? postId,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (status != null && status.isNotEmpty) 'status': status,
      if (postId != null && postId.isNotEmpty) 'postId': postId,
    };

    final queryString = Uri(queryParameters: queryParams).query;
    final endpoint = '${ApiEndpoints.companions}/my-requests?$queryString';

    final response = await ApiClient.get(endpoint);
    final data = response['data'] as Map<String, dynamic>;

    final requestsJson = (data['requests'] as List<dynamic>?) ?? [];
    final requests = requestsJson
        .map((item) => CompanionRequest.fromJson(item as Map<String, dynamic>))
        .toList();

    final paginationJson = (data['pagination'] as Map<String, dynamic>?) ?? {};
    final pagination = PaginationInfo.fromJson(paginationJson);

    return (requests: requests, pagination: pagination);
  }

  @override
  Future<void> reviewJoinRequest(String requestId, String status) async {
    final endpoint = '${ApiEndpoints.companions}/requests/$requestId';
    final body = <String, dynamic>{'status': status};

    await ApiClient.put(endpoint, body: body);
  }

  @override
  Future<void> updatePost(String postId, Map<String, dynamic> data) async {
    await ApiClient.patch(
      '${ApiEndpoints.companions}/posts/$postId',
      body: data,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getMyPosts({int page = 1}) async {
    final rows =
        (await ApiClient.get(
              '${ApiEndpoints.companions}/my-posts?page=$page&limit=20',
            ))['data']
            as List;
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  @override
  Future<void> closePost(String postId) async {
    await ApiClient.delete('${ApiEndpoints.companions}/posts/$postId');
  }

  @override
  Future<List<Map<String, dynamic>>> getMySentRequests({
    String? status,
    int page = 1,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'limit': '20',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    ).query;
    final response = await ApiClient.get(
      '${ApiEndpoints.companions}/sent-requests?$query',
    );
    return (response['data']['requests'] as List)
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  @override
  Future<void> deleteJoinRequest(String requestId) async {
    final endpoint = '${ApiEndpoints.companions}/requests/$requestId';
    await ApiClient.delete(endpoint);
  }
}
