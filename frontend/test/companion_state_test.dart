import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:feeling_trip/features/companion/models/companion_post_model.dart';
import 'package:feeling_trip/features/companion/repositories/mock_companion_repository.dart';
import 'package:feeling_trip/features/companion/viewmodels/companion_detail_viewmodel.dart';
import 'package:feeling_trip/features/companion/views/companion_detail_screen.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

class ChangingRequestRepository extends MockCompanionRepository {
  String? state;
  bool missing = false, finished = false, cancelConflict = false;
  int sent = 0;
  @override
  Future<CompanionPost> getPostDetail(String id) async {
    if (missing) {
      throw ApiException(statusCode: 404, message: 'Bài đăng đã đóng');
    }
    return CompanionPost(
      id: id,
      title: 'Chuyến đi kiểm thử',
      content: 'Nội dung chuyến đi',
      targetMembersCount: 3,
      currentMembersCount: 1,
      createdAt: DateTime(2026, 10, 12),
      trip: TripInfo(
        id: 'trip-state',
        destination: 'Hà Nội',
        status: finished ? 'COMPLETED' : 'UPCOMING',
      ),
      creator: const CreatorInfo(id: 'other-user', fullName: 'Trưởng nhóm'),
      myRequestStatus: state,
      myRequestId: state == null ? null : 'request-state',
    );
  }

  @override
  Future<void> createJoinRequest({
    required String postId,
    String? introduction,
  }) async {
    sent++;
    state = 'ACCEPTED';
  }

  @override
  Future<void> deleteJoinRequest(String requestId) async {
    if (cancelConflict) {
      state = 'ACCEPTED';
      throw ApiException(statusCode: 409, message: 'Yêu cầu đã được xử lý');
    }
    state = null;
  }
}

void main() {
  test(
    'Display title removes only leading recruitment prefix without changing stored title',
    () {
      CompanionPost post(String? title) => CompanionPost.fromJson({
        'id': 'title-test',
        'title': title,
        'createdAt': '2026-10-14T10:00:00Z',
        'targetMembersCount': 4,
        'currentMembersCount': 1,
        'trip': {'id': 'trip', 'name': 'Chuyến đi Hà Nội'},
        'creator': {'id': 'leader'},
      });
      final existing = post('Tìm bạn đồng hành: Hàm Lợn');
      expect(existing.displayTitle, 'Hàm Lợn');
      expect(existing.title, 'Tìm bạn đồng hành: Hàm Lợn');
      expect(
        post('  TÌM BẠN ĐỒNG HÀNH: Chuyến đi Hà Nội  ').displayTitle,
        'Chuyến đi Hà Nội',
      );
      expect(
        post('Hẹn gặp bạn: Tìm bạn đồng hành').displayTitle,
        'Hẹn gặp bạn: Tìm bạn đồng hành',
      );
      expect(post(null).displayTitle, 'Chuyến đi Hà Nội');
    },
  );

  test(
    'Sending uses the latest accepted status and prevents duplicate submission',
    () async {
      final repo = ChangingRequestRepository();
      final vm = CompanionDetailViewModel(repository: repo);
      await vm.load('post-state');
      final result = await Future.wait([
        vm.sendJoinRequest(postId: 'post-state'),
        vm.sendJoinRequest(postId: 'post-state'),
      ]);
      expect(result, [true, false]);
      expect(repo.sent, 1);
      expect(vm.requestStatus, 'ACCEPTED');
      vm.dispose();
    },
  );
  test(
    'Reloading a closed post removes stale data and request status',
    () async {
      final repo = ChangingRequestRepository()..state = 'PENDING';
      final vm = CompanionDetailViewModel(repository: repo);
      await vm.load('post-state');
      expect(vm.post, isNotNull);
      repo.missing = true;
      await vm.load('post-state');
      expect(vm.post, isNull);
      expect(vm.requestStatus, isNull);
      expect(vm.errorMessage, 'Bài đăng đã đóng');
      vm.dispose();
    },
  );
  test('Cancellation racing approval refreshes the accepted state', () async {
    final repo = ChangingRequestRepository()
      ..state = 'PENDING'
      ..cancelConflict = true;
    final vm = CompanionDetailViewModel(repository: repo);
    await vm.load('post-state');
    expect(await vm.cancelRequest(), false);
    expect(vm.requestStatus, 'ACCEPTED');
    expect(vm.errorMessage, 'Yêu cầu đã được xử lý');
    vm.dispose();
  });
  testWidgets('Completed trips do not offer an enabled join button', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthViewModel();
    await tester.runAsync(
      () => auth.login('user.ekyc@feelingtrip.com', 'demo'),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      AuthScope(
        auth: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: CompanionDetailScreen(
            postId: 'post-state',
            repository: ChangingRequestRepository()..finished = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<CustomButton>(
      find.widgetWithText(CustomButton, 'Chuyến đi đã kết thúc hoặc đã huỷ'),
    );
    expect(button.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
