import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../models/expense_model.dart';
import '../viewmodels/expense_viewmodel.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.viewModel,
    this.plannedCost,
  });
  final ExpenseViewModel viewModel;
  final PlannedCost? plannedCost;
  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController(), _amount = TextEditingController();
  final Map<String, TextEditingController> _shares = {};
  final Set<String> _selected = {};
  String? _payer;
  String _category = 'FOOD', _split = 'EQUAL';
  DateTime _date = DateTime.now();
  bool _payerInitialized = false;
  @override
  void initState() {
    super.initState();
    for (final member in widget.viewModel.trip!.members.where(
      (m) => m.membershipStatus == 'ACTIVE',
    )) {
      _selected.add(member.userId);
      _shares[member.userId] = TextEditingController();
    }
    if (_selected.isNotEmpty) _payer = _selected.first;
    final plan = widget.plannedCost;
    if (plan != null) {
      _title.text = plan.title;
      _amount.text = VndInputFormatter.format('${plan.amount}');
      _category = plan.expenseCategory;
      _date = plan.date ?? _date;
    }
    widget.viewModel.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_payerInitialized) {
      _payerInitialized = true;
      final id = AuthScope.of(context).user?.id;
      if (_selected.contains(id)) _payer = id;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_changed);
    _title.dispose();
    _amount.dispose();
    for (final controller in _shares.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _total => VndInputFormatter.parse(_amount.text) ?? 0;
  double? _percent(String id) =>
      double.tryParse(_shares[id]!.text.replaceAll(',', '.'));
  String? get _splitError {
    if (_selected.isEmpty) return 'Chọn ít nhất một người cùng chia tiền.';
    if (_split == 'EXACT' &&
        _selected.fold<int>(
              0,
              (sum, id) =>
                  sum + (VndInputFormatter.parse(_shares[id]!.text) ?? 0),
            ) !=
            _total) {
      return 'Tổng tiền chia phải bằng ${AppUtils.formatCurrency(_total)}.';
    }
    if (_split == 'PERCENTAGE' &&
        _selected.fold<int>(
              0,
              (sum, id) => sum + ((_percent(id) ?? 0) * 100).round(),
            ) !=
            10000) {
      return 'Tổng tỷ lệ phải bằng 100%.';
    }
    return null;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_key.currentState!.validate() ||
        _splitError != null ||
        _payer == null) {
      AppFeedback.show(
        context,
        _splitError ?? 'Kiểm tra thông tin khoản chi.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    final splits = _selected
        .map(
          (id) => {
            'userId': id,
            if (_split == 'EXACT')
              'amountOwed': VndInputFormatter.parse(_shares[id]!.text),
            if (_split == 'PERCENTAGE') 'percentage': _percent(id),
          },
        )
        .toList();
    final saved = await widget.viewModel.create({
      'title': _title.text.trim(),
      'amount': _total,
      'payerId': _payer,
      'category': _category,
      'splitType': _split,
      'splits': splits,
      'expenseDate': DateUtils.dateOnly(_date).toIso8601String(),
      if (widget.plannedCost != null) 'itineraryItemId': widget.plannedCost!.id,
    });
    if (mounted && saved) {
      KoharuScope.maybeOf(context)?.complete('expense.save');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final members = vm.trip!.members
        .where((m) => m.membershipStatus == 'ACTIVE')
        .toList();
    return AppScaffold(
      title: 'Thêm khoản chi',
      subtitle: vm.trip!.name,
      scrollable: true,
      bottomAction: CustomButton(
        guideId: 'expense.save',
        text: 'Lưu và xem trả nợ tối ưu',
        isLoading: vm.saving,
        onPressed: vm.saving || members.isEmpty ? null : _save,
      ),
      body: AbsorbPointer(
        absorbing: vm.saving,
        child: Form(
          key: _key,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.plannedCost != null) ...[
                AppInlineNotice(
                  message:
                      'Khoản chi cho ${widget.plannedCost!.title}, ngày ${widget.plannedCost!.dayNumber}. Nhập số tiền thực tế đã trả; khoản dự kiến sẽ được thay thế trong tổng dự báo.',
                ),
                const SizedBox(height: 16),
              ],
              const SectionHeader(
                title: 'Ai đã trả khoản này?',
                subtitle:
                    'Ghi tổng tiền đã chi, sau đó chọn những người cùng chia.',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'Tên khoản chi',
                guideId: 'expense.form',
                hint: 'Ví dụ: Bữa tối tại Hội An',
                controller: _title,
                inputFormatters: [LengthLimitingTextInputFormatter(255)],
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Nhập tên khoản chi.',
              ),
              const SizedBox(height: 14),
              AppMoneyField(
                label: 'Tổng số tiền',
                controller: _amount,
                allowZero: true,
                maxAmount: 9999999999999,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              AppDropdownField<String>(
                label: 'Người đã trả tiền',
                value: _payer,
                items: members
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.userId,
                        child: Text(m.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _payer = value),
              ),
              const SizedBox(height: 14),
              AppDropdownField<String>(
                label: 'Danh mục',
                value: _category,
                items: expenseCategories.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 14),
              AppSelectionField(
                label: 'Ngày chi',
                value: AppUtils.formatDate(_date),
                icon: Icons.calendar_month_outlined,
                onTap: () async {
                  final picked = await AppPickers.date(
                    context,
                    initial: _date,
                    first: DateTime(2000),
                    last: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null && mounted) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Chia cho những ai?',
                subtitle: 'Người trả tiền có thể cùng chia hoặc chỉ trả hộ.',
              ),
              const SizedBox(height: 12),
              AppChoiceChips<String>(
                options: splitTypes,
                selected: {_split},
                onChanged: (value) => setState(() {
                  _split = value;
                  for (final controller in _shares.values) {
                    controller.clear();
                  }
                }),
              ),
              const SizedBox(height: 16),
              if (members.isEmpty)
                const AppInlineNotice(
                  message:
                      'Chuyến đi chưa có thành viên đang hoạt động. Hãy tải lại thông tin chuyến đi.',
                  tone: AppStatusTone.warning,
                ),
              for (final member in members)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(member.displayName),
                          value: _selected.contains(member.userId),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              _selected.add(member.userId);
                            } else {
                              _selected.remove(member.userId);
                            }
                          }),
                        ),
                        if (_selected.contains(member.userId) &&
                            _split == 'EQUAL')
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Phần chịu: ${AppUtils.formatCurrency(_total ~/ _selected.length + (_selected.toList().indexOf(member.userId) < _total % _selected.length ? 1 : 0))}',
                            ),
                          ),
                        if (_selected.contains(member.userId) &&
                            _split != 'EQUAL')
                          CustomTextField(
                            label: _split == 'EXACT'
                                ? 'Số tiền phải chịu'
                                : 'Tỷ lệ (%)',
                            controller: _shares[member.userId],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: _split == 'EXACT'
                                ? [VndInputFormatter()]
                                : [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]'),
                                    ),
                                  ],
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              if (_split == 'EXACT') {
                                final amount = VndInputFormatter.parse(
                                  value ?? '',
                                );
                                return amount == null || amount > 9999999999999
                                    ? 'Nhập số tiền hợp lệ.'
                                    : null;
                              }
                              final percent = _percent(member.userId);
                              if (percent == null ||
                                  percent < 0 ||
                                  percent > 100 ||
                                  !RegExp(
                                    r'^\d+(?:[.,]\d{1,2})?$',
                                  ).hasMatch(value ?? '')) {
                                return 'Nhập từ 0 đến 100, tối đa 2 số thập phân.';
                              }
                              return null;
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              if (_splitError != null)
                AppInlineNotice(
                  message: _splitError!,
                  tone: AppStatusTone.warning,
                ),
              const SizedBox(height: 12),
              const AppInlineNotice(
                message:
                    'Sau khi lưu, hệ thống tự gộp nợ chéo và hiển thị ai cần chuyển tiền cho ai. QR đang dùng có thể được thay thế khi công nợ thay đổi.',
              ),
              if (vm.error != null) ...[
                const SizedBox(height: 12),
                AppInlineNotice(message: vm.error!, tone: AppStatusTone.error),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
