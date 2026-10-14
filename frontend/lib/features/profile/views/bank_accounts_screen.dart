import 'package:flutter/material.dart';
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
      if (widget.viewModel.profile == null) {
        widget.viewModel.loadProfile();
      }
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
              CircleAvatar(
                radius: 24,
                child: const Icon(Icons.account_balance_outlined),
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
    final accounts = viewModel.bankAccounts;

    if (viewModel.isLoadingBankAccounts && accounts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: LoadingIndicator(message: 'Đang tải tài khoản ngân hàng...'),
        ),
      );
    }

    if (viewModel.errorMessage != null && accounts.isEmpty) {
      return ErrorState(
        message: viewModel.errorMessage!,
        onRetry: viewModel.loadBankAccounts,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppInlineNotice(
          message:
              'FeelingTrip không yêu cầu bạn tự nhập hoặc lưu mật khẩu '
              'ngân hàng. Việc liên kết được thực hiện trên trang bảo mật '
              'của SePay Bank Hub.',
          tone: AppStatusTone.info,
        ),

        if (_activeHostedLink != null) ...[
          const SizedBox(height: 16),
          _buildHostedLinkCard(),
        ],

        const SizedBox(height: 24),

        SectionHeader(
          title: 'Tài khoản đã liên kết',
          subtitle: accounts.isEmpty
              ? 'Bạn chưa liên kết tài khoản ngân hàng nào.'
              : '${accounts.length} tài khoản trong Bank Hub',
          action: IconButton(
            tooltip: 'Tải lại',
            onPressed: viewModel.isLoadingBankAccounts
                ? null
                : viewModel.loadBankAccounts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
        const SizedBox(height: 16),

        if (accounts.isEmpty)
          AppCard(
            outlined: true,
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 52),
                const SizedBox(height: 12),
                Text(
                  'Chưa có tài khoản ngân hàng',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Thiết lập tài khoản ngân hàng để nhận tiền chia sẻ chi phí và tự động tạo mã VietQR.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Thiết lập tài khoản ngân hàng',
                  icon: Icons.account_balance_rounded,
                  onPressed: _showManualBankBottomSheet,
                ),
              ],
            ),
          )
        else
          ...accounts.expand(
            (account) => [
              _buildAccountCard(account),
              const SizedBox(height: 14),
            ],
          ),

        const SizedBox(height: 12),

        CustomButton(
          text: 'Cập nhật tài khoản nhận tiền',
          icon: Icons.edit_note_rounded,
          onPressed: _showManualBankBottomSheet,
        ),
        const SizedBox(height: 10),

        CustomButton(
          text: 'Mở SePay Bank Hub (Nâng cao)',
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
