import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../profile/viewmodels/profile_viewmodel.dart';
import '../../profile/views/bank_accounts_screen.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.settlement,
    required this.repository,
    this.pollInterval = const Duration(seconds: 5),
  });
  final Settlement settlement;
  final ExpenseRepository repository;
  final Duration pollInterval;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  Timer? _timer;
  PaymentStatus? _payment;
  String? _error;
  bool _checking = false, _announced = false;
  bool _active = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    if (!_active ||
        _payment?.status == 'PAID' ||
        _payment?.status == 'CANCELLED') {
      return;
    }
    _timer = Timer.periodic(widget.pollInterval, (_) => _check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) {
      _check();
      _startPolling();
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _check() async {
    if (_checking ||
        !_active ||
        _payment?.status == 'PAID' ||
        _payment?.status == 'CANCELLED') {
      return;
    }
    setState(() => _checking = true);
    try {
      final result = await widget.repository.payment(widget.settlement.id);
      if (!mounted) return;
      setState(() {
        _payment = result;
        _error = null;
      });
      if (result.status == 'PAID' || result.status == 'CANCELLED') {
        _timer?.cancel();
      }
      if (result.status == 'PAID' && !_announced) {
        _announced = true;
        AppFeedback.show(
          context,
          'Thanh toán thành công. Khoản nợ đã được gạch.',
          tone: AppStatusTone.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Chưa kiểm tra được giao dịch. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _bank() async {
    _active = false;
    _timer?.cancel();
    final vm = ProfileViewModel();
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => BankAccountsScreen(viewModel: vm)),
    );
    vm.dispose();
    if (!mounted) return;
    _active = true;
    await _check();
    _startPolling();
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      AppFeedback.show(context, 'Đã sao chép.', tone: AppStatusTone.success);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    final paid = payment?.status == 'PAID';
    final cancelled = payment?.status == 'CANCELLED';
    final creditor = AuthScope.of(context).user?.id == widget.settlement.toId;
    return AppScaffold(
      showKoharu: false,
      title: paid ? 'Thanh toán thành công' : 'Thanh toán khoản nợ',
      scrollable: true,
      bottomAction: paid || cancelled
          ? CustomButton(
              text: 'Trở về công nợ',
              onPressed: () => Navigator.pop(context),
            )
          : CustomButton(
              text: 'Kiểm tra thanh toán',
              variant: AppButtonVariant.secondary,
              isLoading: _checking,
              onPressed: _checking ? null : _check,
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.settlement.fromName} → ${widget.settlement.toName}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            AppUtils.formatCurrency(
              payment?.amount ?? widget.settlement.amount,
            ),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          if (paid)
            const AppInlineNotice(
              message:
                  'Hệ thống đã xác nhận nhận tiền. Khoản nợ được chuyển sang Đã thanh toán và giữ lại trong lịch sử.',
              tone: AppStatusTone.success,
            )
          else if (cancelled)
            const AppInlineNotice(
              message:
                  'Khoản nợ này đã được tính lại. QR cũ hết hiệu lực; hãy trở về công nợ để mở khoản mới.',
              tone: AppStatusTone.warning,
            )
          else if (payment == null && _error == null)
            const LoadingIndicator(message: 'Đang lấy thông tin thanh toán...')
          else if (_error != null)
            AppInlineNotice(message: _error!, tone: AppStatusTone.error)
          else if (payment!.status == 'REPORTED')
            const AppInlineNotice(
              message:
                  'Khoản này đã được báo chuyển. Hệ thống đang chờ xác nhận nhận tiền; không chuyển thêm lần nữa.',
              tone: AppStatusTone.warning,
            )
          else if (payment.qrUrl == null) ...[
            AppInlineNotice(
              message:
                  '${widget.settlement.toName} chưa cập nhật thông tin tài khoản ngân hàng nhận tiền.',
              tone: AppStatusTone.warning,
            ),
            if (creditor) ...[
              const SizedBox(height: 20),
              CustomButton(
                text: 'Thiết lập ngân hàng nhận tiền',
                onPressed: _bank,
              ),
            ],
          ] else ...[
            AppCard(
              child: Column(
                children: [
                  Image.network(
                    payment.qrUrl!,
                    width: 280,
                    height: 280,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            height: 280,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'Chưa tải được ảnh QR. Kiểm tra mạng và mở lại màn hình.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Quét bằng app ngân hàng. Giữ nguyên số tiền và nội dung chuyển khoản.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            InfoRow(
              icon: Icons.person_outline,
              label: 'Chủ tài khoản',
              value: payment.accountName,
            ),
            const SizedBox(height: 12),
            InfoRow(
              icon: Icons.account_balance_outlined,
              label: 'Số tài khoản',
              value: payment.accountNumber,
            ),
            CustomButton(
              text: 'Sao chép số tài khoản',
              variant: AppButtonVariant.text,
              onPressed: () => _copy(payment.accountNumber),
            ),
            const SizedBox(height: 8),
            SelectableText('Nội dung: ${payment.reference}'),
            CustomButton(
              text: 'Sao chép nội dung',
              variant: AppButtonVariant.text,
              onPressed: () => _copy(payment.reference),
            ),
            const SizedBox(height: 12),
            const AppInlineNotice(
              message:
                  'Sau khi chuyển khoản, quay lại màn hình này. App tự kiểm tra và chỉ báo thành công khi hệ thống xác nhận nhận tiền.',
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
