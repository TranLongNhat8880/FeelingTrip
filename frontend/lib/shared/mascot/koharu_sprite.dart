import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum KoharuPose { idle, welcome, pointLeft, pointUp, talking, success, explain }

class _Atlas {
  _Atlas(this.image, this.manifest);
  final ui.Image image;
  final Map<String, dynamic> manifest;
  static Future<_Atlas>? _cache;
  static Future<_Atlas> load() => _cache ??= _load();
  static Future<_Atlas> _load() async {
    const base = 'assets/mascot/koharu/';
    final manifest =
        jsonDecode(await rootBundle.loadString('${base}animations.json'))
            as Map<String, dynamic>;
    final bytes = await rootBundle.load('$base${manifest['image']}');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    try {
      final frame = await codec.getNextFrame();
      return _Atlas(frame.image, manifest);
    } finally {
      codec.dispose();
    }
  }
}

/// One cached atlas; nearest-neighbour rendering preserves the pixel artwork.
class KoharuSprite extends StatefulWidget {
  const KoharuSprite({
    super.key,
    this.pose = KoharuPose.idle,
    this.height = 96,
  });
  final KoharuPose pose;
  final double height;
  @override
  State<KoharuSprite> createState() => _KoharuSpriteState();
}

class _KoharuSpriteState extends State<KoharuSprite>
    with WidgetsBindingObserver {
  Timer? _timer;
  _Atlas? _atlas;
  int _frame = 0;
  bool _foreground = true;
  bool _animate = true;
  bool _resting = false;
  bool _done = false;
  int _position = 0;
  KoharuPose get _pose => _resting ? KoharuPose.idle : widget.pose;
  String get _name => switch (_pose) {
    KoharuPose.pointLeft => 'koharu_point_left',
    KoharuPose.pointUp => 'koharu_point_up',
    _ => 'koharu_${_pose.name}',
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    try {
      final atlas = await _Atlas.load();
      if (!mounted) return;
      setState(() {
        _atlas = atlas;
        _frame = _frames.first;
      });
      _sync();
    } catch (_) {
      // Keep the help button usable even if an asset cannot be decoded.
    }
  }

  List<int> get _frames =>
      ((_atlas?.manifest['animations'][_name]['frames'] as List?) ?? [0])
          .cast<int>();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(KoharuSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pose != widget.pose) {
      _timer?.cancel();
      _resting = false;
      _done = false;
      _position = 0;
      _frame = _frames.first;
      _sync();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    if (_atlas == null || !_foreground || !_animate || _done) {
      _timer?.cancel();
      return;
    }
    if (_timer?.isActive == true) return;
    final durations = _pose == KoharuPose.idle
        ? [2000, 100, 100, 2000]
        : (_atlas!.manifest['animations'][_name]['durationMs'] as List)
              .cast<int>();
    // The artwork has four frames; wake only when a frame changes, not at 60fps.
    _timer = Timer(Duration(milliseconds: durations[_position]), () {
      if (!mounted) return;
      setState(() {
        if (_position + 1 < _frames.length) {
          _position++;
        } else if (_pose == KoharuPose.idle) {
          _position = 0;
        } else if (widget.pose == KoharuPose.welcome ||
            widget.pose == KoharuPose.success ||
            widget.pose == KoharuPose.talking) {
          _resting = true;
          _position = 0;
        } else {
          _done = true;
        }
        _frame = _frames[_position];
      });
      _sync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: widget.height * 96 / 112,
      height: widget.height,
      child: _atlas == null
          ? const Icon(Icons.support_agent_rounded, color: Color(0xFF0085FF))
          : CustomPaint(painter: _SpritePainter(_atlas!, _frame)),
    ),
  );
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.atlas, this.frame);
  final _Atlas atlas;
  final int frame;
  @override
  void paint(Canvas canvas, Size size) {
    final w = (atlas.manifest['frameWidth'] as num).toDouble();
    final h = (atlas.manifest['frameHeight'] as num).toDouble();
    final columns = atlas.manifest['columns'] as int;
    canvas.drawImageRect(
      atlas.image,
      Rect.fromLTWH((frame % columns) * w, (frame ~/ columns) * h, w, h),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) =>
      atlas != oldDelegate.atlas || frame != oldDelegate.frame;
}
