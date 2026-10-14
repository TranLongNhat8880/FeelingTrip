import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/network/storage_helper.dart';
import 'package:feeling_trip/features/auth/repositories/api_auth_repository.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:feeling_trip/features/companion/repositories/api_companion_repository.dart';
import 'package:feeling_trip/features/companion/repositories/companion_trip_repository.dart';
import 'package:feeling_trip/features/notification/viewmodels/notification_viewmodel.dart';
import 'package:feeling_trip/features/admin/viewmodels/admin_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Live API: companion, notifications, admin and blocked login',
    () async {
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      final fixture =
          jsonDecode(File('.tmp/api-fixture.json').readAsStringSync()) as Map;
      final users = fixture['users'] as Map;
      Future<void> login(String key) async {
        final session = await ApiAuthRepository().login(
          users[key]['email'],
          fixture['password'],
        );
        await StorageHelper.saveSession(session.token, session.user);
      }

      final companion = ApiCompanionRepository();
      await login('leader');
      final trips = await CompanionTripRepository().getMyTrips();
      expect(trips.any((trip) => trip['id'] == fixture['tripId']), isTrue);
      final post = await companion.createPost(
        tripId: fixture['tripId'],
        title: 'API Test: Cùng khám phá Hội An',
        content: 'Mình tìm bạn cùng khám phá Hội An và chia sẻ chi phí.',
        targetMembersCount: 4,
        tags: ['Nhiếp ảnh'],
      );
      expect(post.trip.id, fixture['tripId']);
      expect(post.trip.estimatedBudget, 3500000);
      expect(post.trip.members.single.userId, users['leader']['id']);
      final feed = await companion.getFeed(destination: 'Hội An');
      expect(feed.posts.any((item) => item.id == post.id), isTrue);
      await login('member');
      await companion.createJoinRequest(
        postId: post.id,
        introduction: 'Mình muốn tham gia chuyến đi.',
      );
      await expectLater(
        companion.createJoinRequest(postId: post.id, introduction: 'Lần hai'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.statusCode,
            'status',
            409,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await login('leader');
      final requests = await companion.getMyReceivedRequests(postId: post.id);
      expect(requests.requests.single.requester.id, users['member']['id']);
      final notifications = NotificationViewModel();
      await notifications.load();
      expect(notifications.errorMessage, isNull);
      expect(notifications.items.any((item) => item.postId == post.id), isTrue);
      expect(await notifications.markAllRead(), isTrue);
      await notifications.load();
      expect(notifications.unreadCount, 0);
      expect(await notifications.deleteAll(), isTrue);
      await notifications.load();
      expect(notifications.items, isEmpty);
      notifications.dispose();
      await companion.reviewJoinRequest(
        requests.requests.single.id,
        'ACCEPTED',
      );
      final detail = await companion.getPostDetail(post.id);
      expect(
        detail.trip.members.any(
          (member) => member.userId == users['member']['id'],
        ),
        isTrue,
      );
      expect(detail.currentMembersCount, 2);
      await login('member');
      final memberNotifications = NotificationViewModel();
      await memberNotifications.load();
      expect(memberNotifications.unreadCount, greaterThan(0));
      final notice = memberNotifications.items.first;
      expect(await memberNotifications.markRead(notice), isTrue);
      expect(await memberNotifications.delete(notice), isTrue);
      memberNotifications.dispose();
      await login('admin');
      final admin = AdminViewModel();
      await admin.load();
      expect(admin.errorMessage, isNull);
      final pending = admin.pending.firstWhere(
        (user) => user.id == users['pending']['id'],
      );
      expect(await admin.review(pending, true), isTrue);
      final rejected = admin.pending.firstWhere(
        (user) => user.id == users['reject']['id'],
      );
      expect(
        await admin.review(rejected, false, reason: 'API test: ảnh chưa rõ'),
        isTrue,
      );
      final target = admin.users.firstWhere(
        (user) => user.id == users['member']['id'],
      );
      expect(await admin.updateStatus(target), isTrue);
      expect(target.status, 'BANNED');
      final auth = AuthViewModel();
      expect(
        await auth.login(users['member']['email'], fixture['password']),
        isFalse,
      );
      expect(auth.blockedEmail, users['member']['email']);
      expect(await admin.updateStatus(target), isTrue);
      expect(
        await auth.login(users['member']['email'], fixture['password']),
        isTrue,
      );
      await auth.logout();
      admin.dispose();
      // Leave seeded accounts/trip in local dev for manual testing; no user data removed.
    },
    skip: !const bool.fromEnvironment('LIVE_API_TEST'),
  );
}
