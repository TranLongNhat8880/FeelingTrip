import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/ui_kit.dart';
import '../../companion/views/companion_detail_screen.dart';
import '../../companion/views/companion_requests_screen.dart';
import '../viewmodels/notification_viewmodel.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key, required this.viewModel});
  final NotificationViewModel viewModel;

  Future<void> _open(BuildContext context, NotificationItem item) async {
    if (!item.isRead && !await viewModel.markRead(item)) {
      if (context.mounted) _showError(context);
      return;
    }
    if (!context.mounted) return;
    if (item.type == 'REQUEST' && item.title == 'Yêu cầu tham gia mới') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const CompanionRequestsScreen()),
      );
    } else if (item.postId != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => CompanionDetailScreen(postId: item.postId!),
        ),
      );
    } else if (item.type == 'REQUEST') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => const CompanionRequestsScreen()),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(item.title),
          content: Text(item.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _actions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Thao tác thông báo')),
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('Đánh dấu tất cả đã đọc'),
              enabled: viewModel.unreadCount > 0,
              onTap: () => Navigator.pop(context, 'read'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'Xoá tất cả thông báo',
                style: TextStyle(color: AppColors.error),
              ),
              subtitle: const Text('Bao gồm cả thông báo đã đọc'),
              enabled: true,
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              title: const Text('Hủy', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'read') {
      if (!await viewModel.markAllRead() && context.mounted) {
        _showError(context);
      }
    }
    if (action == 'delete') {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Xoá tất cả thông báo?',
        message:
            'Cả thông báo đã đọc và chưa đọc sẽ bị xoá. Bạn không thể khôi phục thao tác này.',
        confirmLabel: 'Xoá tất cả',
      );
      if (context.mounted && confirmed) {
        if (!await viewModel.deleteAll() && context.mounted) {
          _showError(context);
        }
      }
    }
  }

  void _showError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(viewModel.errorMessage ?? 'Thao tác chưa thành công'),
      ),
    );
  }

  String _day(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Hôm nay';
    if (day == today.subtract(const Duration(days: 1))) return 'Hôm qua';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.surface,
    child: SafeArea(
      bottom: false,
      child: AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) {
          final items = viewModel.visibleItems;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thông báo',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Thao tác thông báo',
                      onPressed: viewModel.isLoading || viewModel.isUpdating
                          ? null
                          : () => _actions(context),
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _tab(
                        context,
                        'Chưa đọc (${viewModel.unreadCount})',
                        viewModel.unreadOnly,
                        () => viewModel.filter(true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _tab(
                        context,
                        'Tất cả',
                        !viewModel.unreadOnly,
                        () => viewModel.filter(false),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Expanded(
                child: viewModel.isLoading
                    ? const Center(child: LoadingIndicator())
                    : viewModel.errorMessage != null
                    ? ErrorState(
                        message: viewModel.errorMessage!,
                        onRetry: viewModel.load,
                      )
                    : items.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.notifications_none_rounded,
                        title: viewModel.unreadOnly
                            ? 'Không có thông báo chưa đọc'
                            : 'Chưa có thông báo',
                        message: 'Những cập nhật mới sẽ xuất hiện tại đây.',
                      )
                    : RefreshIndicator(
                        onRefresh: viewModel.load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (index == 0 ||
                                    _day(items[index - 1].createdAt) !=
                                        _day(item.createdAt))
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      14,
                                      16,
                                      8,
                                    ),
                                    child: Text(
                                      _day(item.createdAt),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                Dismissible(
                                  key: ValueKey(item.id),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    final deleted = await viewModel.delete(
                                      item,
                                    );
                                    if (!deleted && context.mounted) {
                                      _showError(context);
                                    }
                                    return deleted;
                                  },
                                  background: Container(
                                    color: AppColors.error,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () => _open(context, item),
                                    onLongPress: () async {
                                      final confirmed =
                                          await AppConfirmDialog.show(
                                            context,
                                            title: 'Xoá thông báo?',
                                            message: item.title,
                                            confirmLabel: 'Xoá',
                                          );
                                      if (context.mounted && confirmed) {
                                        if (!await viewModel.delete(item) &&
                                            context.mounted) {
                                          _showError(context);
                                        }
                                      }
                                    },
                                    child: Container(
                                      color: item.isRead
                                          ? AppColors.surface
                                          : AppColors.primarySurface.withValues(
                                              alpha: .3,
                                            ),
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor:
                                                AppColors.inputSurface,
                                            child: Icon(
                                              item.type == 'REQUEST'
                                                  ? Icons.group_add_outlined
                                                  : item.type == 'SYSTEM'
                                                  ? Icons.verified_outlined
                                                  : Icons.luggage_outlined,
                                              size: 20,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight: item.isRead
                                                            ? FontWeight.w500
                                                            : FontWeight.w600,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.message,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: AppColors
                                                            .textSecondary,
                                                      ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  DateFormat(
                                                    'HH:mm · dd/MM',
                                                  ).format(item.createdAt),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.textHint,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (!item.isRead)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                left: 8,
                                                top: 5,
                                              ),
                                              child: Icon(
                                                Icons.circle,
                                                size: 7,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  color: AppColors.divider,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    ),
  );
  Widget _tab(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      backgroundColor: selected
          ? AppColors.primarySurface
          : AppColors.inputSurface,
      foregroundColor: selected ? AppColors.primary : AppColors.textSecondary,
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    child: Text(label),
  );
}
