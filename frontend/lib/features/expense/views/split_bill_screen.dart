import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../trip/models/trip_model.dart';
import '../../trip/repositories/api_trip_repository.dart';
import '../../trip/repositories/trip_repository.dart';
import '../../trip/views/widgets/trip_widgets.dart';
import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';
import '../viewmodels/expense_viewmodel.dart';
import 'expense_form_screen.dart';
import 'payment_screen.dart';

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({
    super.key,
    this.tripId,
    this.repository,
    this.tripRepository,
    this.itineraryItemId,
  });
  final String? tripId;
  final ExpenseRepository? repository;
  final TripRepository? tripRepository;
  final String? itineraryItemId;
  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen> {
  ExpenseViewModel? _vm;
  List<TripModel> _trips = [];
  String? _chooserError;
  bool _choosing = false;
  String _tab = 'expenses';
  bool _openedRequestedItem = false;
  TripRepository get _tripRepository =>
      widget.tripRepository ?? ApiTripRepository();
  @override
  void initState() {
    super.initState();
    if (widget.tripId != null) {
      _select(widget.tripId!);
    } else {
      _loadTrips();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
    if (mounted &&
        !_openedRequestedItem &&
        widget.itineraryItemId != null &&
        _vm?.data != null &&
        _vm?.trip != null) {
      _openedRequestedItem = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final items = _vm!.data!.plannedCosts.where(
          (p) => p.id == widget.itineraryItemId,
        );
        if (items.isEmpty) {
          AppFeedback.show(
            context,
            'Hoạt động đã thay đổi hoặc bị xóa. Hãy tải lại lịch trình.',
            tone: AppStatusTone.warning,
          );
        } else if (items.first.expenseId != null) {
          AppFeedback.show(
            context,
            'Hoạt động đã có khoản chi trong danh sách bên dưới.',
          );
        } else {
          setState(() => _tab = 'planned');
          _create(plannedCost: items.first);
        }
      });
    }
  }

  void _select(String id) {
    _vm =
        ExpenseViewModel(
            tripId: id,
            repository: widget.repository,
            tripRepository: _tripRepository,
          )
          ..addListener(_changed)
          ..load();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _choosing = true;
      _chooserError = null;
    });
    try {
      final page = await _tripRepository.getMyTrips(includeHistory: false);
      if (mounted) setState(() => _trips = page.items);
    } catch (e) {
      if (mounted) {
        setState(
          () => _chooserError = e is ApiException
              ? e.message
              : 'Không tải được chuyến đi. Kiểm tra kết nối và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  void dispose() {
    _vm?.removeListener(_changed);
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _create({PlannedCost? plannedCost}) async {
    final vm = _vm!;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ExpenseFormScreen(viewModel: vm, plannedCost: plannedCost),
      ),
    );
    if (!mounted || saved != true) return;
    setState(() => _tab = 'settlements');
    AppFeedback.show(
      context,
      vm.notice ??
          (vm.error != null
              ? 'Đã lưu khoản chi. Hãy tải lại để xem công nợ.'
              : 'Đã chia tiền. Phương án trả nợ tối ưu nằm bên dưới.'),
      tone: vm.notice != null || vm.error != null
          ? AppStatusTone.warning
          : AppStatusTone.success,
    );
  }

  Future<void> _budget() async {
    final vm = _vm!;
    final controller = TextEditingController(
      text: VndInputFormatter.format('${vm.data!.budget}'),
    );
    final key = GlobalKey<FormState>();
    final amount = await AppBottomSheet.show<int>(
      context,
      title: 'Ngân sách chuyến đi',
      child: Form(
        key: key,
        child: Column(
          children: [
            AppMoneyField(
              label: 'Ngân sách dự kiến',
              controller: controller,
              maxAmount: 9999999999999,
            ),
            const SizedBox(height: 12),
            const Text(
              'Có thể đặt bằng 0 hoặc thấp hơn tổng đã chi. Các khoản chi và công nợ giữ nguyên.',
            ),
            const SizedBox(height: 20),
            Builder(
              builder: (sheetContext) => CustomButton(
                text: 'Lưu ngân sách',
                onPressed: () {
                  if (key.currentState!.validate()) {
                    Navigator.pop(
                      sheetContext,
                      VndInputFormatter.parse(controller.text),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (amount == null || !mounted) return;
    final success = await vm.updateBudget(amount);
    if (mounted && success) {
      AppFeedback.show(
        context,
        'Đã cập nhật ngân sách.',
        tone: AppStatusTone.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    return AppScaffold(
      title: 'Chi phí chuyến đi',
      subtitle: vm?.trip?.name,
      actions: [
        if (vm != null)
          AppIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Tải lại chi phí',
            onPressed: vm.loading || vm.saving ? null : vm.load,
          ),
      ],
      bottomAction: vm?.data != null && vm?.trip != null
          ? CustomButton(
              text: 'Thêm khoản chi',
              icon: Icons.add_rounded,
              isLoading: vm!.saving,
              onPressed: vm.saving || vm.loading ? null : _create,
            )
          : null,
      body: vm == null ? _chooser() : _content(vm),
    );
  }

  Widget _chooser() {
    if (_choosing) {
      return const Center(
        child: LoadingIndicator(message: 'Đang tải chuyến đi...'),
      );
    }
    if (_chooserError != null) {
      return ErrorState(message: _chooserError!, onRetry: _loadTrips);
    }
    if (_trips.isEmpty) {
      return const SingleChildScrollView(
        child: EmptyStateWidget(
          title: 'Chưa có chuyến đi',
          message: 'Tạo hoặc tham gia một chuyến đi để bắt đầu ghi chi phí.',
          icon: Icons.luggage_outlined,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Bạn muốn chia tiền cho chuyến nào?',
          subtitle: 'Mỗi chuyến đi có ngân sách và công nợ riêng.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.separated(
            itemCount: _trips.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (_, i) => TripCard(
              trip: _trips[i],
              onTap: () => setState(() => _select(_trips[i].id)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(ExpenseViewModel vm) {
    if (vm.data == null) {
      if (vm.error != null) {
        return ErrorState(message: vm.error!, onRetry: vm.load);
      }
      return const Center(
        child: LoadingIndicator(message: 'Đang tải chi phí và công nợ...'),
      );
    }
    final data = vm.data!;
    return Column(
      children: [
        _buildTabBar(data, vm),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: vm.load,
            child: ListView(
              key: ValueKey(_tab),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
              children: [
                if (vm.loading) const LinearProgressIndicator(),
                if (vm.error != null) ...[
                  AppInlineNotice(
                    message: vm.error!,
                    tone: AppStatusTone.error,
                  ),
                  const SizedBox(height: 12),
                ],
                if (vm.notice != null) ...[
                  AppInlineNotice(
                    message: vm.notice!,
                    tone: AppStatusTone.warning,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_tab == 'expenses' || _tab == 'planned') ...[
                  _buildBudgetOverviewCard(data, vm),
                  const SizedBox(height: 20),
                ],
                if (_tab == 'expenses') ..._expenses(data),
                if (_tab == 'planned') ..._planned(vm),
                if (_tab == 'settlements') ..._settlements(vm),
                if (_tab == 'history') ...[
                  if (vm.paid.isEmpty)
                    const EmptyStateWidget(
                      title: 'Chưa có khoản đã thanh toán',
                      message:
                          'Các khoản được hệ thống xác nhận sẽ xuất hiện tại đây.',
                      icon: Icons.receipt_long_outlined,
                    ),
                  for (final item in vm.paid) _settlementCard(vm, item),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(ExpenseSnapshot data, ExpenseViewModel vm) {
    final pendingPlannedCount =
        data.plannedCosts.where((p) => p.expenseId == null).length;
    final tabs = [
      _TabDef('expenses', 'Khoản chi', data.expenses.length, Icons.receipt_long_rounded),
      _TabDef('planned', 'Dự kiến lịch trình', pendingPlannedCount, Icons.calendar_month_rounded),
      _TabDef('settlements', 'Quyết toán', vm.open.length, Icons.payments_outlined),
      _TabDef('history', 'Đã thanh toán', vm.paid.length, Icons.check_circle_outline_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Row(
        children: tabs.map((t) {
          final isSelected = _tab == t.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _tab = t.id),
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t.icon,
                      size: 15,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    if (t.count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${t.count}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBudgetOverviewCard(ExpenseSnapshot data, ExpenseViewModel vm) {
    final bool isOverBudget = data.remaining < 0;
    final bool hasBudget = data.budget > 0;
    final double percentUsed =
        hasBudget ? (data.spent / data.budget).clamp(0.0, 2.0) : 0.0;
    final int percentInt = (percentUsed * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Nhãn & Nút sửa ngân sách
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'TỔNG QUAN NGÂN SÁCH',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (vm.trip?.isLeader == true)
                InkWell(
                  onTap: vm.saving ? null : _budget,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 13, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Sửa ngân sách',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Tổng thực tế đã chi
          const Text(
            'Tổng thực tế đã chi',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  AppUtils.formatCurrency(data.spent),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              // Status Badge
              if (hasBudget)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isOverBudget
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOverBudget
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFA7F3D0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOverBudget
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 13,
                        color: isOverBudget
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF059669),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOverBudget
                            ? 'Vượt ${AppUtils.formatCurrency(-data.remaining)}'
                            : 'Còn ${AppUtils.formatCurrency(data.remaining)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isOverBudget
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (hasBudget) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: percentUsed.clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFFE2E8F0),
                  color: isOverBudget
                      ? const Color(0xFFEF4444)
                      : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ngân sách: ${AppUtils.formatCurrency(data.budget)}',
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
                Text(
                  '$percentInt% hạn mức',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isOverBudget
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Khối dự báo cả chuyến đi
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.query_stats_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Dự báo tài chính cả chuyến',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    Tooltip(
                      message:
                          'Dự báo = Đã chi thực tế + Chi phí các điểm lịch trình chưa ghi nhận.',
                      child: const Icon(
                        Icons.info_outline_rounded,
                        size: 15,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dự kiến chi thêm',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppUtils.formatCurrency(data.pendingEstimated),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tổng dự báo',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppUtils.formatCurrency(data.projected),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (data.projectedRemaining < 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.arrow_upward_rounded,
                        size: 13,
                        color: Color(0xFFDC2626),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Dự báo vượt ngân sách ${AppUtils.formatCurrency(-data.projectedRemaining)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _expenses(ExpenseSnapshot data) => [
    const SectionHeader(
      title: 'Các khoản chi của nhóm',
      subtitle: 'Mở từng khoản để xem mỗi người được chia bao nhiêu.',
    ),
    const SizedBox(height: 12),
    if (data.expenses.isEmpty)
      const EmptyStateWidget(
        title: 'Bắt đầu ghi chi phí',
        message:
            'Thêm khoản chi, chọn người đã trả và những người cùng chia tiền.',
        icon: Icons.receipt_long_outlined,
      ),
    for (final expense in data.expenses) ...[
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              expense.title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '${expenseCategories[expense.category] ?? expense.category} · ${expense.payerName} trả',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            trailing: Text(
              AppUtils.formatCurrency(expense.amount),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),
              if (expense.date != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 13,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppUtils.formatDate(expense.date!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final share in expense.splits)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${share['fullName'] ?? 'Thành viên'}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        AppUtils.formatCurrency(vnd(share['amountOwed'])),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  ];

  List<Widget> _planned(ExpenseViewModel vm) => [
    const SectionHeader(
      title: 'Chi phí theo lịch trình',
      subtitle:
          'Ghi nhận khi đã trả tiền để liên kết với khoản chi thực tế, tránh tính trùng.',
    ),
    const SizedBox(height: 12),
    if (vm.data!.plannedCosts.isEmpty)
      const AppInlineNotice(
        message:
            'Chưa có hoạt động trong lịch trình. Khoản chi ngoài lịch trình vẫn ghi bằng Thêm khoản chi.',
      ),
    for (final plan in vm.data!.plannedCosts) ...[
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ngày ${plan.dayNumber}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.sell_outlined,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Dự kiến: ${AppUtils.formatCurrency(plan.amount)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                if (plan.expenseId != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 12,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Đã chi ${AppUtils.formatCurrency(plan.actualAmount ?? 0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Text(
                      'Chưa ghi chi',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
              ],
            ),
            if (plan.expenseId != null) ...[
              const SizedBox(height: 10),
              CustomButton(
                text: 'Xem các khoản đã chi',
                variant: AppButtonVariant.text,
                icon: Icons.arrow_forward_rounded,
                onPressed: () => setState(() => _tab = 'expenses'),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Ghi nhận chi',
                      icon: Icons.add_circle_outline_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: vm.saving || vm.loading
                          ? null
                          : () => _create(plannedCost: plan),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomButton(
                      text: 'Ghép có sẵn',
                      icon: Icons.link_rounded,
                      variant: AppButtonVariant.secondary,
                      onPressed: vm.saving || vm.loading
                          ? null
                          : () => _linkExisting(vm, plan),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ],
  ];

  Future<void> _linkExisting(ExpenseViewModel vm, PlannedCost plan) async {
    final expenses = vm.data!.expenses
        .where((e) => e.itineraryItemId == null)
        .toList();
    if (expenses.isEmpty) {
      AppFeedback.show(
        context,
        'Chưa có khoản chi chưa liên kết. Dùng Ghi nhận khoản chi khi đã trả tiền.',
        tone: AppStatusTone.info,
      );
      return;
    }
    final id = await AppBottomSheet.show<String>(
      context,
      title: 'Liên kết với ${plan.title}',
      child: Column(
        children: [
          const AppInlineNotice(
            message:
                'Chọn đúng khoản đã trả cho hoạt động này. Liên kết không thêm tiền, không thay đổi người trả hoặc phần chia.',
          ),
          const SizedBox(height: 12),
          for (final expense in expenses)
            ListTile(
              title: Text(expense.title),
              subtitle: Text(
                '${expense.payerName} · ${AppUtils.formatCurrency(expense.amount)}',
              ),
              onTap: () => Navigator.pop(context, expense.id),
            ),
        ],
      ),
    );
    if (id == null || !mounted) return;
    final ok = await vm.linkExpense(id, plan.id);
    if (mounted && ok) {
      AppFeedback.show(
        context,
        'Đã liên kết khoản chi; dự báo đã cập nhật.',
        tone: AppStatusTone.success,
      );
    }
  }

  List<Widget> _settlements(ExpenseViewModel vm) => [
    Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Phương án trả nợ tối ưu (Min Cash Flow)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${vm.open.length} giao dịch còn lại · Tổng nợ: ${AppUtils.formatCurrency(vm.open.fold<int>(0, (sum, item) => sum + item.amount))}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Thuật toán rút gọn nợ chéo thành số lượng giao dịch tối thiểu. Người nhận có thể khác người trả hóa đơn.',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          CustomButton(
            text: 'Tính lại phương án trả nợ',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: vm.saving
                ? null
                : () async {
                    final confirmed = await AppConfirmDialog.show(
                      context,
                      title: 'Tính lại công nợ?',
                      message:
                          'Nếu công nợ thay đổi, QR cũ sẽ hết hiệu lực. Hãy báo các thành viên ngừng dùng QR cũ trước khi tính lại.',
                      confirmLabel: 'Tính lại',
                    );
                    if (confirmed) await vm.optimize();
                  },
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    if (vm.open.isEmpty)
      const AppInlineNotice(
        message:
            'Hiện không có khoản chuyển đang chờ. Sau khi thêm khoản chi, phương án tối ưu sẽ được tính tự động.',
      ),
    for (final item in vm.open) _settlementCard(vm, item),
    const SizedBox(height: 12),
    Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text(
            'Bảng cân đối từng người',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Đã trả, phần phải chịu và số dư còn lại',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final balance in vm.data!.balances)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${balance['fullName']}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Đã trả ${AppUtils.formatCurrency(vnd(balance['totalPaid']))} · Phần chịu ${AppUtils.formatCurrency(vnd(balance['totalOwed']))}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      vnd(balance['netBalance']) < 0
                          ? 'Cần trả ${AppUtils.formatCurrency(-vnd(balance['netBalance']))}'
                          : 'Còn nhận ${AppUtils.formatCurrency(vnd(balance['netBalance']))}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: vnd(balance['netBalance']) < 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  ];

  Widget _settlementCard(ExpenseViewModel vm, Settlement item) {
    final userId = AuthScope.of(context).user?.id;
    final debtor = userId == item.fromId;
    final creditor = userId == item.toId;
    final isPaid = item.status == 'PAID';
    final isReported = item.status == 'REPORTED';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPaid
                ? const Color(0xFFA7F3D0)
                : (isReported
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Row From -> To
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text(
                          item.fromName.isNotEmpty
                              ? item.fromName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.fromName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFF0FDF4),
                        child: Text(
                          item.toName.isNotEmpty
                              ? item.toName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.toName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),

            // Số tiền & Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppUtils.formatCurrency(item.amount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isPaid
                        ? const Color(0xFF059669)
                        : AppColors.textPrimary,
                    decoration: isPaid ? TextDecoration.lineThrough : null,
                  ),
                ),
                AppStatusBadge(
                  label: isPaid
                      ? 'Đã thanh toán'
                      : isReported
                      ? 'Đã báo chuyển'
                      : debtor
                      ? 'Bạn cần trả'
                      : creditor
                      ? 'Bạn sẽ nhận'
                      : 'Chờ thanh toán',
                  tone: isPaid
                      ? AppStatusTone.success
                      : isReported
                      ? AppStatusTone.warning
                      : AppStatusTone.info,
                ),
              ],
            ),

            if (item.paidAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Xác nhận ngày ${AppUtils.formatDate(item.paidAt!)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],

            if (item.isOpen) ...[
              const SizedBox(height: 14),
              CustomButton(
                text: debtor ? 'Xem mã VietQR thanh toán' : 'Xem trạng thái',
                icon: debtor
                    ? Icons.qr_code_2_rounded
                    : Icons.info_outline_rounded,
                variant: debtor
                    ? AppButtonVariant.primary
                    : AppButtonVariant.secondary,
                onPressed: vm.saving
                    ? null
                    : () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(
                              settlement: item,
                              repository: vm.repository,
                            ),
                          ),
                        );
                        await vm.load();
                      },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TabDef {
  final String id;
  final String label;
  final int count;
  final IconData icon;

  const _TabDef(this.id, this.label, this.count, this.icon);
}
