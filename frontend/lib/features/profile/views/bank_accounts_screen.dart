import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui_kit.dart';
import '../models/bank_account_model.dart';
import '../viewmodels/profile_viewmodel.dart';
import 'bank_account_form_sheet.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key, required this.viewModel, this.openUrl});
  final ProfileViewModel viewModel;
  final Future<void> Function(Uri)? openUrl;

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  BankLinkAttempt? _attempt;
  Timer? _expiryTimer;
  bool _refreshing = false;
  bool _preparing = false;
  bool _showNumber = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.viewModel.loadProfile();
      widget.viewModel.loadBankAccounts();
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    super.dispose();
  }

  Future<void> _editReceivingAccount() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => BankAccountFormSheet(viewModel: widget.viewModel),
    );
    if (!mounted || saved != true) return;
    setState(() => _showNumber = false);
    AppFeedback.show(
      context,
      'Đã lưu thông tin nhận tiền. Thao tác này không xác nhận liên kết Bank Hub.',
      tone: AppStatusTone.success,
    );
    await widget.viewModel.loadBankAccounts();
  }

  Future<void> _prepare(BankLinkPurpose purpose, {String? accountId}) async {
    if (_preparing ||
        _refreshing ||
        widget.viewModel.isLoadingBankAccounts ||
        widget.viewModel.isSavingProfile) {
      return;
    }
    if (purpose == BankLinkPurpose.unlink) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Ngắt liên kết ngân hàng?',
        message:
            'Bạn cần xác nhận trên SePay. Việc tạo hoặc đóng phiên tại đây không tự ngắt liên kết.',
        confirmLabel: 'Tiếp tục',
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() => _preparing = true);
    try {
      // A fresh baseline prevents cached accounts from confirming a new operation.
      final loaded = await widget.viewModel.loadBankAccounts();
      if (!mounted || !loaded) return;
      final before = widget.viewModel.bankAccounts;
      final link = await widget.viewModel.createBankHostedLink(
        purpose: purpose,
        accountId: accountId,
      );
      if (!mounted || link == null) return;
      final attempt = BankLinkAttempt(
        link: link,
        purpose: purpose,
        accountId: accountId,
        before: before,
      );
      _expiryTimer?.cancel();
      setState(() {
        _attempt = attempt;
        _result = null;
      });
      final expiry = link.expiresAt;
      if (expiry != null && !attempt.expired) {
        _expiryTimer = Timer(expiry.difference(DateTime.now()), () {
          if (mounted) setState(() {});
        });
      }
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _openHostedLink(Uri uri) async {
    if (_attempt == null || _attempt!.expired) {
      throw StateError('Phiên đã hết hạn. Hãy tạo phiên mới.');
    }
    if (widget.openUrl != null) {
      await widget.openUrl!(uri);
    } else if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Không thể mở SePay Bank Hub');
    }
  }

  Future<void> _refresh() async {
    if (_refreshing ||
        _preparing ||
        widget.viewModel.isLoadingBankAccounts ||
        widget.viewModel.isSavingProfile) {
      return;
    }
    setState(() => _refreshing = true);
    final attempt = _attempt;
    try {
      final loaded = await widget.viewModel.refreshAfterBankReturn();
      if (!mounted || !loaded) return;
      if (attempt != null && attempt == _attempt) {
        final confirmed = attempt.confirmedBy(widget.viewModel.bankAccounts);
        setState(() {
          if (confirmed) {
            _attempt = null;
            _expiryTimer?.cancel();
            _result =
                'Backend đã xác nhận ${switch (attempt.purpose) {
                  BankLinkPurpose.link => 'liên kết tài khoản',
                  BankLinkPurpose.unlink => 'ngắt liên kết',
                  BankLinkPurpose.reactivate => 'kích hoạt lại tài khoản',
                }}.';
          } else {
            _result =
                'Chưa nhận được thay đổi xác nhận từ backend. '
                'Nếu đã hoàn tất trên SePay, chờ một chút rồi kiểm tra lại.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  bool get _busy =>
      _preparing ||
      _refreshing ||
      widget.viewModel.isLoadingBankAccounts ||
      widget.viewModel.isSavingProfile;

  Widget _receivingAccount() {
    final vm = widget.viewModel;
    final profile = vm.profile;
    final number = profile?.bankAccountNumber ?? '';
    final hasNumber = number.isNotEmpty;
    final linked =
        hasNumber &&
        vm.bankAccountsErrorMessage == null &&
        !vm.isLoadingBankAccounts &&
        !vm.isSavingProfile &&
        vm.bankAccounts.any(
          (a) => a.isLinked && a.isDefault && a.accountNumber == number,
        );
    return AppCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '1. Thông tin nhận tiền',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Lưu ngân hàng, số tài khoản và tên người nhận trong hồ sơ để dùng khi chia chi phí. Không phải xác thực danh tính ngân hàng.',
          ),
          const SizedBox(height: 16),
          if (profile == null && vm.isLoadingProfile)
            const LoadingIndicator(message: 'Đang tải hồ sơ...')
          else if (profile == null)
            AppInlineNotice(
              message: vm.profileErrorMessage ?? 'Chưa tải được hồ sơ.',
              tone: AppStatusTone.error,
            )
          else if (!hasNumber)
            const Text('Chưa lưu thông tin nhận tiền.')
          else ...[
            _buildLuxuryBankCard(
              bankName: profile.bankName ?? '',
              accountNumber: number,
              accountHolderName: profile.bankAccountName ?? '',
              bankBin: profile.bankBin,
            ),
            const SizedBox(height: 12),
            AppStatusBadge(
              label: linked
                  ? 'Khớp tài khoản Bank Hub đang liên kết'
                  : 'Thông tin trong hồ sơ · chưa xác nhận Bank Hub',
              tone: linked ? AppStatusTone.success : AppStatusTone.warning,
            ),
          ],
          const SizedBox(height: 16),
          if (profile == null)
            CustomButton(
              text: 'Tải lại hồ sơ',
              onPressed: vm.isLoadingProfile ? null : vm.loadProfile,
            )
          else
            CustomButton(
              text: hasNumber
                  ? 'Sửa thông tin nhận tiền'
                  : 'Nhập tài khoản nhận tiền',
              icon: Icons.edit_outlined,
              onPressed:
                  _preparing ||
                      _refreshing ||
                      vm.isSavingProfile ||
                      _attempt != null
                  ? null
                  : _editReceivingAccount,
            ),
          const SizedBox(height: 8),
          const Text(
            'Lưu hoặc sửa thông tin này không tự liên kết/ngắt liên kết SePay. Không sửa thông tin trong lúc đang thực hiện phiên SePay.',
          ),
        ],
      ),
    );
  }

  String _formatAccountNumber(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write('  ');
      buffer.write(clean[i]);
    }
    return buffer.toString();
  }

  Widget _buildLuxuryBankCard({
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
    String? bankBin,
  }) {
    final displayBankName = bankName.trim().isNotEmpty
        ? bankName
        : (bankBin == null
              ? 'Ngân hàng thụ hưởng'
              : 'Ngân hàng (BIN $bankBin)');
    final displayName = accountHolderName.trim().isNotEmpty
        ? accountHolderName.toUpperCase()
        : 'CHỦ TÀI KHOẢN';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF064E3B), // Deep emerald
            Color(0xFF047857), // Forest emerald
            Color(0xFF0F766E), // Deep teal
            Color(0xFF115E59),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            bottom: -35,
            child: Icon(
              Icons.account_balance_rounded,
              size: 190,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Positioned(
            right: 40,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              displayBankName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code_2_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'VietQR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFDF7A),
                            Color(0xFFE5A638),
                            Color(0xFFF9D46A),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFB8860B),
                          width: 0.5,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 32,
                          height: 18,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.black26,
                              width: 0.8,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Transform.rotate(
                      angle: 1.5708,
                      child: Icon(
                        Icons.wifi_rounded,
                        color: Colors.white.withValues(alpha: 0.65),
                        size: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _showNumber || accountNumber.length <= 4
                            ? _formatAccountNumber(accountNumber)
                            : '•••• ${accountNumber.substring(accountNumber.length - 4)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _showNumber
                          ? 'Ẩn số tài khoản'
                          : 'Hiện số tài khoản',
                      onPressed: () =>
                          setState(() => _showNumber = !_showNumber),
                      icon: Icon(
                        _showNumber
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Sao chép số tài khoản',
                      onPressed: () async {
                        try {
                          await Clipboard.setData(
                            ClipboardData(text: accountNumber),
                          );
                          if (!mounted) return;
                          AppFeedback.show(
                            context,
                            'Đã sao chép số tài khoản.',
                            tone: AppStatusTone.success,
                          );
                        } catch (_) {
                          if (!mounted) return;
                          AppFeedback.show(
                            context,
                            'Không thể sao chép số tài khoản.',
                            tone: AppStatusTone.error,
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHỦ TÀI KHOẢN',
                            style: TextStyle(
                              color: const Color(
                                0xFFA7F3D0,
                              ).withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF34D399).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Color(0xFF34D399),
                            size: 14,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Tài khoản chính',
                            style: TextStyle(
                              color: Color(0xFFD1FAE5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hostedSession(BankLinkAttempt attempt) {
    final expiry = attempt.link.expiresAt?.toLocal();
    return AppCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppStatusBadge(
            label: attempt.expired
                ? 'Phiên đã hết hạn'
                : 'Chờ xác nhận từ Bank Hub',
            tone: AppStatusTone.warning,
          ),
          const SizedBox(height: 12),
          const Text(
            'Mở SePay, hoàn tất thao tác rồi quay lại kiểm tra. Chỉ quay lại ứng dụng chưa có nghĩa là thành công.',
          ),
          if (expiry != null)
            Text(
              'Hết hạn: ${expiry.day}/${expiry.month}/${expiry.year} '
              '${expiry.hour.toString().padLeft(2, '0')}:${expiry.minute.toString().padLeft(2, '0')}',
            ),
          const SizedBox(height: 12),
          if (attempt.expired)
            CustomButton(
              text: 'Tạo phiên mới',
              isLoading: _preparing,
              onPressed: _busy
                  ? null
                  : () =>
                        _prepare(attempt.purpose, accountId: attempt.accountId),
            )
          else
            ExternalLink(
              key: ValueKey(attempt),
              label: switch (attempt.purpose) {
                BankLinkPurpose.link => 'Mở SePay để liên kết',
                BankLinkPurpose.unlink => 'Mở SePay để ngắt liên kết',
                BankLinkPurpose.reactivate => 'Mở SePay để kích hoạt lại',
              },
              url: attempt.link.url,
              openUrl: _openHostedLink,
              onReturn: _refresh,
            ),
          const SizedBox(height: 8),
          CustomButton(
            text: 'Kiểm tra kết quả',
            variant: AppButtonVariant.secondary,
            isLoading: _refreshing,
            onPressed: _busy ? null : _refresh,
          ),
          CustomButton(
            text: 'Đóng phiên trên ứng dụng',
            variant: AppButtonVariant.text,
            onPressed: _busy
                ? null
                : () {
                    _expiryTimer?.cancel();
                    setState(() {
                      _attempt = null;
                      _result =
                          'Đã đóng phiên hiển thị. Không ngắt liên kết hoặc thu hồi URL trên SePay.';
                    });
                  },
          ),
        ],
      ),
    );
  }

  Widget _bankHub() {
    final vm = widget.viewModel;
    return AppCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '2. Liên kết SePay Bank Hub',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Liên kết thực hiện trên SePay; backend đồng bộ trạng thái để hỗ trợ đối soát thanh toán. FeelingTrip không yêu cầu nhập mật khẩu ngân hàng tại đây.',
          ),
          const SizedBox(height: 16),
          if (vm.isLoadingBankAccounts)
            const LoadingIndicator(message: 'Đang tải trạng thái Bank Hub...'),
          if (vm.bankAccountsErrorMessage != null)
            AppInlineNotice(
              message: vm.bankAccountsErrorMessage!,
              tone: AppStatusTone.error,
            )
          else if (!vm.isLoadingBankAccounts && vm.bankAccounts.isEmpty)
            const Text(
              'Chưa có tài khoản liên kết qua Bank Hub. Thông tin nhận tiền nhập tay vẫn nằm ở mục 1.',
            ),
          if (vm.profileErrorMessage != null && vm.profile != null)
            AppInlineNotice(
              message: vm.profileErrorMessage!,
              tone: AppStatusTone.error,
            ),
          if (vm.bankAccountsErrorMessage == null)
            ...vm.bankAccounts.map(
              (account) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: AppCard(
                  outlined: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        account.bankName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${account.maskedAccountNumber}\n${account.accountHolderName}',
                      ),
                      const SizedBox(height: 8),
                      AppStatusBadge(
                        label: account.isLinked
                            ? 'Đang liên kết'
                            : 'Đã ngắt liên kết',
                        tone: account.isLinked
                            ? AppStatusTone.success
                            : AppStatusTone.neutral,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: account.isLinked
                            ? 'Ngắt liên kết'
                            : 'Kích hoạt lại',
                        variant: AppButtonVariant.secondary,
                        onPressed: _busy || _attempt != null
                            ? null
                            : () => _prepare(
                                account.isLinked
                                    ? BankLinkPurpose.unlink
                                    : BankLinkPurpose.reactivate,
                                accountId: account.id,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (vm.bankLinkErrorMessage != null) ...[
            const SizedBox(height: 12),
            AppInlineNotice(
              message:
                  '${vm.bankLinkErrorMessage!}\n'
                  'Nếu backend chưa cấu hình SePay, bạn vẫn có thể lưu thông tin nhận tiền ở mục 1; đó chưa phải liên kết Bank Hub.',
              tone: AppStatusTone.warning,
            ),
          ],
          if (_attempt case final attempt?) ...[
            const SizedBox(height: 12),
            _hostedSession(attempt),
          ],
          if (_result != null) ...[
            const SizedBox(height: 12),
            AppInlineNotice(message: _result!, tone: AppStatusTone.info),
          ],
          const SizedBox(height: 16),
          CustomButton(
            text: 'Liên kết qua SePay',
            icon: Icons.add_link,
            isLoading: _preparing,
            onPressed: _busy || _attempt != null
                ? null
                : () => _prepare(BankLinkPurpose.link),
          ),
          CustomButton(
            text: 'Tải lại trạng thái',
            variant: AppButtonVariant.text,
            isLoading: _refreshing,
            onPressed: _busy ? null : _refresh,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.viewModel,
    builder: (context, _) => AppScaffold(
      title: 'Tài khoản ngân hàng',
      scrollable: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _receivingAccount(),
              const SizedBox(height: 24),
              _bankHub(),
            ],
          ),
        ),
      ),
    ),
  );
}
