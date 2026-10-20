import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../shared/ui_kit.dart';
import '../../../core/network/api_client.dart';
import '../services/active_liveness_session.dart';
import '../services/cccd_ocr_service.dart';
import '../services/liveness_frame_converter.dart';
import '../services/liveness_file_cleanup.dart';
import '../models/identity_session.dart';
import '../repositories/api_profile_repository.dart';

class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({
    super.key,
    this.cameraProvider,
    this.cameraFactory,
    this.detectorFactory,
    this.sessionProvider,
  });
  final Future<List<CameraDescription>> Function()? cameraProvider;
  final CameraController Function(CameraDescription)? cameraFactory;
  final FaceDetector Function()? detectorFactory;
  final Future<IdentitySession> Function()? sessionProvider;
  static Future<LivenessCapture?> show(BuildContext context) =>
      Navigator.of(context).push<LivenessCapture>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const FaceLivenessScreen(),
        ),
      );
  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  FaceDetector? _detector;
  ActiveLivenessSession _session = ActiveLivenessSession();
  final _clock = Stopwatch();
  Timer? _timer;
  Future<void> _cameraWork = Future.value();
  Future<void>? _frameWork;
  bool _foreground = true, _closing = false, _disposed = false, _canPop = false;
  bool _processing = false, _captureQueued = false;
  int _generation = 0, _lastFrameMillis = -1000;
  String? _error;
  IdentitySession? _serverSession;
  bool get _wantCamera => !_closing && !_disposed && _foreground;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    unawaited(_queue(_start));
  }

  Future<void> _queue(
    Future<void> Function() task,
  ) => _cameraWork = _cameraWork.then((_) async {
    try {
      await task();
    } catch (error) {
      await _release();
      if (mounted && _wantCamera) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : error is CameraException && error.code.contains('Access')
              ? 'Chưa có quyền camera. Cho phép truy cập camera trong cài đặt rồi thử lại.'
              : 'Không mở được camera hoặc bộ nhận diện. Vui lòng thử lại trên Android/iOS.',
        );
      }
    }
  });

  Future<void> _start() async {
    if (!_wantCamera || _camera != null) return;
    if (!CccdOcrService.isSupported) {
      if (mounted) {
        setState(
          () => _error =
              'Liveness trực tiếp hiện hỗ trợ ứng dụng Android/iOS. Trình duyệt chưa được kiểm tra liveness.',
        );
      }
      return;
    }
    final token = _generation;
    final cameras = await (widget.cameraProvider ?? availableCameras)();
    if (!_wantCamera || token != _generation) return;
    final fronts = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    if (fronts.isEmpty) {
      setState(() => _error = 'Không tìm thấy camera trước.');
      return;
    }
    final camera =
        widget.cameraFactory?.call(fronts.first) ??
        CameraController(
          fronts.first,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        );
    _camera = camera;
    try {
      await camera.initialize();
      if (!_wantCamera || token != _generation) {
        await _release();
        return;
      }
      final session =
          await (widget.sessionProvider ??
              ApiProfileRepository().createIdentitySession)();
      if (!_wantCamera || token != _generation) {
        await _release();
        return;
      }
      _serverSession = session;
      _detector =
          widget.detectorFactory?.call() ??
          FaceDetector(
            options: FaceDetectorOptions(
              performanceMode: FaceDetectorMode.accurate,
              enableClassification: true,
              enableTracking: true,
              minFaceSize: .1,
            ),
          );
      _session = ActiveLivenessSession(
        mirrored: defaultTargetPlatform == TargetPlatform.iOS,
        actions: session.actions
            .map((action) => LivenessAction.values.byName(action))
            .toList(),
      );
      _captureQueued = false;
      _lastFrameMillis = -1000;
      _clock
        ..reset()
        ..start();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || !_wantCamera) return;
        setState(() => _session.tick(_clock.elapsed));
        if (_session.stage == LivenessStage.expired) {
          _timer?.cancel();
          unawaited(_queue(_release));
        }
      });
      await camera.startVideoRecording(
        onAvailable: _onFrame,
        enablePersistentRecording: false,
      );
      if (mounted && _wantCamera) setState(() => _error = null);
    } catch (_) {
      await _release();
      rethrow;
    }
  }

  void _onFrame(CameraImage image) {
    if (!_wantCamera ||
        _processing ||
        _captureQueued ||
        _session.stage == LivenessStage.expired ||
        _clock.elapsedMilliseconds - _lastFrameMillis < 120) {
      return;
    }
    _processing = true;
    _lastFrameMillis = _clock.elapsedMilliseconds;
    _frameWork = _processFrame(image, _generation);
  }

  Future<void> _processFrame(CameraImage image, int token) async {
    try {
      final camera = _camera, detector = _detector;
      if (camera == null || detector == null) return;
      final frame = LivenessFrameConverter.convert(
        image,
        camera.description,
        camera.value.deviceOrientation,
      );
      if (frame == null) throw StateError('Unsupported camera frame');
      final faces = await detector.processImage(frame.image);
      if (!_wantCamera || token != _generation) return;
      final size = frame.uprightSize;
      final previousStage = _session.stage;
      _session.addFrame([
        for (final face in faces)
          LiveFaceSample(
            trackingId: face.trackingId,
            bounds: Rect.fromLTRB(
              face.boundingBox.left / size.width,
              face.boundingBox.top / size.height,
              face.boundingBox.right / size.width,
              face.boundingBox.bottom / size.height,
            ),
            pitch: face.headEulerAngleX,
            yaw: face.headEulerAngleY,
            roll: face.headEulerAngleZ,
            leftEye: face.leftEyeOpenProbability,
            rightEye: face.rightEyeOpenProbability,
          ),
      ], _clock.elapsed);
      if (previousStage != LivenessStage.align &&
          _session.stage == LivenessStage.align) {
        throw StateError('Capture continuity lost');
      }
      if (mounted) setState(() {});
      if (_session.evidence != null && !_captureQueued) {
        _captureQueued = true;
        _timer?.cancel();
        unawaited(_queue(() => _capture(token)));
      }
    } catch (_) {
      if (mounted && _wantCamera && token == _generation) {
        setState(
          () => _error =
              'Luồng khuôn mặt bị gián đoạn hoặc chưa đọc rõ. Bấm thử lại để quay video mới.',
        );
        _generation++;
        unawaited(_queue(_release));
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _capture(int token) async {
    final camera = _camera, evidence = _session.evidence;
    if (!_wantCamera ||
        token != _generation ||
        camera == null ||
        evidence == null) {
      return;
    }
    if (!camera.value.isRecordingVideo || _serverSession == null) {
      throw StateError('Missing video evidence');
    }
    final video = await camera.stopVideoRecording();
    Uint8List videoBytes;
    try {
      if (await video.length() > 20 * 1024 * 1024) {
        throw StateError('Video too large');
      }
      videoBytes = await video.readAsBytes();
    } finally {
      await deleteLivenessVideo(video.path);
    }
    if (videoBytes.isEmpty) throw StateError('Empty video');
    final file = await camera.takePicture();
    final bytes = await file.readAsBytes();
    if (!_wantCamera || token != _generation) return;
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw StateError('Invalid capture size');
    }
    final capture = LivenessCapture(
      path: file.path,
      name: file.name,
      bytes: bytes,
      evidence: evidence,
      serverSessionId: _serverSession!.id,
      videoBytes: videoBytes,
    );
    // Queue the close after this capture to avoid waiting on our own queue.
    unawaited(_close(capture));
  }

  Future<void> _release() async {
    _timer?.cancel();
    _clock.stop();
    final camera = _camera;
    _camera = null;
    if (mounted && !_closing) setState(() {});
    if (camera != null) {
      try {
        if (camera.value.isRecordingVideo) {
          final video = await camera.stopVideoRecording();
          await deleteLivenessVideo(video.path);
        } else if (camera.value.isStreamingImages) {
          await camera.stopImageStream();
        }
      } catch (_) {}
    }
    try {
      await _frameWork;
    } catch (_) {}
    if (camera != null) {
      try {
        await camera.dispose();
      } catch (_) {}
    }
    final detector = _detector;
    _detector = null;
    if (detector != null) {
      try {
        await detector.close();
      } catch (_) {}
    }
  }

  Future<void> _close(LivenessCapture? result) async {
    if (_closing) return;
    _closing = true;
    _generation++;
    _timer?.cancel();
    await _queue(() async {
      await _release();
      if (mounted) {
        setState(() => _canPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) Navigator.of(context).pop(result);
      }
    });
  }

  Future<void> _retry() async {
    if (_closing) return;
    _generation++;
    setState(() {
      _error = null;
      _session = ActiveLivenessSession();
    });
    await _queue(() async {
      await _release();
      await _start();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _generation++;
      _timer?.cancel();
      _session = ActiveLivenessSession();
      unawaited(_queue(_release));
    } else if (!_closing) {
      unawaited(_queue(_start));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_queue(_release));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final expired = _session.stage == LivenessStage.expired;
    return PopScope<LivenessCapture>(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close(null));
      },
      child: AppScaffold(
        title: 'Kiểm tra liveness',
        showBack: false,
        showKoharu: false,
        actions: [
          IconButton(
            tooltip: 'Đóng camera',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _close(null),
          ),
        ],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: ColoredBox(
                  color: Colors.black,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (camera != null && camera.value.isInitialized)
                        Center(child: CameraPreview(camera))
                      else if (_error == null && !expired)
                        const Center(child: CircularProgressIndicator()),
                      IgnorePointer(
                        child: LayoutBuilder(
                          builder: (_, constraints) => Center(
                            child: Container(
                              width: constraints.maxWidth * .72,
                              height: constraints.maxHeight * .78,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(200),
                                border: Border.all(
                                  color: Colors.white70,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_error != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error == null ? _session.instruction : 'Chưa hoàn tất liveness',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: _session.progress),
            const SizedBox(height: 8),
            Text(
              '${_session.completedActions}/${_session.actionCount} thao tác • ${_session.secondsRemaining}s',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Video được gửi cùng hồ sơ để server kiểm tra liveness và đối chiếu khuôn mặt với CCCD.',
              textAlign: TextAlign.center,
            ),
            if (_error != null || expired) ...[
              const SizedBox(height: 12),
              CustomButton(text: 'Thử lại', onPressed: _retry),
            ],
          ],
        ),
      ),
    );
  }
}
