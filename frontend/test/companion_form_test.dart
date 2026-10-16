import 'package:feeling_trip/shared/inputs/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feeling_trip/features/companion/models/companion_post_model.dart';
import 'package:feeling_trip/features/companion/repositories/companion_trip_repository.dart';
import 'package:feeling_trip/features/companion/repositories/mock_companion_repository.dart';
import 'package:feeling_trip/features/companion/views/create_companion_post_screen.dart';
import 'package:feeling_trip/features/companion/views/widgets/companion_post_card.dart';

class _Trips extends CompanionTripRepository {
  _Trips({this.image = ''});
  final String image;
  @override
  Future<bool> hasPostForTrip(String id) async => false;
  @override
  Future<Map<String, String>> getTrip(String id) async => {
    'privacyType': 'PUBLIC',
    'memberCount': '3',
    'image': image,
  };
}

CompanionPost _post({int members = 1, int target = 5}) => CompanionPost(
  id: 'post',
  title: 'Đi Hà Nội',
  content: 'Cùng đi Hà Nội nhé',
  targetMembersCount: target,
  currentMembersCount: members,
  createdAt: DateTime(2026, 10, 16),
  trip: const TripInfo(id: 'trip'),
  creator: const CreatorInfo(id: '', fullName: 'Tùng'),
);

class _Posts extends MockCompanionRepository {
  Map<String, dynamic>? submitted;
  @override
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
  }) async {
    submitted = {
      'title': title,
      'recruitmentCount': recruitmentCount,
      'minAge': minAge,
      'maxAge': maxAge,
      'genderPreference': genderPreference,
      'tags': tags,
    };
    return _post();
  }

  @override
  Future<void> updatePost(String id, Map<String, dynamic> data) async {
    submitted = data;
  }
}

Finder field(String label) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is CustomTextField && widget.label == label,
  ),
  matching: find.byType(TextFormField),
);

Future<void> _pumpForm(
  WidgetTester tester,
  _Posts posts, {
  CompanionPost? post,
  String image = '',
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: CreateCompanionPostScreen(
        repository: posts,
        tripRepository: _Trips(image: image),
        tripId: 'trip',
        tripName: 'Chuyến đi Hà Nội',
        post: post,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'new form has blank title, hidden optional controls, no substitute trip icon, and recruits additional people',
    (tester) async {
      final posts = _Posts();
      await _pumpForm(tester, posts);
      expect(
        tester
            .widget<TextFormField>(field('Tiêu đề bài đăng *'))
            .controller!
            .text,
        '',
      );
      expect(find.byIcon(Icons.luggage_rounded), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is NetworkImage,
        ),
        findsNothing,
      );
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
      expect(find.text('Nhóm hiện có 3 thành viên'), findsOneWidget);
      await tester.enterText(field('Tiêu đề bài đăng *'), 'Cùng đi Hà Nội');
      await tester.enterText(field('Lời nhắn *'), 'abc');
      await tester.tap(find.text('Đăng bài').last);
      await tester.pumpAndSettle();
      expect(posts.submitted?['recruitmentCount'], 1);
      expect(posts.submitted?['minAge'], null);
      expect(posts.submitted?['maxAge'], null);
      expect(posts.submitted?['genderPreference'], 'ANY');
      expect(posts.submitted?['tags'], isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('preferences open on tap and can be cleared when editing', (
    tester,
  ) async {
    final posts = _Posts();
    final old = CompanionPost(
      id: 'post',
      title: 'Cùng đi Hà Nội',
      content: 'Cùng đi Hà Nội nhé',
      targetMembersCount: 5,
      currentMembersCount: 2,
      minAge: 18,
      maxAge: 35,
      genderPreference: 'MALE',
      tags: const ['Phượt'],
      createdAt: DateTime(2026),
      trip: const TripInfo(id: 'trip'),
      creator: const CreatorInfo(id: 'leader'),
    );
    await _pumpForm(tester, posts, post: old);
    final ages = find.text('Yêu cầu độ tuổi');
    await tester.ensureVisible(ages);
    await tester.tap(ages);
    await tester.pumpAndSettle();
    await tester.ensureVisible(field('Từ tuổi'));
    await tester.enterText(field('Từ tuổi'), '');
    await tester.ensureVisible(field('Đến tuổi'));
    await tester.enterText(field('Đến tuổi'), '');
    await tester.ensureVisible(find.text('Chủ đề chuyến đi'));
    await tester.tap(find.text('Chủ đề chuyến đi'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Phượt'));
    await tester.tap(find.widgetWithText(FilterChip, 'Phượt'));
    await tester.ensureVisible(find.text('Ưu tiên giới tính'));
    await tester.tap(find.text('Ưu tiên giới tính'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Bất kỳ'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bất kỳ'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(posts.submitted?['recruitmentCount'], 3);
    expect(posts.submitted?['minAge'], null);
    expect(posts.submitted?['maxAge'], null);
    expect(posts.submitted?['tags'], null);
    expect(posts.submitted?['genderPreference'], 'ANY');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'age inputs exclude signs and show range and ordering errors; gender chips align left',
    (tester) async {
      await _pumpForm(tester, _Posts());
      await tester.ensureVisible(find.text('Ưu tiên giới tính'));
      await tester.tap(find.text('Ưu tiên giới tính'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.widgetWithText(ChoiceChip, 'Bất kỳ')).dx,
        16,
      );
      await tester.ensureVisible(find.text('Yêu cầu độ tuổi'));
      await tester.tap(find.text('Yêu cầu độ tuổi'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('Từ tuổi'));
      await tester.enterText(field('Từ tuổi'), '-1');
      await tester.pump();
      expect(
        tester.widget<TextFormField>(field('Từ tuổi')).controller!.text,
        '1',
      );
      expect(find.text('Nhập tuổi từ 16 đến 100'), findsOneWidget);
      await tester.enterText(field('Từ tuổi'), '20');
      await tester.ensureVisible(field('Đến tuổi'));
      await tester.enterText(field('Đến tuổi'), '4');
      await tester.pump();
      expect(find.text('Cần kiểm tra độ tuổi'), findsOneWidget);
      await tester.enterText(field('Đến tuổi'), '18');
      await tester.pump();
      expect(find.text('Tuổi tối đa phải từ 20 trở lên'), findsOneWidget);
      await tester.enterText(field('Đến tuổi'), '40');
      await tester.pump();
      expect(find.text('20 – 40'), findsOneWidget);
      expect(find.text('Cần kiểm tra độ tuổi'), findsNothing);
    },
  );

  testWidgets('feed badge shows current members over total capacity', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CompanionPostCard(post: _post())),
      ),
    );
    expect(find.text('1/5 thành viên'), findsOneWidget);
    expect(find.text('Còn 4 chỗ'), findsNothing);
  });
}
