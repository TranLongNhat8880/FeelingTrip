import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/features/companion/repositories/api_companion_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/companion/models/companion_post_model.dart';
import 'package:feeling_trip/features/companion/repositories/mock_companion_repository.dart';
import 'package:feeling_trip/features/companion/views/companion_my_posts_screen.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

class MyPostsRepository extends MockCompanionRepository {
  int detailCalls = 0;
  @override
  Future<List<Map<String, dynamic>>> getMyPosts({int page = 1}) async => [
    {
      'id': 'one',
      'title': 'Tìm bạn đồng hành: Chuyến đi Hồ Hoàn Kiếm',
      'trip_name': 'Chuyến đi Hồ Hoàn Kiếm',
      'status': 'OPEN',
    },
    {
      'id': 'two',
      'title': 'Chuyến đi Hà Nội',
      'status': 'FULL',
      'trip_cover_image_url': '',
    },
  ];
  @override
  Future<CompanionPost> getPostDetail(String id) async {
    detailCalls++;
    throw Exception('Thumbnail request failed');
  }
}

class PublicPostsRepository extends MyPostsRepository {
  String? viewedUserId;
  @override
  Future<List<Map<String, dynamic>>> getMyPosts({int page = 1}) async =>
      throw StateError('Must not load signed-in user posts');
  @override
  Future<List<Map<String, dynamic>>> getPublicPosts({
    required String userId,
    int page = 1,
  }) async {
    viewedUserId = userId;
    return [
      {
        'id': 'public-post',
        'title': 'Bài viết của người đang xem',
        'status': 'CLOSED',
        'trip_cover_image_url': null,
      },
    ];
  }
}

void main() {
  testWidgets(
    'my posts stay compact and usable without images or thumbnail API',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MyPostsRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CompanionMyPostsScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Card), findsNothing);
      expect(find.byType(AppCard), findsNothing);
      expect(find.text('Chuyến đi Hồ Hoàn Kiếm'), findsOneWidget);
      expect(find.textContaining('Tìm bạn đồng hành:'), findsNothing);
      expect(find.text('Đang mở'), findsOneWidget);
      expect(find.text('Đã đủ'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(repo.detailCalls, 1);
      final title = tester.getCenter(find.text('Chuyến đi Hà Nội'));
      final status = tester.getCenter(find.text('Đã đủ'));
      expect((title.dy - status.dy).abs(), lessThan(1));
      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(repo.detailCalls, 1);
    },
  );
  testWidgets(
    'public list requests the viewed author and uses supplied thumbnail data',
    (tester) async {
      final repo = PublicPostsRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CompanionMyPostsScreen(repository: repo, userId: 'viewed-user'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.viewedUserId, 'viewed-user');
      expect(repo.detailCalls, 0);
      expect(find.text('Bài viết'), findsOneWidget);
      expect(find.text('Bài viết của người đang xem'), findsOneWidget);
      expect(find.text('Đã đóng'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'API public list sends author and pagination to the dedicated endpoint',
    () async {
      SharedPreferences.setMockInitialValues({});
      final original = ApiClient.client;
      ApiClient.client = MockClient((request) async {
        expect(
          request.url.path,
          endsWith('/companions/users/viewed-user/posts'),
        );
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['limit'], '20');
        return http.Response(
          jsonEncode({
            'data': {
              'posts': [
                {'id': 'p', 'status': 'CLOSED', 'trip_cover_image_url': null},
              ],
              'pagination': {
                'totalItems': 21,
                'totalPages': 2,
                'currentPage': 2,
                'limit': 20,
              },
            },
          }),
          200,
        );
      });
      try {
        final rows = await ApiCompanionRepository().getPublicPosts(
          userId: 'viewed-user',
          page: 2,
        );
        expect(rows.single['id'], 'p');
        expect(rows.single['status'], 'CLOSED');
        expect(rows.single.containsKey('trip_cover_image_url'), isTrue);
      } finally {
        ApiClient.client.close();
        ApiClient.client = original;
      }
    },
  );
}
