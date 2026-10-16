import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/admin/models/admin_content_model.dart';
import 'package:feeling_trip/features/admin/viewmodels/admin_viewmodel.dart';
import 'package:feeling_trip/features/admin/repositories/admin_content_repository.dart';
import 'package:feeling_trip/features/admin/views/admin_moderation_screen.dart';

class MediaRepository extends AdminContentRepository {
  @override
  Future<List<Map<String, dynamic>>> moderationPosts({
    String search = '',
    int page = 1,
  }) async => [
    {
      'id': 'photo',
      'title': 'Bài có ảnh',
      'trip_cover_image_url': 'https://example.com/trip.jpg',
    },
    {'id': 'none', 'title': 'Bài không ảnh', 'trip_cover_image_url': null},
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('pending eKYC merge keeps avatar returned by admin users API', () async {
    SharedPreferences.setMockInitialValues({});
    final previous = ApiClient.client;
    ApiClient.client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'data': {
            request.url.path.endsWith('/users') ? 'users' : 'profiles': [
              {
                'id': 'u',
                'fullName': 'Test',
                'email': 'test@example.com',
                if (request.url.path.endsWith('/users'))
                  'avatarUrl': 'https://example.com/avatar.jpg',
              },
            ],
            'pagination': {'totalPages': 1},
          },
        }),
        200,
      ),
    );
    addTearDown(() => ApiClient.client = previous);
    final users = await ApiAdminRepository().getUsers();
    expect(users.single.avatarUrl, 'https://example.com/avatar.jpg');
    expect(
      AdminReport({
        'id': 'r',
        'reportedUserAvatarUrl': 'https://example.com/target.jpg',
      }).userAvatarUrl,
      'https://example.com/target.jpg',
    );
  });

  testWidgets(
    'post media uses actual cover; missing or broken image has no document placeholder',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AdminModerationScreen(repository: MediaRepository()),
        ),
      );
      await tester.pumpAndSettle();
      final photo = find.widgetWithText(ListTile, 'Bài có ảnh');
      final none = find.widgetWithText(ListTile, 'Bài không ảnh');
      final image = tester.widget<Image>(
        find.descendant(of: photo, matching: find.byType(Image)),
      );
      expect((image.image as NetworkImage).url, 'https://example.com/trip.jpg');
      expect(tester.widget<ListTile>(none).leading, isNull);
      expect(find.byIcon(Icons.description_outlined), findsNothing);
      expect(tester.widget<ListTile>(photo).hoverColor, Colors.transparent);
      expect(tester.takeException(), isNull);
    },
  );
}
