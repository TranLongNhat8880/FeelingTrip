import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../map/views/admin_place_management_content.dart';
import '../viewmodels/admin_viewmodel.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _vm = AdminViewModel();
  int _section = 0;
  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<bool> _review(AdminUser user, bool approve) async {
    if (_vm.isUpdating) return false;
    String? reason;
    if (approve) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Duyệt hồ sơ của ${user.name}?',
        message: 'Cấp trạng thái đã xác minh cho hồ sơ này.',
        confirmLabel: 'Duyệt hồ sơ',
      );
      if (!confirmed || !mounted) return false;
    } else {
      final form = GlobalKey<FormState>();
      var input = '';
      reason = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lý do từ chối'),
          content: Form(
            key: form,
            child: TextFormField(
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: ảnh mặt trước chưa rõ',
              ),
              onChanged: (value) => input = value,
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Nhập ít nhất 3 ký tự'
                  : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, input.trim());
                }
              },
              child: const Text('Từ chối'),
            ),
          ],
        ),
      );
      if (reason == null || !mounted) return false;
    }
    final success = await _vm.review(user, approve, reason: reason);
    if (!success && mounted) _showError();
    return success;
  }

  Future<void> _userActions(AdminUser user) async {
    if (_vm.isUpdating) return;
    final ban = user.status != 'BANNED';
    final selected = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: AvatarPlaceholder(name: user.name, radius: 22),
                title: Text(user.name),
                subtitle: Text(
                  '${user.email}\nTrạng thái: ${ban ? 'Hoạt động' : 'Đã khóa'}',
                ),
              ),
              ListTile(
                leading: Icon(
                  ban ? Icons.lock_outline : Icons.lock_open,
                  color: ban ? AppColors.error : AppColors.primary,
                ),
                title: Text(ban ? 'Khóa tài khoản' : 'Mở khóa tài khoản'),
                onTap: () => Navigator.pop(context, true),
              ),
              ListTile(
                title: const Text('Hủy', textAlign: TextAlign.center),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != true || !mounted) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: ban ? 'Khóa tài khoản?' : 'Mở khóa tài khoản?',
      message: user.email,
      confirmLabel: ban ? 'Khóa tài khoản' : 'Mở khóa',
    );
    if (mounted && confirmed) {
      if (!await _vm.updateStatus(user) && mounted) _showError();
    }
  }

  Future<void> _logout() async {
    final auth = AuthScope.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Đăng xuất quản trị?',
      message: 'Bạn có thể đăng nhập lại để tiếp tục xử lý hồ sơ.',
      confirmLabel: 'Đăng xuất',
    );
    if (confirmed && mounted) await auth.logout();
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_vm.errorMessage ?? 'Thao tác chưa thành công')),
    );
  }

  Widget _document(String? url) {
    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(Icons.image_outlined, size: 48, color: AppColors.textHint),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          const Center(child: Text('Không tải được ảnh')),
    );
  }

  void _openProfile(AdminUser user) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (profileContext) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: const AppTopBar(title: 'Chi tiết hồ sơ'),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .04),
                  offset: const Offset(0, -3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Từ chối',
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          if (await _review(user, false) &&
                              profileContext.mounted) {
                            Navigator.pop(profileContext);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: 'Duyệt hồ sơ',
                        onPressed: () async {
                          if (await _review(user, true) &&
                              profileContext.mounted) {
                            Navigator.pop(profileContext);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.documentMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AvatarPlaceholder(name: user.name, radius: 26),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF09143B),
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    user.email,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const AppStatusBadge(
                          label: 'Chờ duyệt',
                          tone: AppStatusTone.warning,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nộp hồ sơ: ${(user.submittedAt == null ? 'Chưa có thời gian' : DateFormat('dd/MM/yyyy · HH:mm').format(user.submittedAt!))}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final label in [
                          'CCCD mặt trước',
                          'CCCD mặt sau',
                          'Ảnh chân dung',
                        ]) ...[
                          Text(
                            label,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF09143B),
                                ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => showDialog<void>(
                              context: profileContext,
                              builder: (context) => AlertDialog(
                                title: Text(label),
                                content: SizedBox(
                                  height: 300,
                                  width: double.maxFinite,
                                  child: InteractiveViewer(
                                    child: _document(user.document(label)),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Đóng'),
                                  ),
                                ],
                              ),
                            ),
                            child: Container(
                              height: label == 'Ảnh chân dung' ? 120 : 150,
                              decoration: BoxDecoration(
                                color: AppColors.inputSurface,
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _document(user.document(label)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Center(
                          child: Text(
                            'Chạm ảnh để phóng to',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _sectionTitle {
    return switch (_section) {
      0 => 'Hồ sơ chờ duyệt',
      1 => 'Người dùng',
      2 => 'Quản lý địa điểm',
      _ => 'Quản trị',
    };
  }

  Widget _buildSection() {
    if (_section == 2) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: AdminPlaceManagementContent(),
      );
    }

    return RefreshIndicator(
      onRefresh: _vm.load,
      child: _vm.isLoading
          ? const LoadingIndicator()
          : _vm.errorMessage != null
          ? ErrorState(message: _vm.errorMessage!, onRetry: _vm.load)
          : _section == 0
          ? _pendingList()
          : _userList(),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _vm,
    builder: (context, _) => Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppTopBar(
        title: _sectionTitle,
        showBack: false,
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedIndex: _section,
        onSelected: (value) => setState(() => _section = value),
        items: const [
          AppNavigationItem(
            label: 'Duyệt eKYC',
            icon: Icons.fact_check_outlined,
          ),
          AppNavigationItem(label: 'Người dùng', icon: Icons.people_outline),
          AppNavigationItem(label: 'Địa điểm', icon: Icons.place_outlined),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSizes.documentMaxWidth,
            ),
            child: _buildSection(),
          ),
        ),
      ),
    ),
  );

  Widget _pendingList() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${_vm.pending.length} hồ sơ cần xem xét',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: _vm.pending.isEmpty
            ? EmptyStateWidget(
                buttonText: 'Tải lại',
                onButtonPressed: _vm.load,
                icon: Icons.task_alt,
                title: 'Đã xử lý hết hồ sơ',
                message: 'Hồ sơ mới sẽ xuất hiện ở đây.',
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _vm.load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _vm.pending.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = _vm.pending[index];
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: AvatarPlaceholder(name: user.name, radius: 22),
                        title: Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF09143B),
                              ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nộp ${(user.submittedAt == null ? 'Chưa có thời gian' : DateFormat('dd/MM · HH:mm').format(user.submittedAt!))}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textHint,
                                  ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                        onTap: () => _openProfile(user),
                      ),
                    ),
                  );
                  },
                ),
              ),
      ),
    ],
  );

  Widget _userList() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            onChanged: (value) => _vm.filter(query: value),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 20, color: AppColors.primary),
              hintText: 'Tên hoặc email',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final item in const {
              '': 'Tất cả',
              'ACTIVE': 'Hoạt động',
              'BANNED': 'Đã khóa',
            }.entries)
              ChoiceChip(
                label: Text(item.value),
                selected: _vm.status == item.key,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _vm.status == item.key
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontWeight: _vm.status == item.key
                      ? FontWeight.w600
                      : FontWeight.w500,
                  fontSize: 13,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: _vm.status == item.key
                      ? AppColors.primary
                      : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) => _vm.filter(userStatus: item.key),
              ),
          ],
        ),
      ),
      Expanded(
        child: _vm.filteredUsers.isEmpty
            ? EmptyStateWidget(
                buttonText: 'Tải lại',
                onButtonPressed: _vm.load,
                icon: Icons.search_off,
                title: 'Không tìm thấy tài khoản',
                message: 'Thử tên khác hoặc bỏ bộ lọc.',
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _vm.load,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: _vm.filteredUsers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = _vm.filteredUsers[index];
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: .03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        leading: AvatarPlaceholder(name: user.name, radius: 20),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF09143B),
                                    ),
                              ),
                            ),
                            if (user.verification == 'VERIFIED') ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.role == 'ADMIN'
                                  ? 'Quản trị viên'
                                  : user.status == 'BANNED'
                                  ? 'Đã khóa'
                                  : 'Hoạt động',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: user.status == 'BANNED'
                                        ? AppColors.error
                                        : user.role == 'ADMIN'
                                        ? AppColors.primaryDark
                                        : AppColors.success,
                                  ),
                            ),
                          ],
                        ),
                        trailing: user.role == 'ADMIN'
                            ? null
                            : IconButton(
                                tooltip: 'Thao tác tài khoản',
                                icon: const Icon(Icons.more_vert),
                                onPressed: () => _userActions(user),
                              ),
                      ),
                    ),
                  );
                  },
                ),
              ),
      ),
    ],
  );
}
