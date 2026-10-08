import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';

// ==============================================================================
// MÔ HÌNH DỮ LIỆU SPLIT BILL & THUẬT TOÁN TỐI ƯU CÔNG NỢ (MIN CASH FLOW)
// Phụ trách thiết kế & nghiệp vụ: Long Nhật
// ==============================================================================

enum SplitType {
  equal('Chia đều', 'EQUAL', Icons.balance_rounded),
  exact('Số tiền cụ thể', 'EXACT', Icons.pin_rounded),
  percentage('Theo tỷ lệ %', 'PERCENTAGE', Icons.pie_chart_outline_rounded);

  final String label;
  final String code;
  final IconData icon;
  const SplitType(this.label, this.code, this.icon);
}

enum ExpenseCategory {
  food('Ăn uống', Icons.restaurant_rounded, Color(0xFFEF4444)),
  hotel('Khách sạn', Icons.hotel_rounded, Color(0xFF3B82F6)),
  transport('Di chuyển', Icons.directions_car_rounded, Color(0xFFF59E0B)),
  tickets('Vé tham quan', Icons.confirmation_number_rounded, Color(0xFF8B5CF6)),
  cafe('Cafe & Bar', Icons.local_cafe_rounded, Color(0xFFEC4899)),
  shopping('Mua sắm', Icons.shopping_bag_rounded, Color(0xFF10B981)),
  other('Khác', Icons.receipt_long_rounded, Color(0xFF6B7280));

  final String label;
  final IconData icon;
  final Color color;
  const ExpenseCategory(this.label, this.icon, this.color);
}

class GroupMember {
  final String id;
  final String name;
  final String role;
  final String avatarUrl;
  final String bankName;
  final String bankBin;
  final String accountNumber;
  final String accountHolder;

  const GroupMember({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarUrl,
    required this.bankName,
    required this.bankBin,
    required this.accountNumber,
    required this.accountHolder,
  });
}

class ExpenseItem {
  final String id;
  final String title;
  final int amount;
  final ExpenseCategory category;
  final String payerId;
  final SplitType splitType;
  final Map<String, int> shares; // userId -> amount
  final DateTime date;

  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.payerId,
    required this.splitType,
    required this.shares,
    required this.date,
  });
}

class SettlementTransaction {
  final String id;
  final String fromUserId;
  final String toUserId;
  final int amount;
  String status; // 'PENDING' | 'REPORTED' | 'PAID'
  final String note;

  SettlementTransaction({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
    this.status = 'PENDING',
    required this.note,
  });
}

// ==============================================================================
// GIAO DIỆN CHÍNH: MÔ PHỎNG QUẢN LÝ CHI TIÊU & CHIA TIỀN (SPLIT BILL SIMULATOR)
// Phong cách: Mediterranean Coastal Travel (Tone biển & cam đất thanh lịch)
// ==============================================================================

class SplitBillScreen extends StatefulWidget {
  const SplitBillScreen({super.key});

  @override
  State<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends State<SplitBillScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Dữ liệu thành viên mẫu trong chuyến đi
  final List<GroupMember> _members = const [
    GroupMember(
      id: 'user-nhat',
      name: 'Long Nhật',
      role: 'Trưởng nhóm',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      bankName: 'VietinBank',
      bankBin: '970415',
      accountNumber: '108876543210',
      accountHolder: 'TRAN LONG NHAT',
    ),
    GroupMember(
      id: 'user-phu',
      name: 'Duy Phú',
      role: 'Thành viên',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      bankName: 'MB Bank',
      bankBin: '970422',
      accountNumber: '0988776655',
      accountHolder: 'NGUYEN DUY PHU',
    ),
    GroupMember(
      id: 'user-thanh',
      name: 'Tạ Thành',
      role: 'Thành viên',
      avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
      bankName: 'Techcombank',
      bankBin: '970407',
      accountNumber: '19036789123',
      accountHolder: 'TA THANH',
    ),
    GroupMember(
      id: 'user-tung',
      name: 'Thanh Tùng',
      role: 'Thành viên',
      avatarUrl: 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=150',
      bankName: 'Vietcombank',
      bankBin: '970436',
      accountNumber: '001100456789',
      accountHolder: 'NGUYEN THANH TUNG',
    ),
  ];

  // Ngân sách dự kiến của chuyến đi
  final int _estimatedBudget = 12000000;

  // Danh sách các khoản chi ban đầu (Mock Scenario thực tế)
  late List<ExpenseItem> _expenses;

  // Trạng thái tối ưu hóa dòng tiền (Min Cash Flow)
  bool _isOptimized = false;
  List<SettlementTransaction> _settlements = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _resetToDefaultMockData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _resetToDefaultMockData() {
    setState(() {
      _expenses = [
        ExpenseItem(
          id: 'exp-1',
          title: 'Hải sản Bé Mặn Đà Nẵng',
          amount: 1800000,
          category: ExpenseCategory.food,
          payerId: 'user-nhat',
          splitType: SplitType.equal,
          shares: {
            'user-nhat': 450000,
            'user-phu': 450000,
            'user-thanh': 450000,
            'user-tung': 450000,
          },
          date: DateTime.now().subtract(const Duration(days: 2)),
        ),
        ExpenseItem(
          id: 'exp-2',
          title: 'Vé Cáp treo Bà Nà Hills',
          amount: 3600000,
          category: ExpenseCategory.tickets,
          payerId: 'user-phu',
          splitType: SplitType.equal,
          shares: {
            'user-nhat': 900000,
            'user-phu': 900000,
            'user-thanh': 900000,
            'user-tung': 900000,
          },
          date: DateTime.now().subtract(const Duration(days: 1)),
        ),
        ExpenseItem(
          id: 'exp-3',
          title: 'Homestay Phố cổ Hội An (2 đêm)',
          amount: 1600000,
          category: ExpenseCategory.hotel,
          payerId: 'user-nhat',
          splitType: SplitType.equal,
          shares: {
            'user-nhat': 400000,
            'user-phu': 400000,
            'user-thanh': 400000,
            'user-tung': 400000,
          },
          date: DateTime.now().subtract(const Duration(hours: 18)),
        ),
        ExpenseItem(
          id: 'exp-4',
          title: 'Thuê 2 xe máy vi vu Sơn Trà',
          amount: 400000,
          category: ExpenseCategory.transport,
          payerId: 'user-thanh',
          splitType: SplitType.exact,
          shares: {
            'user-nhat': 100000,
            'user-phu': 100000,
            'user-thanh': 100000,
            'user-tung': 100000,
          },
          date: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ];

      _isOptimized = false;
      _recalculateSettlements();
    });
  }

  // ==============================================================================
  // TÍNH TOÁN CÔNG NỢ & THUẬT TOÁN MIN CASH FLOW
  // ==============================================================================

  // Tính số dư ròng của từng người: Net = Đã chi trả (Paid) - Phải chịu (Owed)
  Map<String, int> _calculateNetBalances() {
    final net = <String, int>{for (var m in _members) m.id: 0};

    for (final exp in _expenses) {
      // Người thanh toán được cộng toàn bộ số tiền đã trả
      net[exp.payerId] = (net[exp.payerId] ?? 0) + exp.amount;

      // Các thành viên chịu phần chia bị trừ đi số tiền tương ứng
      exp.shares.forEach((userId, share) {
        net[userId] = (net[userId] ?? 0) - share;
      });
    }

    return net;
  }

  // Thuật toán Min Cash Flow: Tối ưu hóa dòng tiền, triệt tiêu nợ chéo
  void _recalculateSettlements() {
    if (!_isOptimized) {
      // Chế độ chưa tối ưu: Mỗi hóa đơn tạo ra các khoản nợ chéo rời rạc
      final rawList = <SettlementTransaction>[];
      int counter = 1;

      for (final exp in _expenses) {
        exp.shares.forEach((debtorId, share) {
          if (debtorId != exp.payerId && share > 0) {
            rawList.add(
              SettlementTransaction(
                id: 'raw-$counter',
                fromUserId: debtorId,
                toUserId: exp.payerId,
                amount: share,
                note: exp.title,
              ),
            );
            counter++;
          }
        });
      }
      _settlements = rawList;
    } else {
      // Chế độ tối ưu (Min Cash Flow): Dùng Greedy Subset Net-Balances
      final net = _calculateNetBalances();
      final debtors = <MapEntry<String, int>>[];
      final creditors = <MapEntry<String, int>>[];

      net.forEach((userId, balance) {
        if (balance < 0) {
          debtors.add(MapEntry(userId, -balance)); // Cần trả
        } else if (balance > 0) {
          creditors.add(MapEntry(userId, balance)); // Cần nhận
        }
      });

      debtors.sort((a, b) => b.value.compareTo(a.value));
      creditors.sort((a, b) => b.value.compareTo(a.value));

      final optimized = <SettlementTransaction>[];
      int dIdx = 0;
      int cIdx = 0;
      int count = 1;

      while (dIdx < debtors.length && cIdx < creditors.length) {
        final debtor = debtors[dIdx];
        final creditor = creditors[cIdx];
        final minAmount = debtor.value < creditor.value ? debtor.value : creditor.value;

        if (minAmount > 0) {
          optimized.add(
            SettlementTransaction(
              id: 'opt-$count',
              fromUserId: debtor.key,
              toUserId: creditor.key,
              amount: minAmount,
              note: 'Tất toán tối ưu Min Cash Flow',
            ),
          );
          count++;
        }

        debtors[dIdx] = MapEntry(debtor.key, debtor.value - minAmount);
        creditors[cIdx] = MapEntry(creditor.key, creditor.value - minAmount);

        if (debtors[dIdx].value == 0) dIdx++;
        if (creditors[cIdx].value == 0) cIdx++;
      }

      _settlements = optimized;
    }
  }

  // Format tiền tệ Việt Nam (VD: 1.800.000 ₫)
  String _formatVnd(num amount) {
    final str = amount.toInt().abs().toString();
    final formatted = str.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}.',
    );
    return amount < 0 ? '-$formatted ₫' : '$formatted ₫';
  }

  GroupMember _getMember(String id) =>
      _members.firstWhere((m) => m.id == id, orElse: () => _members.first);

  int get _totalSpent => _expenses.fold(0, (sum, e) => sum + e.amount);

  @override
  Widget build(BuildContext context) {
    final netBalances = _calculateNetBalances();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF09143B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: .04),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sổ quỹ & Chia tiền nhóm',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF09143B),
                fontSize: 17,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'MÔ PHỎNG MIN CASH FLOW',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Hội An – Đà Nẵng',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đặt lại dữ liệu mẫu',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5D6889)),
            onPressed: () {
              _resetToDefaultMockData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã khôi phục dữ liệu chi tiêu mẫu!'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13.5),
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Hóa đơn'),
                Tab(icon: Icon(Icons.account_balance_rounded, size: 18), text: 'Cân đối'),
                Tab(icon: Icon(Icons.qr_code_2_rounded, size: 18), text: 'Tất toán QR'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExpensesTab(),
          _buildBalancesTab(netBalances),
          _buildSettlementTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openAddExpenseModal,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Thêm hóa đơn',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  // ==============================================================================
  // TAB 1: DANH SÁCH HÓA ĐƠN & TỔNG QUAN NGÂN SÁCH
  // ==============================================================================
  Widget _buildExpensesTab() {
    final remaining = _estimatedBudget - _totalSpent;
    final progress = (_totalSpent / _estimatedBudget).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        // ── THẺ DASHBOARD NGÂN SÁCH ──
        AppCard(
          softShadow: true,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tiến độ ngân sách chuyến đi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF09143B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: progress > 0.8
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: progress > 0.8
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.85 ? const Color(0xFFEF4444) : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      label: 'ĐÃ CHI',
                      value: _formatVnd(_totalSpent),
                      valueColor: AppColors.primary,
                    ),
                  ),
                  Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'CÒN LẠI',
                      value: _formatVnd(remaining),
                      valueColor: remaining < 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
                    ),
                  ),
                  Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'DỰ KIẾN',
                      value: _formatVnd(_estimatedBudget),
                      valueColor: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── TIÊU ĐỀ DANH SÁCH HÓA ĐƠN ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Lịch sử chi tiêu (${_expenses.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF09143B),
              ),
            ),
            Text(
              'Tổng: ${_formatVnd(_totalSpent)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── DANH SÁCH CHI TIẾT CÁC HÓA ĐƠN ──
        ..._expenses.map((expense) {
          final payer = _getMember(expense.payerId);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              elevation: 0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Danh mục
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: expense.category.color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        expense.category.icon,
                        color: expense.category.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Thông tin khoản chi
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF09143B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${payer.name} đã trả',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCBD5E1),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  expense.splitType.label,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Avatar nhóm người cùng chia
                          Row(
                            children: [
                              const Text(
                                'Chia cho: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(width: 4),
                              ...expense.shares.keys.map((uid) {
                                final m = _getMember(uid);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: AvatarPlaceholder(
                                    name: m.name,
                                    imageUrl: m.avatarUrl,
                                    radius: 10,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Số tiền & nút xóa
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatVnd(expense.amount),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF09143B),
                          ),
                        ),
                        IconButton(
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Xóa hóa đơn',
                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF94A3B8)),
                          onPressed: () {
                            setState(() {
                              _expenses.removeWhere((e) => e.id == expense.id);
                              _recalculateSettlements();
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  // ==============================================================================
  // TAB 2: BẢNG CÂN ĐỐI TÀI CHÍNH CÁ NHÂN (NET BALANCES)
  // ==============================================================================
  Widget _buildBalancesTab(Map<String, int> netBalances) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Giải thích số dư ròng
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Số dư ròng = (Tổng tiền đã chi) - (Tổng phần phải chịu).\n'
                  'Màu xanh: Được nhận lại tiền. Màu cam/đỏ: Cần trả thêm vào quỹ.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF1E40AF),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        ..._members.map((member) {
          final balance = netBalances[member.id] ?? 0;
          final isCreditor = balance > 0;
          final isSettled = balance == 0;

          // Tính riêng tổng đã chi của người này
          final paidTotal = _expenses
              .where((e) => e.payerId == member.id)
              .fold(0, (sum, e) => sum + e.amount);

          // Tính riêng tổng phần phải chịu
          final owedTotal = _expenses.fold(
            0,
            (sum, e) => sum + (e.shares[member.id] ?? 0),
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              softShadow: true,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      AvatarPlaceholder(
                        name: member.name,
                        imageUrl: member.avatarUrl,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  member.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF09143B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (member.role == 'Trưởng nhóm')
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'LEADER',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${member.bankName} • ${member.accountNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Badge trạng thái số dư
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSettled
                              ? const Color(0xFFF1F5F9)
                              : (isCreditor
                                  ? const Color(0xFFECFDF5)
                                  : const Color(0xFFFEF2F2)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSettled
                                ? const Color(0xFFCBD5E1)
                                : (isCreditor
                                    ? const Color(0xFFA7F3D0)
                                    : const Color(0xFFFECACA)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isSettled
                                  ? 'Hòa vốn'
                                  : (isCreditor ? 'Được nhận lại' : 'Cần trả thêm'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSettled
                                    ? const Color(0xFF64748B)
                                    : (isCreditor
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFDC2626)),
                              ),
                            ),
                            Text(
                              isSettled ? '0 ₫' : _formatVnd(balance),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isSettled
                                    ? const Color(0xFF09143B)
                                    : (isCreditor
                                        ? const Color(0xFF059669)
                                        : const Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Đã chi trước: ${_formatVnd(paidTotal)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      Text(
                        'Phần phải chịu: ${_formatVnd(owedTotal)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ==============================================================================
  // TAB 3: TẤT TOÁN CÔNG NỢ & MÔ PHỎNG VIETQR (MIN CASH FLOW)
  // ==============================================================================
  Widget _buildSettlementTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── BANNER THUẬT TOÁN TỐI ƯU HÓA MIN CASH FLOW ──
        AppCard(
          softShadow: true,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isOptimized
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: _isOptimized ? const Color(0xFF10B981) : const Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isOptimized
                              ? 'Thuật toán Min Cash Flow: ĐÃ TỐI ƯU'
                              : 'Chế độ nợ chéo ban đầu (Chưa tối ưu)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _isOptimized ? const Color(0xFF047857) : const Color(0xFFB45309),
                          ),
                        ),
                        Text(
                          _isOptimized
                              ? 'Đã triệt tiêu nợ chéo! Chỉ cần ${_settlements.length} giao dịch chuyển khoản duy nhất.'
                              : 'Có ${_settlements.length} giao dịch rời rạc. Hãy bấm tối ưu để rút gọn.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              CustomButton(
                text: _isOptimized
                    ? 'Xem lại bảng nợ chéo ban đầu'
                    : '⚡ Kích hoạt tối ưu Min Cash Flow',
                variant: _isOptimized ? AppButtonVariant.secondary : AppButtonVariant.primary,
                icon: _isOptimized ? Icons.history_rounded : Icons.bolt_rounded,
                onPressed: () {
                  setState(() {
                    _isOptimized = !_isOptimized;
                    _recalculateSettlements();
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── TIÊU ĐỀ DANH SÁCH GIAO DỊCH ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Danh sách chuyển tiền (${_settlements.length})',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF09143B),
              ),
            ),
            const Text(
              'Chạm để xem VietQR',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (_settlements.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: EmptyStateWidget(
              icon: Icons.check_circle_outline_rounded,
              title: 'Tất cả đã cân bằng',
              message: 'Không có khoản nợ nào cần thanh toán giữa các thành viên.',
            ),
          )
        else
          ..._settlements.map((tx) {
            final from = _getMember(tx.fromUserId);
            final to = _getMember(tx.toUserId);

            final isPaid = tx.status == 'PAID';
            final isReported = tx.status == 'REPORTED';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  onTap: () => _openVietQrModal(tx, from, to),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                      border: Border.all(
                        color: isPaid
                            ? const Color(0xFFA7F3D0)
                            : (isReported
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFE2E8F0)),
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Người chuyển
                            Column(
                              children: [
                                AvatarPlaceholder(
                                  name: from.name,
                                  imageUrl: from.avatarUrl,
                                  radius: 18,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  from.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF09143B),
                                  ),
                                ),
                              ],
                            ),

                            // Mũi tên chuyển khoản & số tiền
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    _formatVnd(tx.amount),
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isPaid
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF09143B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        height: 2,
                                        width: 28,
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: AppColors.primary,
                                        size: 16,
                                      ),
                                      Container(
                                        height: 2,
                                        width: 28,
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tx.note,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Người nhận
                            Column(
                              children: [
                                AvatarPlaceholder(
                                  name: to.name,
                                  imageUrl: to.avatarUrl,
                                  radius: 18,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  to.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF09143B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // Trạng thái & nút mở QR
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? const Color(0xFFECFDF5)
                                    : (isReported
                                        ? const Color(0xFFFEF3C7)
                                        : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPaid
                                        ? Icons.check_circle_rounded
                                        : (isReported
                                            ? Icons.hourglass_top_rounded
                                            : Icons.pending_actions_rounded),
                                    size: 13,
                                    color: isPaid
                                        ? const Color(0xFF059669)
                                        : (isReported
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isPaid
                                        ? 'ĐÃ TẤT TOÁN'
                                        : (isReported ? 'ĐÃ BÁO CHUYỂN' : 'CHỜ THANH TOÁN'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isPaid
                                          ? const Color(0xFF059669)
                                          : (isReported
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Row(
                              children: [
                                const Icon(Icons.qr_code_rounded, size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                const Text(
                                  'Mã VietQR',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  // ==============================================================================
  // MODAL VIETQR THANH TOÁN TỨC THÌ (NAPAS 24/7)
  // ==============================================================================
  void _openVietQrModal(
    SettlementTransaction tx,
    GroupMember from,
    GroupMember to,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isPaid = tx.status == 'PAID';
          final isReported = tx.status == 'REPORTED';
          final transferSyntax = 'FEELINGTRIP ${from.name.toUpperCase()} TRA ${to.name.toUpperCase()}';

          // Link VietQR chuẩn
          final vietQrUrl =
              'https://img.vietqr.io/image/${to.bankBin}-${to.accountNumber}-compact2.png'
              '?amount=${tx.amount}&addInfo=${Uri.encodeComponent(transferSyntax)}&accountName=${Uri.encodeComponent(to.accountHolder)}';

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thanh kéo
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Tiêu đề
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VietQR Chuyển Khoản Nhanh',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF09143B),
                              ),
                            ),
                            Text(
                              'Hỗ trợ toàn bộ ngân hàng NAPAS 247',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // KHUNG MÃ VIETQR
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Ảnh VietQR
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          vietQrUrl,
                          width: 220,
                          height: 220,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: 220,
                              height: 220,
                              color: const Color(0xFFF8FAFC),
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            );
                          },
                          errorBuilder: (_, _, _) => Container(
                            width: 220,
                            height: 220,
                            color: const Color(0xFFF8FAFC),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.qr_code_scanner_rounded, size: 48, color: AppColors.primary),
                                SizedBox(height: 8),
                                Text(
                                  'Mã QR Mẫu VietQR\n(Không có kết nối mạng)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatVnd(tx.amount),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF09143B),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // THÔNG TIN CHUYỂN KHOẢN
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildQrDetailRow('Ngân hàng thụ hưởng', to.bankName),
                      const Divider(height: 14),
                      _buildQrDetailRow('Chủ tài khoản', to.accountHolder),
                      const Divider(height: 14),
                      _buildQrDetailRow(
                        'Số tài khoản',
                        to.accountNumber,
                        copyable: true,
                      ),
                      const Divider(height: 14),
                      _buildQrDetailRow(
                        'Nội dung CK',
                        transferSyntax,
                        copyable: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // NÚT MÔ PHỎNG TRẠNG THÁI THANH TOÁN
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(
                          isReported ? Icons.check_rounded : Icons.send_rounded,
                          size: 16,
                        ),
                        label: Text(
                          isReported ? 'Đã báo chuyển' : 'Báo đã chuyển',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isReported ? const Color(0xFFD97706) : AppColors.primary,
                          side: BorderSide(
                            color: isReported ? const Color(0xFFD97706) : AppColors.primary,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isPaid
                            ? null
                            : () {
                                setState(() {
                                  tx.status = 'REPORTED';
                                });
                                setModalState(() {});
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${from.name} đã báo chuyển ${_formatVnd(tx.amount)}!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: Text(isPaid ? 'Đã gạch nợ' : 'Xác nhận (SePay)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPaid ? const Color(0xFF10B981) : const Color(0xFF09143B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            tx.status = 'PAID';
                          });
                          setModalState(() {});
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã xác nhận gạch nợ thành công cho ${from.name}!'),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQrDetailRow(String label, String value, {bool copyable = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF09143B),
              ),
            ),
            if (copyable) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Đã sao chép "$value"!'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ==============================================================================
  // MODAL SHEET: THÊM HÓA ĐƠN MỚI VÀ CHỌN CƠ CHẾ CHIA
  // ==============================================================================
  void _openAddExpenseModal() {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    ExpenseCategory selectedCategory = ExpenseCategory.food;
    String selectedPayerId = _members.first.id;
    SplitType selectedSplitType = SplitType.equal;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Thanh kéo
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Thêm hóa đơn mới',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF09143B),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Tên khoản chi
                  CustomTextField(
                    label: 'Tên khoản chi tiêu',
                    hint: 'VD: Ăn tối hải sản, Vé tham quan...',
                    prefixIcon: Icons.edit_note_rounded,
                    controller: titleCtrl,
                  ),

                  const SizedBox(height: 12),

                  // Số tiền
                  AppMoneyField(
                    label: 'Số tiền chi trả',
                    controller: amountCtrl,
                  ),

                  const SizedBox(height: 16),

                  // Danh mục chi tiêu
                  const Text(
                    'Danh mục',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF09143B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ExpenseCategory.values.map((cat) {
                        final isSelected = selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                            label: Text(cat.label),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF09143B),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                            onSelected: (_) => setSheetState(() => selectedCategory = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Người thanh toán (Payer)
                  const Text(
                    'Ai là người trả tiền trước?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF09143B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _members.map((m) {
                      final isPayer = selectedPayerId == m.id;
                      return ChoiceChip(
                        avatar: AvatarPlaceholder(name: m.name, imageUrl: m.avatarUrl, radius: 10),
                        label: Text(m.name),
                        selected: isPayer,
                        selectedColor: const Color(0xFF09143B),
                        labelStyle: TextStyle(
                          color: isPayer ? Colors.white : const Color(0xFF09143B),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                        onSelected: (_) => setSheetState(() => selectedPayerId = m.id),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Cơ chế chia tiền
                  const Text(
                    'Cơ chế chia tiền (Split Mechanism)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF09143B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: SplitType.values.map((st) {
                      final isSelected = selectedSplitType == st;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () => setSheetState(() => selectedSplitType = st),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    st.icon,
                                    size: 18,
                                    color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    st.label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? AppColors.primary : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Nút tạo hóa đơn
                  CustomButton(
                    text: 'Lưu hóa đơn & Tính toán nợ',
                    variant: AppButtonVariant.primary,
                    icon: Icons.check_circle_rounded,
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      final amount = int.tryParse(amountCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;

                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Vui lòng nhập tên khoản chi!')),
                        );
                        return;
                      }

                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Số tiền phải lớn hơn 0!')),
                        );
                        return;
                      }

                      // Tính toán shares
                      final shares = <String, int>{};
                      if (selectedSplitType == SplitType.equal) {
                        final share = (amount / _members.length).round();
                        for (var m in _members) {
                          shares[m.id] = share;
                        }
                      } else {
                        // Demo: chia đều hoặc theo tỷ lệ custom
                        final share = (amount / _members.length).round();
                        for (var m in _members) {
                          shares[m.id] = share;
                        }
                      }

                      setState(() {
                        _expenses.insert(
                          0,
                          ExpenseItem(
                            id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
                            title: title,
                            amount: amount,
                            category: selectedCategory,
                            payerId: selectedPayerId,
                            splitType: selectedSplitType,
                            shares: shares,
                            date: DateTime.now(),
                          ),
                        );
                        _recalculateSettlements();
                      });

                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã thêm hóa đơn "$title" và cập nhật công nợ!'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
