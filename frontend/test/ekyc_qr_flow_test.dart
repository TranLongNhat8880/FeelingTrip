import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:feeling_trip/core/network/api_client.dart';
import 'package:feeling_trip/core/network/storage_helper.dart';
import 'package:feeling_trip/features/auth/models/user_model.dart';
import 'package:feeling_trip/features/auth/repositories/auth_repository.dart';
import 'package:feeling_trip/features/auth/viewmodels/auth_viewmodel.dart';
import 'package:feeling_trip/features/profile/models/cccd_qr_model.dart';
import 'package:feeling_trip/features/profile/models/ekyc_check_status.dart';
import 'package:feeling_trip/features/profile/services/active_liveness_session.dart';
import 'package:feeling_trip/features/profile/services/cccd_ocr_service.dart';
import 'package:feeling_trip/features/profile/services/face_liveness_service.dart';
import 'package:feeling_trip/features/profile/viewmodels/ekyc_verification_viewmodel.dart';
import 'package:feeling_trip/features/profile/models/profile_model.dart';
import 'package:feeling_trip/features/profile/repositories/profile_repository.dart';
import 'package:feeling_trip/features/profile/viewmodels/profile_viewmodel.dart';
import 'package:feeling_trip/features/profile/views/ekyc_screen.dart';

class _FakeProfileRepository extends Fake implements ProfileRepository {
  bool verified = false,
      fail = false,
      loseResponse = false,
      legacyPending = false;
  Map<String, Object?>? submitted;
  @override
  Future<ProfileModel> getProfile() async => verified
      ? const ProfileModel(
          id: '00000000-0000-0000-0000-000000000001',
          email: 'test@feelingtrip.vn',
          role: 'USER',
          isEmailVerified: true,
          isVerified: true,
          verificationStatus: 'VERIFIED',
          hasEkycDocuments: true,
        )
      : _dummyProfile;

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
    submitted = {
      'sessionId': sessionId,
      'qrData': qrData,
      'video': livenessVideoBytes,
    };
    if (fail) throw Exception('Verification failed');
    verified = !legacyPending;
    if (loseResponse) throw TimeoutException('Committed but response lost');
  }
}

class _AuthRepository extends Fake implements AuthRepository {
  @override
  Future<({UserModel user, String token})> login(
    String email,
    String password,
  ) async => (
    user: UserModel(id: _dummyProfile.id, email: email),
    token:
        'test.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800})))}.test',
  );
}

http.Response _serverUser({bool verified = true, String? id}) => http.Response(
  jsonEncode({
    'success': true,
    'data': {
      'id': id ?? _dummyProfile.id,
      'email': _dummyProfile.email,
      'role': 'USER',
      'isVerified': verified,
      'verificationStatus': verified ? 'VERIFIED' : 'UNVERIFIED',
    },
  }),
  200,
);

final _image = base64Decode(
  'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
);

class _Picker extends ImagePicker {
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      XFile.fromData(_image, name: 'document.png', path: 'test-document.png');
}

class _Ocr extends CccdOcrService {
  @override
  Future<CccdOcrResult> recognizeFrontCard({
    required String imagePath,
    required CccdQrModel? qrData,
  }) async => const CccdOcrResult(
    status: EkycCheckStatus.passed,
    feedbackMessage: 'Local OCR passed',
  );
}

class _Portrait extends FaceLivenessService {
  @override
  Future<FaceLivenessResult> analyzeSelfie({
    required String imagePath,
    required Uint8List imageBytes,
    String? cccdFrontPath,
    Uint8List? cccdFrontBytes,
  }) async => const FaceLivenessResult(
    status: EkycCheckStatus.passed,
    faceCount: 1,
    message: 'Portrait quality passed',
  );
}

LivenessCapture _capture({bool withVideo = true}) {
  final session = ActiveLivenessSession(
    actions: [
      LivenessAction.blink,
      LivenessAction.turnLeft,
      LivenessAction.turnRight,
    ],
  );
  int ms = 0;
  void frames(int count, {double yaw = 0, double eye = .95}) {
    for (var i = 0; i < count; i++) {
      ms += 130;
      session.addFrame([
        LiveFaceSample(
          trackingId: 1,
          bounds: const Rect.fromLTWH(.3, .2, .4, .5),
          pitch: 0,
          yaw: yaw,
          roll: 0,
          leftEye: eye,
          rightEye: eye,
        ),
      ], Duration(milliseconds: ms));
    }
  }

  frames(5);
  frames(3);
  frames(2, eye: .05);
  frames(3);
  frames(4);
  frames(4, yaw: 30);
  frames(4);
  frames(4, yaw: -30);
  frames(4);
  return LivenessCapture(
    path: 'test-selfie.png',
    name: 'selfie.png',
    bytes: _image,
    evidence: session.evidence!,
    serverSessionId: withVideo ? '11111111-1111-4111-8111-111111111111' : null,
    videoBytes: withVideo ? Uint8List.fromList([1, 2, 3]) : null,
  );
}

Future<ProfileViewModel> _guided(
  WidgetTester tester,
  _FakeProfileRepository repository,
  LivenessCapture? capture, {
  AuthViewModel? auth,
}) async {
  final profile = ProfileViewModel(repository: repository);
  final app = MaterialApp(
    home: EkycScreen(
      viewModel: profile,
      initialProfile: _dummyProfile,
      verificationViewModel: EkycVerificationViewModel(
        ocr: _Ocr(),
        portrait: _Portrait(),
      ),
      imagePicker: _Picker(),
      scanQr: (_) async => CccdQrModel.parse(
        '001201012345||NGUYEN VAN TEST|15082001|Nam|Ha Noi|10112021',
      ),
      captureLiveness: (_) async => capture,
    ),
  );
  await tester.pumpWidget(
    auth == null ? app : AuthScope(auth: auth, child: app),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Bắt đầu xác minh eKYC'));
  await tester.tap(find.text('Bắt đầu xác minh eKYC'));
  await tester.pumpAndSettle();
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.text('Chụp ảnh ngay'));
    await tester.pumpAndSettle();
  }
  return profile;
}

const _dummyProfile = ProfileModel(
  id: '00000000-0000-0000-0000-000000000001',
  email: 'test@feelingtrip.vn',
  role: 'USER',
  isEmailVerified: true,
  isVerified: false,
  verificationStatus: 'UNVERIFIED',
  hasEkycDocuments: false,
  fullName: 'Nguyễn Văn Test',
);

void main() {
  final originalClient = ApiClient.client;
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    if (ApiClient.client != originalClient) ApiClient.client.close();
    ApiClient.client = originalClient;
  });

  testWidgets(
    'successful eKYC refreshes and persists the auth gate without logging in again',
    (tester) async {
      final auth = AuthViewModel(repository: _AuthRepository());
      addTearDown(auth.dispose);
      await auth.login(_dummyProfile.email, 'test');
      expect(auth.user?.hasVerifiedEkyc, isFalse);
      ApiClient.client = MockClient((_) async => _serverUser());
      await _guided(tester, _FakeProfileRepository(), _capture(), auth: auth);
      final button = find.text('Xác minh tự động');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(auth.user?.hasVerifiedEkyc, isTrue);
      expect((await StorageHelper.getSession())?.user.hasVerifiedEkyc, isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );

  test('a late refresh cannot restore a logged-out session', () async {
    final auth = AuthViewModel(repository: _AuthRepository());
    addTearDown(auth.dispose);
    await auth.login(_dummyProfile.email, 'test');
    final requested = Completer<void>();
    final response = Completer<http.Response>();
    ApiClient.client = MockClient((_) {
      requested.complete();
      return response.future;
    });
    final refresh = auth.refreshUser();
    await requested.future;
    await auth.logout();
    response.complete(_serverUser());
    expect(await refresh, isFalse);
    expect(auth.user, isNull);
    expect(await StorageHelper.getToken(), isNull);
  });

  test(
    'refresh never infers verification or accepts another account',
    () async {
      final auth = AuthViewModel(repository: _AuthRepository());
      addTearDown(auth.dispose);
      await auth.login(_dummyProfile.email, 'test');
      ApiClient.client = MockClient((_) async => _serverUser(verified: false));
      expect(await auth.refreshUser(), isTrue);
      expect(auth.user?.hasVerifiedEkyc, isFalse);
      ApiClient.client.close();
      ApiClient.client = MockClient(
        (_) async => _serverUser(id: 'another-user'),
      );
      expect(await auth.refreshUser(), isFalse);
      expect(auth.user?.hasVerifiedEkyc, isFalse);
      expect((await StorageHelper.getSession())?.user.id, _dummyProfile.id);
    },
  );

  testWidgets(
    'native guide sends the server session and video and refreshes verified profile',
    (tester) async {
      final repo = _FakeProfileRepository();
      final profile = await _guided(tester, repo, _capture());
      final button = find.text('Xác minh tự động');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(
        repo.submitted?['sessionId'],
        '11111111-1111-4111-8111-111111111111',
      );
      expect(repo.submitted?['video'], [1, 2, 3]);
      expect(repo.submitted?['qrData'], contains('001201012345'));
      expect(profile.profile?.isEkycVerified, isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
  testWidgets(
    'cancelled capture and quality-only selfie cannot enable automatic verification',
    (tester) async {
      for (final capture in [null, _capture(withVideo: false)]) {
        final repo = _FakeProfileRepository();
        await _guided(tester, repo, capture);
        final button = find.ancestor(
          of: find.text('Xác minh tự động'),
          matching: find.byType(ElevatedButton),
        );
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
        expect(repo.submitted, isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
  testWidgets(
    'failed verification invalidates consumed video and requires a new face capture',
    (tester) async {
      final repo = _FakeProfileRepository()..fail = true;
      final profile = await _guided(tester, repo, _capture());
      final button = find.text('Xác minh tự động');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(profile.profile?.isEkycVerified ?? false, isFalse);
      expect(
        tester
            .widget<ElevatedButton>(
              find.ancestor(of: button, matching: find.byType(ElevatedButton)),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({TargetPlatform.android}),
  );
  test(
    'a lost success response recovers the actual verified server profile',
    () async {
      final repo = _FakeProfileRepository()..loseResponse = true;
      final profile = ProfileViewModel(repository: repo);
      final success = await profile.submitEkyc(
        cccdNumber: '001201012345',
        frontImageBytes: _image,
        frontImageFileName: 'front.png',
        backImageBytes: _image,
        backImageFileName: 'back.png',
        selfieImageBytes: _image,
        selfieImageFileName: 'selfie.png',
        sessionId: 'test',
        qrData: 'test',
        livenessVideoBytes: [1, 2, 3],
      );
      expect(success, isTrue);
      expect(profile.profile?.isEkycVerified, isTrue);
    },
  );
  test(
    'an accepted upload without server verification is not approval',
    () async {
      final repo = _FakeProfileRepository()..legacyPending = true;
      final profile = ProfileViewModel(repository: repo);
      addTearDown(profile.dispose);
      expect(
        await profile.submitEkyc(
          cccdNumber: '001201012345',
          frontImageBytes: _image,
          frontImageFileName: 'front.png',
          backImageBytes: _image,
          backImageFileName: 'back.png',
          selfieImageBytes: _image,
          selfieImageFileName: 'selfie.png',
        ),
        isFalse,
      );
      expect(profile.profile?.isEkycVerified, isFalse);
      expect(profile.errorMessage, contains('chưa xác nhận'));
    },
  );
  testWidgets(
    'EkycScreen displays step-by-step intro and start verification button',
    (tester) async {
      final viewModel = ProfileViewModel(repository: _FakeProfileRepository());

      await tester.pumpWidget(
        MaterialApp(
          home: EkycScreen(viewModel: viewModel, initialProfile: _dummyProfile),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Nút Bắt đầu xác minh eKYC phải xuất hiện trên màn hình
      expect(find.text('Bắt đầu xác minh eKYC'), findsOneWidget);

      // 2. Các bước trong lộ trình 4 bước phải hiển thị rõ ràng
      expect(find.text('Bước 1: Quét mã QR thẻ CCCD'), findsOneWidget);
      expect(find.text('Bước 2: Chụp mặt trước thẻ CCCD'), findsOneWidget);
      expect(find.text('Bước 3: Chụp mặt sau thẻ CCCD'), findsOneWidget);
      expect(find.text('Bước 4: Chụp ảnh chân dung chính chủ'), findsOneWidget);

      // 3. Hoàn toàn không còn ô nhập text thủ công cho số CCCD
      expect(find.byType(TextFormField), findsNothing);
    },
  );
}
