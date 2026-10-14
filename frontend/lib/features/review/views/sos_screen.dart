import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui_kit.dart';
import '../viewmodels/sos_viewmodel.dart';
import 'emergency_contacts_screen.dart';
import 'sos_history_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
    required this.tripId,
    required this.tripName,
    this.viewModel,
    this.openUrl,
  });
  final String tripId, tripName;
  final SosViewModel? viewModel;
  final Future<bool> Function(Uri)? openUrl;
  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  late final SosViewModel _vm;
  final _message = TextEditingController(
    text: 'Tôi cần giúp đỡ, vui lòng liên hệ với tôi.',
  );
  bool _launching = false;
  @override
  void initState() {
    super.initState();
    _vm = widget.viewModel ?? SosViewModel(tripId: widget.tripId);
    _vm.load();
  }

  @override
  void dispose() {
    _message.dispose();
    if (widget.viewModel == null) _vm.dispose();
    super.dispose();
  }

  Future<void> _open(Uri uri) async {
    if (_launching) return;
    setState(() => _launching = true);
    try {
      final opened =
          await (widget.openUrl?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!mounted) return;
      AppFeedback.show(
        context,
        opened
            ? 'Đã yêu cầu mở ứng dụng. Bạn cần tự xác nhận cuộc gọi/gửi SMS; chưa xác nhận người nhận đã nhận.'
            : 'Thiết bị không mở được ứng dụng này. Hãy sao chép nội dung hoặc gọi trực tiếp.',
        tone: opened ? AppStatusTone.info : AppStatusTone.warning,
      );
    } catch (_) {
      if (mounted) {
        AppFeedback.show(
          context,
          'Không mở được ứng dụng. Hãy sao chép nội dung hoặc gọi trực tiếp.',
          tone: AppStatusTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<void> _create() async {
    final yes = await AppConfirmDialog.show(
      context,
      title: 'Ghi nhận SOS?',
      message:
          'Vị trí sẽ được lưu trên hệ thống. Hệ thống chưa tự gửi SMS/thông báo cho người thân; bạn cần gọi hoặc soạn SMS bên dưới.',
      confirmLabel: 'Ghi nhận SOS',
      destructive: true,
    );
    if (yes && mounted) await _vm.create(_message.text);
  }

  Future<void> _finish(String status) async {
    final yes = await AppConfirmDialog.show(
      context,
      title: status == 'RESOLVED'
          ? 'Xác nhận đã an toàn?'
          : 'Đánh dấu bấm nhầm?',
      message:
          'Kết thúc bản ghi SOS này. SMS/cuộc gọi đã thực hiện trước đó không được thu hồi.',
      confirmLabel: 'Xác nhận',
    );
    if (yes && mounted) await _vm.finish(status);
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: _vm.shareText(widget.tripName, _message.text)),
      );
      if (mounted) {
        AppFeedback.show(
          context,
          'Đã sao chép nội dung; hãy tự gửi cho người cần liên hệ.',
          tone: AppStatusTone.info,
        );
      }
    } catch (_) {
      if (mounted) {
        AppFeedback.show(
          context,
          'Không sao chép được. Hãy chọn nội dung để sao chép thủ công.',
          tone: AppStatusTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _vm,
    builder: (context, _) => AppScaffold(
      title: 'SOS / Liên hệ khẩn cấp',
      scrollable: true,
      actions: [
        IconButton(
          tooltip: 'Tải lại SOS',
          onPressed: _vm.busy ? null : _vm.load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppInlineNotice(
                message:
                    'Nếu cần giúp đỡ ngay, hãy gọi người thân hoặc cơ quan khẩn cấp phù hợp. FeelingTrip không thay thế dịch vụ cứu hộ và chưa tự gửi cảnh báo ra ngoài.',
                tone: AppStatusTone.warning,
              ),
              const SizedBox(height: 16),
              Text(
                widget.tripName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_vm.loading)
                const LoadingIndicator(message: 'Đang tải SOS và liên hệ...'),
              if (_vm.error != null)
                AppInlineNotice(message: _vm.error!, tone: AppStatusTone.error),
              if (_vm.alert != null) ...[
                const SizedBox(height: 12),
                AppStatusBadge(
                  label: switch (_vm.alert!.status) {
                    'ACTIVE' =>
                      'SOS đã ghi nhận · chưa xác nhận gửi cho người thân',
                    'RESOLVED' => 'Đã xác nhận an toàn',
                    _ => 'Đã đánh dấu báo nhầm',
                  },
                  tone: _vm.alert!.isActive
                      ? AppStatusTone.warning
                      : AppStatusTone.neutral,
                ),
                if (_vm.alert!.isActive) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Vị trí đã lưu: ${_vm.alert!.latitude}, ${_vm.alert!.longitude}. Đây là bản chụp, không theo dõi vị trí liên tục.',
                  ),
                  CustomButton(
                    text: 'Tôi đã an toàn',
                    variant: AppButtonVariant.secondary,
                    onPressed: _vm.busy || !_vm.statusLoaded
                        ? null
                        : () => _finish('RESOLVED'),
                  ),
                  CustomButton(
                    text: 'Báo nhầm',
                    variant: AppButtonVariant.text,
                    onPressed: _vm.busy || !_vm.statusLoaded
                        ? null
                        : () => _finish('FALSE_ALARM'),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              CustomButton(
                text: 'Lấy vị trí hiện tại',
                icon: Icons.my_location,
                isLoading: _vm.locating,
                onPressed: _vm.locating || _vm.saving ? null : _vm.locate,
              ),
              if (_vm.location != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Độ chính xác ước tính: ${_vm.location!.accuracy.round()} m. Vị trí chỉ lấy khi bạn bấm nút.',
                ),
              ],
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Nội dung cần hỗ trợ',
                controller: _message,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
                enabled: !_vm.saving,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'Ghi nhận SOS trên hệ thống',
                variant: AppButtonVariant.destructive,
                isLoading: _vm.saving,
                onPressed:
                    _vm.busy ||
                        !_vm.statusLoaded ||
                        _vm.alert?.isActive == true ||
                        _vm.location == null
                    ? null
                    : _create,
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Lịch sử SOS của tôi',
                icon: Icons.history,
                variant: AppButtonVariant.text,
                onPressed: _vm.busy
                    ? null
                    : () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SosHistoryScreen(),
                          ),
                        );
                        if (mounted) await _vm.load();
                      },
              ),
              const SectionHeader(
                title: 'Liên hệ người thân',
                subtitle:
                    'Cuộc gọi và SMS do bạn xác nhận trên thiết bị, có thể phát sinh phí nhà mạng.',
              ),
              if (_vm.contactsError != null)
                AppInlineNotice(
                  message: _vm.contactsError!,
                  tone: AppStatusTone.error,
                ),
              if (!_vm.loading && _vm.contacts.isEmpty)
                const Text(
                  'Chưa có liên hệ. Thêm người thân hoặc gọi trực tiếp bằng điện thoại.',
                ),
              for (final contact in _vm.contacts) ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        contact.fullName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SelectableText(contact.phone),
                      CustomButton(
                        text: 'Gọi ${contact.fullName}',
                        icon: Icons.phone_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: _launching
                            ? null
                            : () => _open(
                                Uri(scheme: 'tel', path: contact.phone),
                              ),
                      ),
                      const SizedBox(height: 8),
                      CustomButton(
                        text: 'Soạn SMS cho ${contact.fullName}',
                        icon: Icons.sms_outlined,
                        onPressed: _launching
                            ? null
                            : () => _open(
                                Uri(
                                  scheme: 'sms',
                                  path: contact.phone,
                                  query:
                                      'body=${Uri.encodeComponent(_vm.shareText(widget.tripName, _message.text))}',
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              CustomButton(
                text: 'Quản lý liên hệ khẩn cấp',
                variant: AppButtonVariant.text,
                onPressed: _vm.saving
                    ? null
                    : () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EmergencyContactsScreen(),
                          ),
                        );
                        if (mounted) await _vm.load();
                      },
              ),
              SelectableText(_vm.shareText(widget.tripName, _message.text)),
              CustomButton(
                text: 'Sao chép nội dung để tự gửi',
                variant: AppButtonVariant.secondary,
                onPressed: _copy,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
