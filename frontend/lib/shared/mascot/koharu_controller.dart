import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'koharu_guides.dart';

/// Targets belong to rendered controls, never to screen coordinates.
class KoharuController extends ChangeNotifier {
  final Map<Object, _TargetEntry> _targets = {};
  final Map<Object, BuildContext> _surfaces = {};
  final List<Route<dynamic>> routes = [];
  KoharuGuide? guide;
  int index = 0;
  bool finished = false;
  bool drawerOpen = false;
  bool _disposed = false;
  bool _pending = false;

  KoharuStep? get step => guide == null ? null : guide!.steps[index];

  void changed() {
    if (_pending || _disposed) return;
    _pending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      if (!_disposed) notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _visible(BuildContext context) {
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }
    var render = context.findRenderObject();
    if (render is! RenderBox || !render.attached || !render.hasSize) {
      return false;
    }
    while (render != null) {
      if (render is RenderOffstage && render.offstage) return false;
      if (render is RenderAbsorbPointer && render.absorbing) return false;
      if (render is RenderIgnorePointer && render.ignoring) return false;
      final parent = render.parent;
      if (parent is RenderIndexedStack) {
        var selected = parent.firstChild;
        for (var i = 0; i < (parent.index ?? -1) && selected != null; i++) {
          selected = (selected.parentData! as StackParentData).nextSibling;
        }
        if (parent.index == null || render != selected) return false;
      }
      render = render.parent;
    }
    return true;
  }

  bool get hasSurface => _surfaces.values.any(_visible);
  bool get hasPopup => routes.isNotEmpty && routes.last is PopupRoute;

  BuildContext? target(String id) {
    for (final entry in _targets.values.toList().reversed) {
      if (entry.id == id && entry.enabled && _visible(entry.context)) {
        return entry.context;
      }
    }
    return null;
  }

  Rect? rect(String id, RenderBox host) {
    final box = target(id)?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) return null;
    var result = box.localToGlobal(Offset.zero, ancestor: host) & box.size;
    var parent = box.parent;
    while (parent != null && parent != host) {
      final viewport = parent is RenderBox ? parent : null;
      if (parent is RenderAbstractViewport &&
          viewport != null &&
          viewport.hasSize) {
        result = result.intersect(
          viewport.localToGlobal(Offset.zero, ancestor: host) & viewport.size,
        );
      }
      parent = parent.parent;
    }
    return result.isEmpty ? null : result;
  }

  void start(KoharuGuide value) {
    guide = value;
    finished = false;
    // Resume at a relevant control when help is opened inside a feature.
    index = 0;
    for (var i = 0; i < value.steps.length; i++) {
      if (!value.steps[i].target.startsWith('home.') &&
          target(value.steps[i].target) != null) {
        index = i;
        break;
      }
    }
    if (index == 0) {
      final manage = value.steps.indexWhere((s) => s.target == 'home.manage');
      if (manage >= 0 && target('home.manage') != null) index = manage;
    }
    changed();
  }

  void next() {
    if (guide == null) return;
    if (index + 1 == guide!.steps.length) {
      guide = null;
      finished = true;
    } else {
      index++;
    }
    changed();
  }

  void tapped(String? id) {
    if (id != null && step?.target == id && step!.advanceOnTap) next();
  }

  /// Called after a successful repository operation, not on the Save tap.
  void complete(String id) {
    if (step?.target == id) next();
  }

  void stop() {
    guide = null;
    finished = false;
    changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class KoharuScope extends InheritedWidget {
  const KoharuScope({
    super.key,
    required this.controller,
    required super.child,
  });
  final KoharuController controller;
  static KoharuController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KoharuScope>()?.controller;
  @override
  bool updateShouldNotify(KoharuScope oldWidget) =>
      controller != oldWidget.controller;
}

class KoharuTarget extends StatefulWidget {
  const KoharuTarget({
    super.key,
    required this.id,
    required this.child,
    this.enabled = true,
  });
  final String? id;
  final Widget child;
  final bool enabled;
  @override
  State<KoharuTarget> createState() => _KoharuTargetState();
}

class _KoharuTargetState extends State<KoharuTarget> {
  KoharuController? _controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = KoharuScope.maybeOf(context);
    if (next != _controller) _controller?._targets.remove(this);
    _controller = next;
    _register();
  }

  @override
  void didUpdateWidget(KoharuTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  void _register() {
    if (widget.id == null) {
      _controller?._targets.remove(this);
      return;
    }
    _controller?._targets[this] = _TargetEntry(
      widget.id,
      context,
      widget.enabled,
    );
    _controller?.changed();
  }

  @override
  void dispose() {
    _controller?._targets.remove(this);
    _controller?.changed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

extension KoharuAnchor on Widget {
  Widget koharu(String? id, {bool enabled = true}) =>
      KoharuTarget(id: id, enabled: enabled, child: this);
}

class _TargetEntry {
  const _TargetEntry(this.id, this.context, this.enabled);
  final String? id;
  final BuildContext context;
  final bool enabled;
}

/// Only explicitly supported screens expose the companion.
class KoharuSurface extends StatefulWidget {
  const KoharuSurface({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<KoharuSurface> createState() => _KoharuSurfaceState();
}

class _KoharuSurfaceState extends State<KoharuSurface> {
  KoharuController? _controller;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller?._surfaces.remove(this);
    _controller = KoharuScope.maybeOf(context);
    _register();
  }

  @override
  void didUpdateWidget(KoharuSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _register();
  }

  void _register() {
    if (widget.enabled) {
      _controller?._surfaces[this] = context;
    } else {
      _controller?._surfaces.remove(this);
    }
    _controller?.changed();
  }

  @override
  void dispose() {
    _controller?._surfaces.remove(this);
    _controller?.changed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class KoharuNavigatorObserver extends NavigatorObserver {
  KoharuNavigatorObserver(this.controller);
  final KoharuController controller;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller.routes.add(route);
    controller.changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller.routes.remove(route);
    controller.changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    controller.routes.remove(route);
    controller.changed();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : controller.routes.indexOf(oldRoute);
    if (i >= 0) {
      if (newRoute == null) {
        controller.routes.removeAt(i);
      } else {
        controller.routes[i] = newRoute;
      }
    }
    controller.changed();
  }
}
