import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:feeling_trip/features/companion/models/companion_post_model.dart';
import 'package:feeling_trip/features/companion/repositories/mock_companion_repository.dart';
import 'package:feeling_trip/features/companion/views/companion_detail_screen.dart';
import 'package:feeling_trip/features/companion/views/widgets/companion_post_card.dart';
import 'package:feeling_trip/features/profile/models/trust_score_model.dart';
import 'package:feeling_trip/features/profile/repositories/api_profile_repository.dart';
import 'package:feeling_trip/features/profile/repositories/profile_repository.dart';
import 'package:feeling_trip/features/profile/viewmodels/public_profile_viewmodel.dart';
import 'package:feeling_trip/features/profile/views/public_profile_screen.dart';
import 'package:feeling_trip/features/trip/models/trip_model.dart';
import 'package:feeling_trip/features/trip/views/widgets/trip_widgets.dart';
import 'package:feeling_trip/routes/app_routes.dart';

Map<String, dynamic> profileJson(
  String id, {
  int count = 3,
  double score = 4.7,
}) => {
  'id': id, 'fullName': 'Họ tên $id', 'nickname': 'Tên $id',
  'bio': 'Thích khám phá và đi bộ.', 'isVerified': true,
  'trustScore': score,
  'reviewCount': count,
  'memberSince': '2025-01-15T00:00:00Z',
  'age': 21,
  // Defensive UI regression: private data must never be displayed even if supplied.
  'phone': 'PRIVATE_PHONE',
  'dob': 'PRIVATE_DOB',
  'gender': 'PRIVATE_GENDER',
  'role': 'PRIVATE_ROLE',
  'email': 'PRIVATE_EMAIL',
  'bankAccountNumber': 'PRIVATE_BANK',
  'cccdNumber': 'PRIVATE_CCCD',
  'verificationRejectionReason': 'PRIVATE_EKYC_REASON',
};

class PublicRepository extends Fake implements ProfileRepository {
  final calls = <String>[];
  final pending = <String, Completer<TrustScoreModel>>{};
  int? failure;
  String? wrongId;
  int count = 3;
  double score = 4.7;
  @override
  Future<TrustScoreModel> getTrustScore(String id) async {
    calls.add(id);
    if (failure != null) {
      throw ApiException(statusCode: failure!, message: 'Không tải được');
    }
    if (pending.containsKey(id)) return pending[id]!.future;
    return TrustScoreModel.fromJson(
      profileJson(wrongId ?? id, count: count, score: score),
    );
  }
}

CompanionPost postFixture() => CompanionPost(
  id: 'post-test',
  title: 'Bài tuyển kiểm thử',
  currentMembersCount: 2,
  targetMembersCount: 3,
  createdAt: DateTime(2026, 10, 14),
  creator: const CreatorInfo(id: 'leader', fullName: 'Trưởng nhóm'),
  trip: const TripInfo(
    id: 'trip-test',
    status: 'UPCOMING',
    members: [
      TripMemberInfo(
        userId: 'leader',
        displayName: 'Trưởng nhóm',
        role: 'LEADER',
      ),
      TripMemberInfo(
        userId: 'member-b',
        displayName: 'Thành viên B',
        role: 'MEMBER',
      ),
    ],
  ),
);

class PostRepository extends MockCompanionRepository {
  @override
  Future<CompanionPost> getPostDetail(String id) async => postFixture();
}

Future<void> mobile(
  WidgetTester tester,
  Widget home, {
  bool routes = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: home,
      onGenerateRoute: routes ? AppRoutes.onGenerateRoute : null,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late http.Client originalClient;
  final requested = <String>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalClient = ApiClient.client;
    requested.clear();
    // Offline mock only; an unexpected endpoint fails the test.
    ApiClient.client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, contains('/users/trust-score/'));
      final id = request.url.pathSegments.last;
      requested.add(id);
      return http.Response(
        jsonEncode({'data': profileJson(id)}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  });
  tearDown(() {
    ApiClient.client.close();
    ApiClient.client = originalClient;
  });

  test(
    'API gets the requested user, not the editable /users/profile endpoint',
    () async {
      final profile = await ApiProfileRepository().getTrustScore('member-b');
      expect(profile.id, 'member-b');
      expect(profile.displayName, 'Tên member-b');
      expect(requested, ['member-b']);
    },
  );

  test('empty userId never calls the API', () async {
    final repo = PublicRepository();
    final vm = PublicProfileViewModel(repository: repo);
    addTearDown(vm.dispose);
    await vm.load('  ');
    expect(repo.calls, isEmpty);
    expect(vm.isLoading, isFalse);
    expect(vm.errorMessage, contains('userId'));
  });

  test(
    'public age is optional and never derived from a leaked date of birth',
    () {
      final legacy = profileJson('a')..remove('age');
      legacy['dob'] = '2005-06-11';
      expect(TrustScoreModel.fromJson(legacy).age, isNull);
      for (final invalid in [-1, 21.5, 'invalid']) {
        expect(
          TrustScoreModel.fromJson({...legacy, 'age': invalid}).age,
          isNull,
        );
      }
      expect(TrustScoreModel.fromJson({...legacy, 'age': 0}).age, 0);
    },
  );

  test(
    'late response for previous user cannot overwrite current profile',
    () async {
      final repo = PublicRepository();
      repo.pending['a'] = Completer<TrustScoreModel>();
      repo.pending['b'] = Completer<TrustScoreModel>();
      final vm = PublicProfileViewModel(repository: repo);
      addTearDown(vm.dispose);
      final a = vm.load('a');
      final b = vm.load('b');
      repo.pending['b']!.complete(TrustScoreModel.fromJson(profileJson('b')));
      await b;
      repo.pending['a']!.complete(TrustScoreModel.fromJson(profileJson('a')));
      await a;
      expect(vm.profile!.id, 'b');
    },
  );

  test('response after dispose does not notify or throw', () async {
    final repo = PublicRepository()
      ..pending['a'] = Completer<TrustScoreModel>();
    final vm = PublicProfileViewModel(repository: repo);
    final future = vm.load('a');
    vm.dispose();
    repo.pending['a']!.complete(TrustScoreModel.fromJson(profileJson('a')));
    await future;
  });

  test('mismatched user and invalid score are not displayed', () async {
    final repo = PublicRepository()..wrongId = 'someone-else';
    final vm = PublicProfileViewModel(repository: repo);
    addTearDown(vm.dispose);
    await vm.load('a');
    expect(vm.profile, isNull);
    repo.wrongId = null;
    repo.score = double.nan;
    await vm.load('a');
    expect(vm.profile, isNull);
  });

  testWidgets('public screen displays only safe profile fields on mobile', (
    tester,
  ) async {
    await mobile(tester, const PublicProfileScreen(userId: 'member-b'));
    expect(find.text('Tên member-b'), findsNWidgets(2));
    expect(find.text('Họ tên member-b'), findsOneWidget);
    expect(find.text('4.7/5'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Đã xác minh danh tính'), findsOneWidget);
    expect(find.text('Thích khám phá và đi bộ.'), findsOneWidget);
    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Biệt danh'), findsOneWidget);
    expect(find.text('21 tuổi'), findsOneWidget);
    for (final label in [
      'Số điện thoại',
      'Ngày sinh',
      'Giới tính',
      'Vai trò',
    ]) {
      expect(find.text(label), findsNothing);
    }
    expect(find.textContaining('PRIVATE_'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(requested, ['member-b']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old backend or missing birth date shows age as not updated', (
    tester,
  ) async {
    ApiClient.client.close();
    ApiClient.client = MockClient((request) async {
      final data = profileJson(request.url.pathSegments.last)..remove('age');
      return http.Response(
        jsonEncode({'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await mobile(tester, const PublicProfileScreen(userId: 'member-b'));
    expect(find.text('Độ tuổi'), findsOneWidget);
    expect(find.text('Chưa cập nhật'), findsOneWidget);
    expect(find.textContaining('PRIVATE_'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero reviews does not imply a bad 0/5 score', (tester) async {
    final repo = PublicRepository()
      ..count = 0
      ..score = 0;
    await mobile(
      tester,
      PublicProfileScreen(userId: 'new-user', repository: repo),
    );
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0.0/5'), findsNothing);
    expect(
      find.textContaining('Chưa có đánh giá bạn đồng hành.'),
      findsOneWidget,
    );
  });

  testWidgets('404 inactive or missing user has a clear error state', (
    tester,
  ) async {
    final repo = PublicRepository()..failure = 404;
    await mobile(tester, PublicProfileScreen(userId: 'gone', repository: repo));
    expect(find.text('Không tìm thấy người dùng'), findsOneWidget);
    expect(
      find.textContaining('tài khoản không còn hoạt động'),
      findsOneWidget,
    );
  });

  testWidgets(
    'failed load can be retried without falling back to signed-in user',
    (tester) async {
      final repo = PublicRepository()..failure = 500;
      await mobile(
        tester,
        PublicProfileScreen(userId: 'member-b', repository: repo),
      );
      expect(find.text('Chưa tải được hồ sơ'), findsOneWidget);
      repo.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Tên member-b'), findsNWidgets(2));
      expect(repo.calls, ['member-b', 'member-b']);
    },
  );

  testWidgets('refresh reloads current trust score and review count', (
    tester,
  ) async {
    final repo = PublicRepository();
    await mobile(
      tester,
      PublicProfileScreen(userId: 'member-b', repository: repo),
    );
    repo.count = 4;
    repo.score = 4.5;
    await tester.tap(find.byTooltip('Tải lại hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('4.5/5'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('reusing screen with another userId loads the new user', (
    tester,
  ) async {
    final repo = PublicRepository();
    await mobile(tester, PublicProfileScreen(userId: 'a', repository: repo));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: PublicProfileScreen(userId: 'b', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tên a'), findsNothing);
    expect(find.text('Tên b'), findsNWidgets(2));
  });

  testWidgets('named route accepts userId for teammates', (tester) async {
    final repo = PublicRepository();
    await mobile(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.publicProfile,
              arguments: {'userId': 'member-b', 'repository': repo},
            ),
            child: const Text('Open'),
          ),
        ),
      ),
      routes: true,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Tên member-b'), findsNWidgets(2));
    expect(repo.calls, ['member-b']);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('route without userId fails safely without API request', (
    tester,
  ) async {
    await mobile(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.publicProfile),
            child: const Text('Open'),
          ),
        ),
      ),
      routes: true,
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Thiếu mã người dùng (userId).'), findsOneWidget);
    expect(requested, isEmpty);
  });

  testWidgets('post member tap opens the selected member public profile', (
    tester,
  ) async {
    final auth = AuthViewModel();
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      AuthScope(
        auth: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: CompanionDetailScreen(
            postId: 'post-test',
            repository: PostRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.text('Thành viên B');
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(find.text('Tên member-b'), findsNWidgets(2));
    expect(requested, ['member-b']);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết bài đăng'), findsOneWidget);
  });

  testWidgets('post creator avatar opens creator and does not open post', (
    tester,
  ) async {
    var postOpens = 0;
    await mobile(
      tester,
      Scaffold(
        body: CompanionPostCard(post: postFixture(), onTap: () => postOpens++),
      ),
    );
    await tester.tap(find.byTooltip('Xem hồ sơ Trưởng nhóm'));
    await tester.pumpAndSettle();
    expect(find.text('Tên leader'), findsNWidgets(2));
    expect(requested, ['leader']);
    expect(postOpens, 0);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bài tuyển kiểm thử'));
    await tester.pumpAndSettle();
    expect(postOpens, 1);
  });

  testWidgets(
    'trip member tile supports profile without triggering moderation',
    (tester) async {
      var profileOpens = 0, removals = 0;
      await mobile(
        tester,
        Scaffold(
          body: TripMemberTile(
            member: const TripMember(
              userId: 'member-b',
              displayName: 'Thành viên B',
              role: 'MEMBER',
              membershipStatus: 'ACTIVE',
            ),
            onViewProfile: () => profileOpens++,
            onRemove: () => removals++,
          ),
        ),
      );
      await tester.tap(find.text('Thành viên B'));
      await tester.pumpAndSettle();
      expect(profileOpens, 1);
      expect(removals, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
