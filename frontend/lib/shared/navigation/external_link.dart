import 'package:flutter/material.dart';
import '../buttons/custom_button.dart';
import '../feedback/app_feedback.dart';
import '../widgets/app_status_badge.dart';

/// Feature provides the URL launcher and reload callback. Closing a hosted flow is not success.
class ExternalLink extends StatefulWidget {
  const ExternalLink({
    super.key,
    required this.label,
    required this.url,
    required this.openUrl,
    required this.onReturn,
  });
  final String label;
  final Uri url;
  final Future<void> Function(Uri) openUrl;
  final Future<void> Function() onReturn;
  @override
  State<ExternalLink> createState() => _ExternalLinkState();
}

class _ExternalLinkState extends State<ExternalLink>
    with WidgetsBindingObserver {
  bool _waiting = false, _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waiting) _reload();
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onReturn();
      _waiting = false;
    } catch (_) {
      if (mounted) {
        AppFeedback.show(
          context,
          'Chưa cập nhật được trạng thái. Vui lòng thử lại.',
          tone: AppStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      _waiting = true;
      await widget.openUrl(widget.url);
    } catch (_) {
      _waiting = false;
      if (mounted) {
        AppFeedback.show(
          context,
          'Chưa mở được liên kết. Vui lòng thử lại.',
          tone: AppStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CustomButton(
        text: widget.label,
        icon: Icons.open_in_new,
        isLoading: _busy,
        onPressed: _open,
      ),
      if (_waiting)
        TextButton(
          onPressed: _busy ? null : _reload,
          child: const Text('Tôi đã quay lại — cập nhật trạng thái'),
        ),
    ],
  );
}
