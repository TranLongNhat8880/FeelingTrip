import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/theme/app_theme.dart';
import 'package:feeling_trip/features/profile/models/profile_model.dart';
import 'package:feeling_trip/features/profile/repositories/api_profile_repository.dart';
import 'package:feeling_trip/features/profile/repositories/profile_repository.dart';
import 'package:feeling_trip/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:feeling_trip/features/profile/views/ekyc_screen.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lboAAAAASUVORK5CYII=',
);
ProfileModel profile(String status, {String? reason}) => ProfileModel(
  id: 'user',
  email: 'test@example.com',
  fullName: 'Test User',
  role: 'USER',
  isEmailVerified: true,
  isVerified: status == 'VERIFIED',
  verificationStatus: status,
  hasEkycDocuments: status == 'PENDING',
  verificationRejectionReason: reason,
);

class ManualRepository extends Fake implements ProfileRepository {
  bool submitted = false, lostResponse = false, rejectUpload = false;
  Map<String, Object?>? payload;
  String state = 'UNVERIFIED';
  @override
  Future<ProfileModel> getProfile() async =>
      profile(submitted ? 'PENDING' : state);
  @override
  Future<void> submitEkyc({
    required String cccdNumber,
    required List<int> frontImageBytes,
    required String frontImageFileName,
    required List<int> backImageBytes,
    required String backImageFileName,
    required List<int> selfieImageBytes,
    required String selfieImageFileName,
    String? sessionId,
    String? qrData,
    List<int>? livenessVideoBytes,
  }) async {
    payload = {
      'number': cccdNumber,
      'session': sessionId,
      'video': livenessVideoBytes,
    };
    if (rejectUpload) throw Exception('Upload failed');
    submitted = true;
    if (lostResponse) throw Exception('Response lost after commit');
  }
}

class Picker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => XFile.fromData(png, name: 'document.png', path: 'document.png');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader('BeVietnamPro')
      ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Bold.ttf'));
    await fonts.load();
  });
  late http.Client original;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    original = ApiClient.client;
  });
  tearDown(() => ApiClient.client = original);

  test(
    'manual API sends only number and three photos to the manual endpoint',
    () async {
      ApiClient.client = MockClient((request) async {
        expect(request.url.path, endsWith('/users/ekyc-submit'));
        final body = latin1.decode(request.bodyBytes);
        for (final name in [
          'cccdNumber',
          'cccdFrontImage',
          'cccdBackImage',
          'selfieImage',
        ]) {
          expect(body, contains('name="$name"'));
        }
        expect(body, isNot(contains('name="sessionId"')));
        expect(body, isNot(contains('name="livenessVideo"')));
        return http.Response('{"success":true}', 200);
      });
      await ApiProfileRepository().submitEkyc(
        cccdNumber: '001201012345',
        frontImageBytes: png,
        frontImageFileName: 'front.png',
        backImageBytes: png,
        backImageFileName: 'back.png',
        selfieImageBytes: png,
        selfieImageFileName: 'selfie.png',
      );
    },
  );

  test(
    'manual pending is accepted without treating it as verified, including a lost response',
    () async {
      for (final lost in [false, true]) {
        final repo = ManualRepository()..lostResponse = lost;
        final vm = ProfileViewModel(repository: repo);
        expect(
          await vm.submitEkyc(
            cccdNumber: '001201012345',
            frontImageBytes: png,
            frontImageFileName: 'front.png',
            backImageBytes: png,
            backImageFileName: 'back.png',
            selfieImageBytes: png,
            selfieImageFileName: 'selfie.png',
          ),
          true,
        );
        expect(vm.profile!.isEkycPending, true);
        expect(vm.profile!.isEkycVerified, false);
        vm.dispose();
      }
    },
  );

  test('pending profiles cannot resubmit; rejected profiles can', () {
    expect(profile('PENDING').canSubmitEkyc, false);
    expect(profile('VERIFIED').canSubmitEkyc, false);
    expect(profile('REJECTED').canSubmitEkyc, true);
    expect(profile('UNVERIFIED').canSubmitEkyc, true);
  });

  Future<ProfileViewModel> mount(
    WidgetTester tester,
    ManualRepository repo,
    ProfileModel initial, {
    bool preview = false,
  }) async {
    tester.view.physicalSize = Size(390, preview ? 1450 : 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = ProfileViewModel(repository: repo);
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: RepaintBoundary(
          key: const Key('manual-preview'),
          child: EkycScreen(
            viewModel: vm,
            initialProfile: initial,
            imagePicker: Picker(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  testWidgets(
    'manual form works on desktop and submits without AI session or video',
    (tester) async {
      final repo = ManualRepository();
      final vm = await mount(tester, repo, profile('UNVERIFIED'));
      expect(find.text('Xác minh tự động'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '001201012345');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      for (final label in [
        'Thêm mặt trước CCCD',
        'Thêm mặt sau CCCD',
        'Thêm ảnh chân dung',
      ]) {
        final button = find.text(label);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chọn từ thư viện'));
        await tester.pumpAndSettle();
        expect(find.text('Chọn lại ảnh'), findsAtLeastNWidgets(1));
      }
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        true,
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '001201012345',
      );
      await tester.ensureVisible(find.text('Gửi hồ sơ xét duyệt'));
      await tester.tap(find.text('Gửi hồ sơ xét duyệt'));
      await tester.pumpAndSettle();
      expect(repo.payload, {
        'number': '001201012345',
        'session': null,
        'video': null,
      });
      expect(vm.profile!.isEkycPending, true);
      expect(find.text('Đã gửi hồ sơ thành công'), findsOneWidget);
      expect(find.text('Gửi hồ sơ xét duyệt'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending screen explains review and rejection screen shows reason with resubmit form',
    (tester) async {
      await mount(tester, ManualRepository(), profile('PENDING'));
      expect(find.text('Hồ sơ đang chờ xét duyệt'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await mount(
        tester,
        ManualRepository(),
        profile('REJECTED', reason: 'Mặt sau bị mờ'),
      );
      expect(find.textContaining('Mặt sau bị mờ'), findsOneWidget);
      expect(find.text('Bổ sung hồ sơ xác minh'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    },
  );

  testWidgets(
    'manual verification layout has no overflow and renders a preview',
    (tester) async {
      await mount(
        tester,
        ManualRepository(),
        profile('UNVERIFIED'),
        preview: true,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('manual-preview')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../backend/.tmp/manual-ekyc-preview.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    },
  );
}
