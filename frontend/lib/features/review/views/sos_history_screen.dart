import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/ui_kit.dart';
import '../models/sos_model.dart';
import '../viewmodels/sos_history_viewmodel.dart';

class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key, this.viewModel, this.openUrl});
  final SosHistoryViewModel? viewModel;
  final Future<bool> Function(Uri)? openUrl;
  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  late final SosHistoryViewModel _vm;
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel ?? SosHistoryViewModel();
    _vm.load();
  }

  @override
  void dispose() {
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  String _time(DateTime? time) => time == null
      ? 'Không có dữ liệu thời gian'
      : DateFormat('dd/MM/yyyy HH:mm:ss').format(time.toLocal());

  Future<void> _map(SosAlert alert) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final opened =
          await (widget.openUrl?.call(alert.mapUrl) ??
              launchUrl(alert.mapUrl, mode: LaunchMode.externalApplication));
      if (!opened && mounted) {
        AppFeedback.show(
          context,
          'Không mở được bản đồ. Bạn có thể sao chép tọa độ đã lưu.',
          tone: AppStatusTone.warning,
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.show(
          context,
          'Không mở được bản đồ. Bạn có thể sao chép tọa độ đã lưu.',
          tone: AppStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Widget _record(SosAlert alert) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          alert.tripName ??
              (alert.tripId == null
                  ? 'SOS không gắn chuyến đi'
                  : 'Chuyến đi không còn thông tin'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        AppStatusBadge(
          label: switch (alert.status) {
            'ACTIVE' => 'Đang cần hỗ trợ',
            'RESOLVED' => 'Đã an toàn',
            _ => 'Báo nhầm',
          },
          tone: alert.isActive ? AppStatusTone.warning : AppStatusTone.neutral,
        ),
        const SizedBox(height: 12),
        Text('Ghi nhận: ${_time(alert.createdAt)}'),
        if (!alert.isActive) Text('Kết thúc: ${_time(alert.resolvedAt)}'),
        const SizedBox(height: 12),
        SelectableText(
          alert.message?.trim().isNotEmpty == true
              ? alert.message!
              : 'Không có nội dung bổ sung.',
        ),
        const SizedBox(height: 12),
        SelectableText('Vị trí đã lưu: ${alert.latitude}, ${alert.longitude}'),
        const Text(
          'Đây là vị trí lúc ghi nhận SOS, không phải vị trí hiện tại.',
        ),
        const SizedBox(height: 8),
        CustomButton(
          text: 'Xem vị trí đã lưu',
          icon: Icons.map_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: _opening ? null : () => _map(alert),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _vm,
    builder: (context, _) => AppScaffold(
      title: 'Lịch sử SOS của tôi',
      actions: [
        IconButton(
          tooltip: 'Tải lại lịch sử SOS',
          onPressed: _vm.loading ? null : () => _vm.load(),
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: () => _vm.load(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const AppInlineNotice(
                  message:
                      'Chỉ bạn xem được lịch sử này trong ứng dụng. Ghi nhận SOS không đồng nghĩa đã gửi SMS hoặc có người tiếp nhận cứu hộ.',
                  tone: AppStatusTone.info,
                ),
                const SizedBox(height: 16),
                if (_vm.error != null) ...[
                  AppInlineNotice(
                    message: _vm.error!,
                    tone: AppStatusTone.error,
                  ),
                  CustomButton(
                    text: 'Thử lại',
                    onPressed: _vm.loading ? null : () => _vm.load(),
                  ),
                ],
                if (!_vm.loading && _vm.error == null && _vm.items.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.history,
                    title: 'Chưa có lịch sử SOS',
                    message:
                        'Các lần bạn bấm ghi nhận SOS thành công sẽ xuất hiện ở đây.',
                  ),
                for (final alert in _vm.items) ...[
                  _record(alert),
                  const SizedBox(height: 16),
                ],
                if (_vm.loading)
                  const LoadingIndicator(message: 'Đang tải lịch sử SOS...'),
                if (_vm.hasMore && !_vm.loading && _vm.error == null)
                  CustomButton(
                    text: 'Xem thêm',
                    onPressed: () => _vm.load(more: true),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
