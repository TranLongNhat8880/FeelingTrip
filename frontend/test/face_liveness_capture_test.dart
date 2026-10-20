import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:feeling_trip/features/profile/models/identity_session.dart';
import 'package:feeling_trip/features/profile/services/active_liveness_session.dart';
import 'package:feeling_trip/features/profile/views/face_liveness_screen.dart';

const _description = CameraDescription(
  name: 'front',
  lensDirection: CameraLensDirection.front,
  sensorOrientation: 90,
);

class _Camera extends CameraController {
  _Camera({this.initialization})
    : super(_description, ResolutionPreset.medium, enableAudio: false);
  final Completer<void>? initialization;
  bool released = false;
  int recorded = 0, stopped = 0, pictures = 0;
  void Function(CameraImage)? frame;
  @override
  Future<void> initialize() async {
    await initialization?.future;
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(640, 480),
    );
  }

  @override
  Future<void> startVideoRecording({
    void Function(CameraImage)? onAvailable,
    bool enablePersistentRecording = true,
  }) async {
    expect(enablePersistentRecording, isFalse);
    recorded++;
    frame = onAvailable;
    value = const CameraValue(
      isInitialized: true,
      isRecordingVideo: true,
      isTakingPicture: false,
      isStreamingImages: true,
      isRecordingPaused: false,
      flashMode: FlashMode.auto,
      exposureMode: ExposureMode.auto,
      focusMode: FocusMode.auto,
      exposurePointSupported: false,
      focusPointSupported: false,
      deviceOrientation: DeviceOrientation.portraitUp,
      description: _description,
      previewSize: Size(640, 480),
      recordingOrientation: DeviceOrientation.portraitUp,
    );
  }

  @override
  Future<XFile> stopVideoRecording() async {
    stopped++;
    value = value.copyWith(isRecordingVideo: false, isStreamingImages: false);
    return XFile.fromData(
      Uint8List.fromList([1, 2, 3]),
      name: 'test.mp4',
      path: '__identity_test_owned_video__.mp4',
    );
  }

  @override
  Future<XFile> takePicture() async {
    pictures++;
    return XFile.fromData(
      Uint8List.fromList([4, 5, 6]),
      name: 'selfie.jpg',
      path: 'test-selfie.jpg',
    );
  }

  @override
  Widget buildPreview() => const SizedBox.expand();
  @override
  Future<void> dispose() async {
    released = true;
    await super.dispose();
  }
}

class _Detector extends FaceDetector {
  _Detector() : super(options: FaceDetectorOptions(enableTracking: true));
  bool released = false;
  double yaw = 0, eye = .95;
  Completer<List<Face>>? pending;
  @override
  Future<List<Face>> processImage(InputImage image) async =>
      pending?.future ??
      [
        Face(
          boundingBox: const Rect.fromLTWH(.6, .8, .8, 2),
          landmarks: {},
          contours: {},
          trackingId: 1,
          headEulerAngleX: 0,
          headEulerAngleY: yaw,
          headEulerAngleZ: 0,
          leftEyeOpenProbability: eye,
          rightEyeOpenProbability: eye,
        ),
      ];
  @override
  Future<void> close() async {
    released = true;
  }
}

// Camera platform test data; this fixture deliberately has no usable portrait.
// Camera's public package does not re-export the replacement platform DTO.
// ignore: deprecated_member_use
CameraImage _frame() => CameraImage.fromPlatformData({
  'format': 17,
  'width': 4,
  'height': 2,
  'planes': [
    {'bytes': Uint8List(12), 'bytesPerRow': 4, 'bytesPerPixel': 1},
  ],
});
IdentitySession _session() => IdentitySession(
  id: '11111111-1111-4111-8111-111111111111',
  actions: ['blink', 'turnLeft', 'turnRight'],
  expiresAt: DateTime.now().add(const Duration(minutes: 5)),
);

Future<void> _mount(
  WidgetTester tester, {
  required _Camera Function() camera,
  required _Detector Function() detector,
  Future<IdentitySession> Function()? session,
  void Function(LivenessCapture?)? result,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final capture = await Navigator.of(context).push<LivenessCapture>(
                MaterialPageRoute(
                  builder: (_) => FaceLivenessScreen(
                    cameraProvider: () async => [_description],
                    cameraFactory: (_) => camera(),
                    detectorFactory: detector,
                    sessionProvider: session ?? () async => _session(),
                  ),
                ),
              );
              result?.call(capture);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test(
    'mirrored streams swap only the human turn instruction, not server action IDs',
    () {
      for (final mirrored in [false, true]) {
        final session = ActiveLivenessSession(
          mirrored: mirrored,
          actions: [
            LivenessAction.turnLeft,
            LivenessAction.blink,
            LivenessAction.turnRight,
          ],
        );
        for (var i = 1; i <= 5; i++) {
          session.addFrame([
            const LiveFaceSample(
              trackingId: 1,
              bounds: Rect.fromLTWH(.3, .2, .4, .5),
              pitch: 0,
              yaw: 0,
              roll: 0,
              leftEye: .95,
              rightEye: .95,
            ),
          ], Duration(milliseconds: i * 130));
        }
        expect(session.currentAction, LivenessAction.turnLeft);
        expect(
          session.instruction,
          mirrored
              ? LivenessAction.turnRight.instruction
              : LivenessAction.turnLeft.instruction,
        );
      }
    },
  );
  final android = TargetPlatformVariant({TargetPlatform.android});
  testWidgets('closing discards video and releases camera and detector', (
    tester,
  ) async {
    final camera = _Camera();
    final detector = _Detector();
    await _mount(tester, camera: () => camera, detector: () => detector);
    expect(camera.recorded, 1);
    expect(camera.enableAudio, isFalse);
    await tester.tap(find.byTooltip('Đóng camera'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(camera.stopped, 1);
    expect(camera.released, isTrue);
    expect(detector.released, isTrue);
    expect(camera.pictures, 0);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, variant: android);
  testWidgets(
    'late permission initialization cannot create a session after close',
    (tester) async {
      final init = Completer<void>();
      final camera = _Camera(initialization: init);
      var sessions = 0;
      await _mount(
        tester,
        camera: () => camera,
        detector: () => _Detector(),
        session: () async {
          sessions++;
          return _session();
        },
      );
      await tester.tap(find.byTooltip('Đóng camera'));
      await tester.pump();
      init.complete();
      await tester.pumpAndSettle();
      expect(camera.released, isTrue);
      expect(camera.recorded, 0);
      expect(sessions, 0);
      expect(tester.takeException(), isNull);
    },
    variant: android,
  );
  testWidgets(
    'background discards recording and resume obtains a fresh server session',
    (tester) async {
      final cameras = <_Camera>[];
      var sessions = 0;
      await _mount(
        tester,
        camera: () {
          final c = _Camera();
          cameras.add(c);
          return c;
        },
        detector: () => _Detector(),
        session: () async {
          sessions++;
          return _session();
        },
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pump();
      expect(cameras.first.released, isTrue);
      expect(cameras.first.stopped, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(cameras.length, 2);
      expect(sessions, 2);
      await tester.tap(find.byTooltip('Đóng camera'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: android,
  );
  testWidgets(
    'detector is not disposed while a native frame is still in flight',
    (tester) async {
      final camera = _Camera();
      final detector = _Detector()..pending = Completer<List<Face>>();
      await _mount(tester, camera: () => camera, detector: () => detector);
      camera.frame!(_frame());
      await tester.pump();
      await tester.tap(find.byTooltip('Đóng camera'));
      await tester.pump();
      expect(detector.released, isFalse);
      detector.pending!.complete([]);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(detector.released, isTrue);
      expect(camera.released, isTrue);
    },
    variant: android,
  );
  testWidgets(
    'completed motions return one snapshot plus server-bound video and close the camera',
    (tester) async {
      final camera = _Camera();
      final detector = _Detector();
      LivenessCapture? capture;
      await _mount(
        tester,
        camera: () => camera,
        detector: () => detector,
        result: (value) => capture = value,
      );
      for (var i = 0; i < 100 && camera.pictures == 0; i++) {
        detector.yaw =
            find.text('Quay đầu chậm sang trái').evaluate().isNotEmpty
            ? 30
            : find.text('Quay đầu chậm sang phải').evaluate().isNotEmpty
            ? -30
            : 0;
        detector.eye =
            find.text('Nhắm cả hai mắt khoảng nửa giây').evaluate().isNotEmpty
            ? .05
            : .95;
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 140));
          camera.frame!(_frame());
          await Future<void>.delayed(Duration.zero);
        });
        await tester.pump();
      }
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(camera.pictures, 1);
      expect(camera.stopped, 1);
      expect(camera.released, isTrue);
      expect(detector.released, isTrue);
      expect(capture?.serverSessionId, _session().id);
      expect(capture?.videoBytes, [1, 2, 3]);
      expect(capture?.bytes, [4, 5, 6]);
      expect(capture?.evidence.actions.length, 3);
      expect(tester.takeException(), isNull);
    },
    variant: android,
  );
}
