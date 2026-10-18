import 'package:flutter/material.dart';

import '../../../shared/ui_kit.dart';
import '../models/profile_form_data.dart';
import '../viewmodels/profile_viewmodel.dart';

/// Feature-specific form, built from the team's shared UI kit.
class BankAccountFormSheet extends StatefulWidget {
  const BankAccountFormSheet({super.key, required this.viewModel});
  final ProfileViewModel viewModel;

  @override
  State<BankAccountFormSheet> createState() => _BankAccountFormSheetState();
}

class _BankAccountFormSheetState extends State<BankAccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _number;
  late final TextEditingController _holder;
  late final Map<String, String> _banks;
  late String _bin;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.viewModel.profile;
    _bin = profile?.bankBin ?? '970422';
    _banks = {
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
    // Preserve existing banks outside this list instead of silently changing BIN.
    if (!_banks.containsKey(_bin)) {
      _banks[_bin] = profile?.bankName ?? 'Ngân hàng đang lưu (BIN $_bin)';
    }
    _number = TextEditingController(text: profile?.bankAccountNumber ?? '');
    _holder = TextEditingController(text: profile?.bankAccountName ?? '');
  }

  @override
  void dispose() {
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving ||
        widget.viewModel.isSavingProfile ||
        !_formKey.currentState!.validate()) {
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(_bin)) {
      setState(
        () => _error = 'BIN ngân hàng không hợp lệ. Hãy chọn lại ngân hàng.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final success = await widget.viewModel.updateProfile(
      data: ProfileFormData.bankAccount(
        bankBin: _bin,
        bankName: _banks[_bin]!,
        bankAccountNumber: _number.text.trim(),
        bankAccountName: _holder.text.trim().toUpperCase(),
      ),
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error =
            widget.viewModel.errorMessage ??
            'Không lưu được thông tin. Hãy thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thông tin nhận tiền',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const AppInlineNotice(
                message:
                    'Đây là thông tin bạn tự khai để nhận tiền/VietQR, không xác nhận quyền sở hữu và không tự liên kết Bank Hub. Kiểm tra kỹ trước khi lưu.',
                tone: AppStatusTone.info,
              ),
              const SizedBox(height: 16),
              AppDropdownField<String>(
                label: 'Ngân hàng',
                enabled: !_saving,
                value: _bin,
                items: _banks.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _bin = value);
                      },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Số tài khoản',
                controller: _number,
                enabled: !_saving,
                keyboardType: TextInputType.text,
                prefixIcon: Icons.pin_outlined,
                validator: (value) =>
                    RegExp(r'^[a-zA-Z0-9]{1,50}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Nhập 1–50 chữ/số, không có khoảng trắng',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Tên chủ tài khoản',
                hint: 'Ví dụ: NGUYEN VAN A',
                controller: _holder,
                enabled: !_saving,
                prefixIcon: Icons.person_outline,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  return text.isEmpty || text.length > 100
                      ? 'Nhập tên chủ tài khoản (tối đa 100 ký tự)'
                      : null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AppInlineNotice(message: _error!, tone: AppStatusTone.error),
              ],
              const SizedBox(height: 24),
              CustomButton(
                text: 'Lưu thông tin nhận tiền',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
