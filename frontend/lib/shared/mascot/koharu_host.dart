import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';
import '../../routes/app_routes.dart';
import 'koharu_controller.dart';
import 'koharu_guides.dart';
import 'koharu_sprite.dart';

class KoharuHost extends StatefulWidget {
  const KoharuHost({
    super.key,
    required this.controller,
    required this.auth,
    required this.navigatorKey,
    required this.child,
  });
  final KoharuController controller;
  final AuthViewModel auth;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<KoharuHost> createState() => _KoharuHostState();
}

class _KoharuHostState extends State<KoharuHost> {
  final _hostKey = GlobalKey();
  Timer? _poll;
  String? _userId;
  bool _ready = false;
  bool _welcome = false;
  bool _compact = false;
  bool _panelOpen = false;
  bool _shown = false;
  Rect? _rect;
  Object? _revealedTarget;
  KoharuStep? _lastStep;
  KoharuController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_accountChanged);
    c.addListener(_changed);
    _accountChanged();
    // Sample layout only while guiding: this follows scroll/reorder/resize.
    _poll = Timer.periodic(
      const Duration(milliseconds: 120),
      (_) => _measure(),
    );
  }

  void _accountChanged() {
    final user = widget.auth.user;
    final id = user != null && !user.isAdmin && user.status == 'ACTIVE'
        ? user.id
        : null;
    if (id == _userId) return;
    _userId = id;
    _ready = false;
    _welcome = false;
    _compact = false;
    c.drawerOpen = false;
    c.stop();
    if (id != null) _loadPreferences(id);
    if (mounted) setState(() {});
  }

  Future<void> _loadPreferences(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || id != _userId) return;
      setState(() {
        _ready = true;
        _welcome = !(prefs.getBool('koharu.$id.welcome.v1') ?? false);
        _compact = prefs.getBool('koharu.$id.compact') ?? false;
      });
    } catch (_) {
      if (mounted && id == _userId) setState(() => _ready = true);
    }
    _changed();
  }

  Future<void> _remember(String key, bool value) async {
    final id = _userId;
    if (id == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('koharu.$id.$key', value);
    } catch (_) {
      /* Help also works when local storage is unavailable. */
    }
  }

  void _changed() {
    if (!mounted) return;
    _measure();
    setState(() {});
    if (_welcome && _ready && _shown && !_panelOpen) {
      _welcome = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _shown) _openHelp(welcome: true);
      });
    }
  }

  void _measure() {
    if (!mounted) return;
    final shown =
        _ready &&
        _userId != null &&
        c.hasSurface &&
        !_panelOpen &&
        !c.hasPopup &&
        !c.drawerOpen &&
        MediaQuery.viewInsetsOf(context).bottom == 0;
    Rect? rect;
    final step = c.step;
    if (shown && step != null) {
      final target = c.target(step.target);
      if (_lastStep != step || target != _revealedTarget) {
        _lastStep = step;
        _revealedTarget = target;
        if (target != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !target.mounted || c.step != step) return;
            Scrollable.ensureVisible(
              target,
              alignment: .2,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
            );
          });
        }
      }
      final host = _hostKey.currentContext?.findRenderObject();
      if (host is RenderBox && host.hasSize) {
        final raw = c.rect(step.target, host);
        final viewport = Offset.zero & host.size;
        if (raw != null &&
            raw.overlaps(viewport) &&
            raw.width > 0 &&
            raw.height > 0) {
          rect = raw.intersect(viewport).inflate(5);
        }
      }
    }
    if (_shown != shown || _rect != rect) {
      setState(() {
        _shown = shown;
        _rect = rect;
      });
    }
  }

  Future<void> _openHelp({bool welcome = false}) async {
    final account = _userId;
    final navContext = widget.navigatorKey.currentContext;
    if (navContext == null || _panelOpen) return;
    _panelOpen = true;
    if (welcome) unawaited(_remember('welcome.v1', true));
    ModalRoute<dynamic>? sheet;
    final picked = await showModalBottomSheet<KoharuGuide>(
      context: navContext,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) {
        sheet = ModalRoute.of(context);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      KoharuSprite(
                        pose: welcome ? KoharuPose.welcome : KoharuPose.talking,
                        height: 96,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              welcome
                                  ? 'Chào cậu, tớ là Koharu nè! ✨'
                                  : 'Cậu cần Koharu giúp gì nào? ✨',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Cậu muốn làm gì cứ chọn bên dưới nha, tớ sẽ chỉ tận tay từng nút cho cậu! Cậu có thể dừng bất cứ lúc nào nè.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < koharuGuides.length; i++)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        [
                          Icons.luggage_outlined,
                          Icons.route_outlined,
                          Icons.account_balance_wallet_outlined,
                          Icons.people_outline,
                          Icons.verified_user_outlined,
                        ][i],
                        color: AppColors.primary,
                      ),
                      title: Text(koharuGuides[i].title),
                      subtitle: Text(koharuGuides[i].description),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, koharuGuides[i]),
                    ),
                  const Divider(),
                  TextButton.icon(
                    icon: Icon(
                      _compact ? Icons.open_in_full : Icons.close_fullscreen,
                    ),
                    label: Text(
                      _compact
                          ? 'Hiện lại Koharu trên màn hình'
                          : 'Thu gọn Koharu thành icon nhỏ',
                    ),
                    onPressed: () {
                      setState(() => _compact = !_compact);
                      unawaited(_remember('compact', _compact));
                      Navigator.pop(context);
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(welcome ? 'Để sau nha, tớ tự xem được nè' : 'Đóng lại nha'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    // The result resolves before the closing animation releases the page.
    await sheet?.completed;
    _panelOpen = false;
    if (!mounted || _userId == null || _userId != account) return;
    if (picked != null) {
      // Keep any unfinished form underneath when starting another feature.
      final hasEntry = picked.steps.any((s) => c.target(s.target) != null);
      if (!hasEntry) {
        unawaited(widget.navigatorKey.currentState?.pushNamed(AppRoutes.home));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _userId != null) c.start(picked);
      });
    }
    _changed();
  }

  @override
  void dispose() {
    _poll?.cancel();
    widget.auth.removeListener(_accountChanged);
    c.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    key: _hostKey,
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_shown)
        LayoutBuilder(
          builder: (context, bounds) {
            final step = c.step;
            final safe = MediaQuery.paddingOf(context);
            if (step == null) {
              return Stack(
                children: [
                  Positioned(
                    right: math.max(8, safe.right),
                    bottom: safe.bottom + 102,
                    child: Semantics(
                      button: true,
                      label: 'Hỏi Koharu nè',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: _openHelp,
                            child: _compact
                                ? const CircleAvatar(
                                    radius: 24,
                                    backgroundColor: Colors.white,
                                    child: Icon(
                                      Icons.help_outline,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      KoharuSprite(
                                        pose: c.finished
                                            ? KoharuPose.success
                                            : KoharuPose.idle,
                                        height: 88,
                                      ),
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          child: Text(
                                            'Hỏi Koharu nè ✨',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            final width = math.min(
              380.0,
              bounds.maxWidth - 24 - safe.horizontal,
            );
            final target = _rect;
            // Place the card in the larger free area; never put it over its target.
            final below =
                target == null || target.center.dy < bounds.maxHeight / 2;
            final free = target == null
                ? bounds.maxHeight - safe.vertical - 120
                : below
                ? bounds.maxHeight - safe.bottom - target.bottom - 22
                : target.top - safe.top - 22;
            final maxHeight = math.min(300.0, math.max(90.0, free));
            final left =
                ((target?.center.dx ?? bounds.maxWidth / 2) - width / 2).clamp(
                  safe.left + 12,
                  bounds.maxWidth - safe.right - width - 12,
                );
            final edge = below
                ? (target?.bottom ?? safe.top + 60) + 18
                : bounds.maxHeight - (target.top - 18);
            return Stack(
              children: [
                if (target != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _SpotlightPainter(target, below),
                      ),
                    ),
                  ),
                Positioned(
                  left: left,
                  width: width,
                  top: below ? edge : null,
                  bottom: below ? null : edge,
                  child: Material(
                    color: Colors.white,
                    elevation: 8,
                    shadowColor: AppColors.primary.withValues(alpha: .2),
                    borderRadius: BorderRadius.circular(20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxHeight),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                KoharuSprite(
                                  pose: target == null
                                      ? KoharuPose.explain
                                      : below
                                      ? KoharuPose.pointUp
                                      : KoharuPose.explain,
                                  height: 62,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    step.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Semantics(
                                  label: 'Đóng hướng dẫn nè',
                                  button: true,
                                  child: IconButton(
                                    onPressed: c.stop,
                                    icon: const Icon(Icons.close, size: 20),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              target == null
                                  ? 'Ủa, tớ chưa thấy nút này ở đâu cả! Có thể app đang tải dữ liệu, hoặc cậu cần mở đúng màn hình trước nha. Cứ mở ra là tớ chỉ ngay nè~'
                                  : step.message,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              children: [
                                Text(
                                  '${c.index + 1}/${c.guide!.steps.length}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _openHelp(),
                                  child: const Text('Đổi hướng dẫn khác'),
                                ),
                                if (target != null &&
                                    !step.advanceOnTap &&
                                    !step.waitForSave)
                                  FilledButton(
                                    onPressed: c.next,
                                    child: Text(
                                      c.index + 1 == c.guide!.steps.length
                                          ? 'Tớ hiểu rồi!'
                                          : 'Tiếp theo nha ✨',
                                    ),
                                  ),
                                if (target != null &&
                                    (step.advanceOnTap || step.waitForSave))
                                  Text(
                                    step.waitForSave
                                        ? 'Tớ đang đợi cậu lưu xong nè...'
                                        : 'Cậu chạm vào nút viền xanh nha!',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
    ],
  );
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter(this.target, this.below);
  final Rect target;
  final bool below;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(target, const Radius.circular(14)),
      paint,
    );
    final tip = Offset(
      target.center.dx,
      below ? target.bottom + 2 : target.top - 2,
    );
    final direction = below ? 1.0 : -1.0;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - 5, tip.dy + 7 * direction)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + 5, tip.dy + 7 * direction),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.target != target || oldDelegate.below != below;
}
