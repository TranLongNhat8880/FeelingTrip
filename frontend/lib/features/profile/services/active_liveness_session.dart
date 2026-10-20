import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

enum LivenessAction { blink, turnLeft, turnRight }

enum LivenessStage { align, perform, returnToCenter, complete, expired }

extension LivenessActionLabel on LivenessAction {
  String get instruction => switch (this) {
    LivenessAction.blink => 'Nhắm cả hai mắt rồi mở lại',
    LivenessAction.turnLeft => 'Quay đầu chậm sang trái',
    LivenessAction.turnRight => 'Quay đầu chậm sang phải',
  };
}

/// Local challenge evidence, not a server-verifiable identity or PAD certificate.
class LivenessEvidence {
  LivenessEvidence._(this.sessionId, List<LivenessAction> actions, this.elapsed)
    : actions = List.unmodifiable(actions);
  final String sessionId;
  final List<LivenessAction> actions;
  final Duration elapsed;
}

class LivenessCapture {
  const LivenessCapture({
    required this.path,
    required this.name,
    required this.bytes,
    required this.evidence,
    this.serverSessionId,
    this.videoBytes,
  });
  final String path;
  final String name;
  final Uint8List bytes;
  final LivenessEvidence evidence;
  final String? serverSessionId;
  final Uint8List? videoBytes;
}

class LiveFaceSample {
  const LiveFaceSample({
    required this.trackingId,
    required this.bounds,
    required this.pitch,
    required this.yaw,
    required this.roll,
    required this.leftEye,
    required this.rightEye,
  });
  final int? trackingId;

  /// Face rectangle normalized to the upright input frame.
  final Rect bounds;
  final double? pitch, yaw, roll, leftEye, rightEye;
}

/// Basic active liveness: randomized motions over consecutive live frames.
/// Does not protect against all replays, deepfakes, or modified clients.
class ActiveLivenessSession {
  ActiveLivenessSession({
    Random? random,
    List<LivenessAction>? actions,
    this.mirrored = false,
  }) {
    final source = random ?? Random.secure();
    if (actions != null &&
        (actions.length != 3 || actions.toSet().length != 3)) {
      throw ArgumentError('Invalid challenge');
    }
    _actions = actions == null
        ? (List.of(LivenessAction.values)..shuffle(source))
        : List.of(actions);
    sessionId = List.generate(
      16,
      (_) => source.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
  late final List<LivenessAction> _actions;
  // Protocol actions describe yaw in the input image. iOS mirrors both its
  // frame stream and recording, so only the human-facing turn label changes.
  final bool mirrored;
  late final String sessionId;
  static const timeLimit = Duration(seconds: 45);
  LivenessStage stage = LivenessStage.align;
  int _step = 0, _heldFrames = 0, _blinkPhase = 0;
  int? _trackingId;
  Duration? _lastFrame, _holdStart, _closedAt;
  Duration _elapsed = Duration.zero;
  String? _hint;

  int get completedActions => _step;
  int get actionCount => _actions.length;
  LivenessAction get currentAction =>
      _actions[_step.clamp(0, _actions.length - 1)];
  double get progress =>
      stage == LivenessStage.complete ? 1 : _step / _actions.length;
  int get secondsRemaining =>
      ((timeLimit - _elapsed).inMilliseconds / 1000).ceil().clamp(0, 45);
  String get instruction =>
      _hint ??
      switch (stage) {
        LivenessStage.align => 'Nhìn thẳng, mở mắt và giữ mặt trong khung',
        LivenessStage.perform =>
          currentAction == LivenessAction.blink
              ? switch (_blinkPhase) {
                  0 => 'Mở cả hai mắt và giữ nhìn thẳng',
                  1 => 'Nhắm cả hai mắt khoảng nửa giây',
                  _ => 'Mở mắt lại và nhìn thẳng',
                }
              : (mirrored
                        ? currentAction == LivenessAction.turnLeft
                              ? LivenessAction.turnRight
                              : LivenessAction.turnLeft
                        : currentAction)
                    .instruction,
        LivenessStage.returnToCenter => 'Quay lại nhìn thẳng và giữ yên',
        LivenessStage.complete => 'Hoàn tất thao tác. Đang chụp ảnh...',
        LivenessStage.expired => 'Phiên kiểm tra hết hạn. Vui lòng thử lại.',
      };
  LivenessEvidence? get evidence => stage == LivenessStage.complete
      ? LivenessEvidence._(sessionId, _actions, _elapsed)
      : null;

  void tick(Duration now) {
    _elapsed = now;
    if (now >= timeLimit && stage != LivenessStage.complete) {
      stage = LivenessStage.expired;
      _hint = null;
    }
  }

  void _resetProgress(String message) {
    stage = LivenessStage.align;
    _step = 0;
    _trackingId = null;
    _heldFrames = 0;
    _holdStart = null;
    _blinkPhase = 0;
    _closedAt = null;
    _hint = message;
  }

  bool _hold(bool condition, Duration now, int millis, int frames) {
    if (!condition) {
      _holdStart = null;
      _heldFrames = 0;
      return false;
    }
    _holdStart ??= now;
    _heldFrames++;
    return now - _holdStart! >= Duration(milliseconds: millis) &&
        _heldFrames >= frames;
  }

  void _clearHold() {
    _holdStart = null;
    _heldFrames = 0;
  }

  bool _open(LiveFaceSample face) =>
      face.leftEye != null &&
      face.rightEye != null &&
      face.leftEye! >= .7 &&
      face.rightEye! >= .7;
  bool _straight(LiveFaceSample face) =>
      face.pitch!.abs() <= 12 &&
      face.yaw!.abs() <= 12 &&
      face.roll!.abs() <= 15;

  void addFrame(List<LiveFaceSample> faces, Duration now) {
    if (stage == LivenessStage.complete || stage == LivenessStage.expired) {
      return;
    }
    tick(now);
    if (stage == LivenessStage.expired) return;
    if (_lastFrame != null && now <= _lastFrame!) return;
    if (_lastFrame != null &&
        now - _lastFrame! > const Duration(milliseconds: 800)) {
      _resetProgress('Luồng camera bị gián đoạn. Nhìn thẳng để bắt đầu lại.');
    }
    _lastFrame = now;
    if (faces.length != 1) {
      _resetProgress(
        faces.isEmpty
            ? 'Đưa mặt vào khung hình để bắt đầu lại.'
            : 'Chỉ một người trong khung hình. Bắt đầu lại nhé.',
      );
      return;
    }
    final face = faces.single;
    final box = face.bounds;
    if (face.trackingId == null ||
        [
          face.pitch,
          face.yaw,
          face.roll,
        ].any((v) => v == null || !v.isFinite) ||
        [
          face.leftEye,
          face.rightEye,
        ].any((v) => v != null && (!v.isFinite || v < 0 || v > 1))) {
      _resetProgress('Chưa đo rõ khuôn mặt. Chọn nơi đủ sáng và nhìn thẳng.');
      return;
    }
    if (![box.left, box.top, box.right, box.bottom].every((v) => v.isFinite) ||
        box.width < .2 ||
        box.height < .2 ||
        box.width > .85 ||
        box.height > .95 ||
        box.left < 0 ||
        box.top < 0 ||
        box.right > 1 ||
        box.bottom > 1 ||
        (box.center.dx - .5).abs() > .23 ||
        (box.center.dy - .5).abs() > .25) {
      _resetProgress(
        'Giữ toàn bộ mặt ở giữa khung, không quá gần hoặc quá xa.',
      );
      return;
    }
    if (_trackingId != null && _trackingId != face.trackingId) {
      _resetProgress('Khuôn mặt theo dõi đã thay đổi. Bắt đầu lại.');
      return;
    }
    _trackingId ??= face.trackingId;
    _hint = null;
    if (stage == LivenessStage.align) {
      if (_hold(_straight(face) && _open(face), now, 500, 4)) {
        stage = LivenessStage.perform;
        _clearHold();
      }
      return;
    }
    if (stage == LivenessStage.returnToCenter) {
      if (_hold(_straight(face) && _open(face), now, 350, 3)) {
        _step++;
        _clearHold();
        _blinkPhase = 0;
        _closedAt = null;
        stage = _step == _actions.length
            ? LivenessStage.complete
            : LivenessStage.perform;
      }
      return;
    }
    if (currentAction == LivenessAction.blink) {
      if (!_straight(face) || face.leftEye == null || face.rightEye == null) {
        _blinkPhase = 0;
        _closedAt = null;
        _clearHold();
        return;
      }
      if (_blinkPhase == 0 && _hold(_open(face), now, 180, 2)) {
        _blinkPhase = 1;
        _clearHold();
      } else if (_blinkPhase == 1) {
        if (face.leftEye! <= .25 && face.rightEye! <= .25) {
          _closedAt ??= now;
          if (_hold(true, now, 80, 2)) {
            _blinkPhase = 2;
            _clearHold();
          }
        } else {
          _closedAt = null;
          _clearHold();
        }
      } else if (_blinkPhase == 2) {
        if (now - _closedAt! > const Duration(milliseconds: 1500)) {
          _blinkPhase = 0;
          _closedAt = null;
          _clearHold();
        } else if (_hold(_open(face), now, 180, 2)) {
          stage = LivenessStage.returnToCenter;
          _clearHold();
        }
      }
    } else {
      final turned =
          face.pitch!.abs() <= 20 &&
          face.roll!.abs() <= 20 &&
          (currentAction == LivenessAction.turnLeft
              ? face.yaw! >= 24
              : face.yaw! <= -24);
      if (_hold(turned, now, 350, 3)) {
        stage = LivenessStage.returnToCenter;
        _clearHold();
      }
    }
  }
}
