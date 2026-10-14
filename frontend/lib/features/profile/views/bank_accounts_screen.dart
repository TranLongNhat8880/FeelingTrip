import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/ui_kit.dart';
import '../models/bank_account_model.dart';
import '../models/profile_form_data.dart';
import '../viewmodels/profile_viewmodel.dart';

class BankAccountsScreen extends StatefulWidget {
  const BankAccountsScreen({super.key, required this.viewModel});

  final ProfileViewModel viewModel;

  @override
  State<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  BankHostedLink? _activeHostedLink;
  String _activeLinkLabel = 'Mở SePay Bank Hub';

  static const Map<String, String> _bankList = {
    '970422': 'MBBank (Ngân hàng Quân đội)',
    '970436': 'Vietcombank',
    '970407': 'Techcombank',
    '970415': 'VietinBank',
    '970418': 'BIDV',
    '970405': 'Agribank',
    '970416': 'ACB',
    '970432': 'VPBank',
    '970423': 'TPBank',
    '970403': 'Sacombank',
    '970441': 'VIB',
    '970437': 'HDBank',
    '970443': 'SHB',
    '970426': 'MSB',
    '970448': 'OCB',
    '970440': 'SeABank',
    '546034': 'Cake by VPBank',
    '963388': 'Timo by BVBank',
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.viewModel.loadProfile();
      widget.viewModel.loadBankAccounts();
    });
  }

  Future<void> _showManualBankBottomSheet() async {
    final profile = widget.viewModel.profile;
    String selectedBin = profile?.bankBin ?? '970422';
    if (!_bankList.containsKey(selectedBin)) {
      selectedBin = '970422';
    }

    final numberController = TextEditingController(
      text: profile?.bankAccountNumber ?? '',
    );
    final nameController = TextEditingController(
      text: profile?.bankAccountName ?? profile?.fullName ?? '',
    );
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Thiết lập tài khoản nhận tiền',
                            style: Theme.of(modalContext).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(bottomSheetContext),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Thông tin này dùng để tạo mã VietQR chuyển tiền tự động khi chia hoá đơn nhóm.',
                        style: Theme.of(modalContext).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(modalContext).hintColor,
                            ),
                      ),
                      const SizedBox(height: 20),
                      AppDropdownField<String>(
                        label: 'Ngân hàng',
                        value: selectedBin,
                        items: _bankList.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedBin = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Số tài khoản',
                        hint: 'Nhập số tài khoản ngân hàng',
                        controller: numberController,
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.pin_outlined,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập số tài khoản';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: 'Tên chủ tài khoản (viết hoa không dấu)',
                        hint: 'Ví dụ: NGUYEN VAN A',
                        controller: nameController,
                        prefixIcon: Icons.person_outline,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Vui lòng nhập tên chủ tài khoản';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: 'Lưu tài khoản',
                        icon: Icons.check_circle_outline_rounded,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final currentProfile = widget.viewModel.profile;
                          if (currentProfile == null) return;

                          final success = await widget.viewModel.updateProfile(
                            data: ProfileFormData(
                              fullName: currentProfile.fullName ?? '',
                              nickname: currentProfile.nickname,
                              phone: currentProfile.phone,
                              bio: currentProfile.bio,
                              gender: currentProfile.gender,
                              dob: currentProfile.dob,
                              bankBin: selectedBin,
                              bankName: _bankList[selectedBin] ?? 'MBBank',
                              bankAccountNumber: numberController.text.trim(),
                              bankAccountName:
                                  nameController.text.trim().toUpperCase(),
                            ),
                          );

                          if (success) {
                            await widget.viewModel.loadBankAccounts();
                            if (bottomSheetContext.mounted) {
                              Navigator.of(bottomSheetContext).pop();
                            }
                            if (mounted) {
                              AppFeedback.show(
                                context,
                                'Đã lưu tài khoản ngân hàng nhận tiền thành công.',
                                tone: AppStatusTone.success,
                              );
                            }
                          } else {
                            if (mounted) {
                              AppFeedback.show(
                                context,
                                widget.viewModel.errorMessage ??
                                    'Không thể lưu thông tin tài khoản.',
                                tone: AppStatusTone.error,
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _prepareHostedLink({
    required BankLinkPurpose purpose,
    BankAccountModel? account,
  }) async {
    if (purpose == BankLinkPurpose.unlink) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Ngắt liên kết ngân hàng?',
        message:
            'Bạn sẽ được chuyển sang SePay Bank Hub để xác nhận '
            'ngắt liên kết tài khoản ${account?.maskedAccountNumber ?? ''}.',
        confirmLabel: 'Tiếp tục',
        destructive: true,
      );

      if (!confirmed || !mounted) return;
    }

    final link = await widget.viewModel.createBankHostedLink(
      purpose: purpose,
      accountId: account?.id,
    );

    if (!mounted) return;

    if (link == null) {
      final err = widget.viewModel.errorMessage ?? '';
      final isConfigErr = err.contains('Chưa cấu hình') ||
          err.contains('Cần cấu hình') ||
          err.contains('chưa được cấu hình');
      AppFeedback.show(
        context,
        isConfigErr
            ? 'Cổng SePay Bank Hub tự động chưa bật. Vui lòng bấm "Cập nhật tài khoản nhận tiền" để nhập số tài khoản trực tiếp.'
            : (widget.viewModel.errorMessage ?? 'Không thể tạo liên kết Bank Hub.'),
        tone: AppStatusTone.warning,
      );
      return;
    }

    setState(() {
      _activeHostedLink = link;
      _activeLinkLabel = _labelForPurpose(purpose);
    });

    AppFeedback.show(
      context,
      'Đã tạo liên kết bảo mật. Hãy mở SePay để tiếp tục.',
      tone: AppStatusTone.success,
    );
  }

  Future<void> _openHostedLink(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened) {
      throw StateError('Không thể mở liên kết Bank Hub');
    }
  }

  Future<void> _refreshAfterReturn() async {
    await widget.viewModel.refreshAfterBankReturn();

    if (!mounted) return;

    if (widget.viewModel.errorMessage != null) {
      AppFeedback.show(
        context,
        widget.viewModel.errorMessage!,
        tone: AppStatusTone.error,
      );
      return;
    }

    setState(() {
      _activeHostedLink = null;
    });

    AppFeedback.show(
      context,
      'Đã cập nhật trạng thái tài khoản ngân hàng.',
      tone: AppStatusTone.success,
    );
  }

  String _labelForPurpose(BankLinkPurpose purpose) {
    switch (purpose) {
      case BankLinkPurpose.link:
        return 'Mở SePay để liên kết tài khoản';
      case BankLinkPurpose.unlink:
        return 'Mở SePay để ngắt liên kết';
      case BankLinkPurpose.reactivate:
        return 'Mở SePay để kích hoạt lại';
    }
  }

  String _formatExpiry(DateTime? value) {
    if (value == null) {
      return 'Liên kết chỉ có hiệu lực trong thời gian ngắn.';
    }

    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return 'Liên kết hết hạn lúc '
        '$hour:$minute, ngày $day/$month/${local.year}.';
  }

  Widget _buildHostedLinkCard() {
    final link = _activeHostedLink;

    if (link == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppStatusBadge(
            label: 'Liên kết bảo mật đã sẵn sàng',
            tone: AppStatusTone.success,
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            'Tiếp tục trên SePay Bank Hub',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(_formatExpiry(link.expiresAt)),
          const SizedBox(height: 16),
          ExternalLink(
            label: _activeLinkLabel,
            url: link.url,
            openUrl: _openHostedLink,
            onReturn: _refreshAfterReturn,
          ),
          CustomButton(
            text: 'Hủy liên kết này',
            onPressed: () {
              setState(() {
                _activeHostedLink = null;
              });
            },
            variant: AppButtonVariant.text,
            fullWidth: false,
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
        : (_bankList[bankBin] ?? 'Ngân hàng thụ hưởng');
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
                            'VietQR 24/7',
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
                        _formatAccountNumber(accountNumber),
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
                      icon: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: 'Sao chép số tài khoản',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: accountNumber));
                        AppFeedback.show(
                          context,
                          'Đã sao chép số tài khoản $accountNumber',
                          tone: AppStatusTone.success,
                        );
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
                              color: const Color(0xFFA7F3D0).withValues(alpha: 0.9),
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
                            Icons.check_circle_rounded,
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

  Widget _buildAccountCard(BankAccountModel account) {
    final bankName = account.bankName.trim().isEmpty
        ? 'Ngân hàng'
        : account.bankName;

    final holderName = account.accountHolderName.trim().isEmpty
        ? 'Chưa có tên chủ tài khoản'
        : account.accountHolderName;

    return AppCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 24,
                child: Icon(Icons.account_balance_outlined),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bankName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account.maskedAccountNumber,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(holderName),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppStatusBadge(
                label: account.isLinked ? 'Đang liên kết' : 'Đã ngắt liên kết',
                tone: account.isLinked
                    ? AppStatusTone.success
                    : AppStatusTone.neutral,
                icon: account.isLinked
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
              ),
              if (account.isDefault)
                const AppStatusBadge(
                  label: 'Tài khoản mặc định',
                  tone: AppStatusTone.info,
                  icon: Icons.star_outline_rounded,
                ),
            ],
          ),
          const SizedBox(height: 18),

          CustomButton(
            text: account.isLinked ? 'Ngắt liên kết' : 'Kích hoạt lại',
            icon: account.isLinked
                ? Icons.link_off_rounded
                : Icons.refresh_rounded,
            variant: account.isLinked
                ? AppButtonVariant.secondary
                : AppButtonVariant.primary,
            onPressed: widget.viewModel.isCreatingBankLink
                ? null
                : () {
                    _prepareHostedLink(
                      purpose: account.isLinked
                          ? BankLinkPurpose.unlink
                          : BankLinkPurpose.reactivate,
                      account: account,
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final viewModel = widget.viewModel;
    final profile = viewModel.profile;
    final hasManualBank = profile?.bankAccountNumber != null &&
        profile!.bankAccountNumber!.trim().isNotEmpty;
    final accounts = viewModel.bankAccounts;

    if (viewModel.isLoadingBankAccounts && accounts.isEmpty && profile == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: LoadingIndicator(message: 'Đang tải tài khoản ngân hàng...'),
        ),
      );
    }

    if (viewModel.errorMessage != null && accounts.isEmpty && !hasManualBank) {
      return ErrorState(
        message: viewModel.errorMessage!,
        onRetry: () {
          viewModel.loadProfile();
          viewModel.loadBankAccounts();
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_activeHostedLink != null) ...[
          _buildHostedLinkCard(),
          const SizedBox(height: 20),
        ],

        if (hasManualBank) ...[
          SectionHeader(
            title: 'Tài khoản nhận tiền chính',
            subtitle: 'Đang dùng để tạo mã VietQR và thanh toán chia tiền',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: () {
                viewModel.loadProfile();
                viewModel.loadBankAccounts();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 14),

          _buildLuxuryBankCard(
            bankName: profile.bankName ?? _bankList[profile.bankBin] ?? 'Ngân hàng',
            accountNumber: profile.bankAccountNumber!,
            accountHolderName: profile.bankAccountName ?? profile.fullName ?? '',
            bankBin: profile.bankBin,
          ),
          const SizedBox(height: 16),

          const AppInlineNotice(
            message:
                'Tài khoản này được đặt làm tài khoản thụ hưởng mặc định. Khi chia tiền chuyến đi, các thành viên sẽ quét mã VietQR để chuyển tiền trực tiếp cho bạn.',
            tone: AppStatusTone.success,
          ),
          const SizedBox(height: 16),

          CustomButton(
            text: 'Chỉnh sửa tài khoản nhận tiền',
            icon: Icons.edit_note_rounded,
            onPressed: _showManualBankBottomSheet,
          ),
          const SizedBox(height: 10),

          CustomButton(
            text: 'Mở SePay Bank Hub (Tự động)',
            icon: Icons.sync_rounded,
            variant: AppButtonVariant.secondary,
            isLoading: viewModel.isCreatingBankLink,
            onPressed: viewModel.isCreatingBankLink
                ? null
                : () {
                    _prepareHostedLink(purpose: BankLinkPurpose.link);
                  },
          ),
        ] else if (accounts.isNotEmpty) ...[
          SectionHeader(
            title: 'Tài khoản đã liên kết',
            subtitle: '${accounts.length} tài khoản trong Bank Hub',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: viewModel.loadBankAccounts,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 16),

          ...accounts.expand(
            (account) => [
              _buildAccountCard(account),
              const SizedBox(height: 14),
            ],
          ),
          const SizedBox(height: 12),

          CustomButton(
            text: 'Thêm tài khoản ngân hàng',
            icon: Icons.account_balance_rounded,
            onPressed: _showManualBankBottomSheet,
          ),
        ] else ...[
          const AppInlineNotice(
            message:
                'FeelingTrip không yêu cầu bạn tự nhập hoặc lưu mật khẩu '
                'ngân hàng. Tài khoản chỉ dùng để nhận tiền và tạo mã VietQR.',
            tone: AppStatusTone.info,
          ),
          const SizedBox(height: 24),

          SectionHeader(
            title: 'Tài khoản ngân hàng',
            subtitle: 'Bạn chưa thiết lập tài khoản nhận tiền nào.',
            action: IconButton(
              tooltip: 'Tải lại',
              onPressed: () {
                viewModel.loadProfile();
                viewModel.loadBankAccounts();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          const SizedBox(height: 16),

          AppCard(
            outlined: true,
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 38,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chưa có tài khoản ngân hàng',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thiết lập tài khoản ngân hàng để nhận tiền chia sẻ chi phí và tự động tạo mã VietQR khi quyết toán chuyến đi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
                ),
                const SizedBox(height: 20),
                CustomButton(
                  text: 'Thiết lập tài khoản ngân hàng',
                  icon: Icons.account_balance_rounded,
                  onPressed: _showManualBankBottomSheet,
                ),
                const SizedBox(height: 10),
                CustomButton(
                  text: 'Kết nối SePay Bank Hub (Tự động)',
                  icon: Icons.add_link_rounded,
                  variant: AppButtonVariant.secondary,
                  isLoading: viewModel.isCreatingBankLink,
                  onPressed: viewModel.isCreatingBankLink
                      ? null
                      : () {
                          _prepareHostedLink(purpose: BankLinkPurpose.link);
                        },
                ),
              ],
            ),
          ),
        ],

        if (hasManualBank && accounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(
            title: 'Tài khoản Bank Hub kết nối tự động',
            subtitle: 'Dùng cho gạch nợ tự động SePay B2B',
          ),
          const SizedBox(height: 12),
          ...accounts.expand(
            (account) => [
              _buildAccountCard(account),
              const SizedBox(height: 14),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (context, _) {
        return AppScaffold(
          title: 'Tài khoản ngân hàng',
          scrollable: true,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: LoadingOverlay(
                isLoading: widget.viewModel.isCreatingBankLink,
                message: 'Đang tạo liên kết bảo mật...',
                child: _buildContent(),
              ),
            ),
          ),
        );
      },
    );
  }
}
