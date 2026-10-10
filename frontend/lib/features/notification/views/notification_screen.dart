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
      await AppMessageDialog.show(
        context,
        title: item.title,
        message: item.message,
        tone: AppStatusTone.info,
        actionLabel: 'Đóng',
      );
    }
  }

  Future<void> _actions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
    color: AppColors.background,
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
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Thông báo',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Thao tác thông báo',
                      onPressed: viewModel.isLoading || viewModel.isUpdating
                          ? null
                          : () => _actions(context),
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
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
                    const SizedBox(width: 10),
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
                        color: AppColors.primary,
                        onRefresh: viewModel.load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(top: 4, bottom: 24),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final showDateHeader =
                                index == 0 ||
                                _day(items[index - 1].createdAt) !=
                                    _day(item.createdAt);

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (showDateHeader)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      14,
                                      20,
                                      8,
                                    ),
                                    child: Text(
                                      _day(item.createdAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Dismissible(
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
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
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
                                          decoration: BoxDecoration(
                                            color: item.isRead
                                                ? Colors.white
                                                : const Color(0xFFF2F9FF),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: item.isRead
                                                  ? AppColors.border
                                                  : AppColors.primary
                                                        .withValues(alpha: .3),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: item.isRead
                                                      ? .02
                                                      : .04,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: item.type == 'REQUEST'
                                                      ? const Color(0xFFE0F2FE)
                                                      : item.type == 'SYSTEM'
                                                      ? const Color(0xFFECFDF5)
                                                      : AppColors
                                                            .warningSurface,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  item.type == 'REQUEST'
                                                      ? Icons.group_add_rounded
                                                      : item.type == 'SYSTEM'
                                                      ? Icons.verified_rounded
                                                      : Icons.luggage_rounded,
                                                  size: 20,
                                                  color: item.type == 'REQUEST'
                                                      ? const Color(0xFF0284C7)
                                                      : item.type == 'SYSTEM'
                                                      ? const Color(0xFF059669)
                                                      : AppColors.warning,
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
                                                            fontWeight:
                                                                item.isRead
                                                                ? FontWeight
                                                                      .w500
                                                                : FontWeight
                                                                      .w700,
                                                            color: const Color(
                                                              0xFF09143B,
                                                            ),
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
                                                            height: 1.35,
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
                                                            color: AppColors
                                                                .textHint,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (!item.isRead)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: 8,
                                                        top: 4,
                                                      ),
                                                  child: Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration:
                                                        const BoxDecoration(
                                                          color:
                                                              AppColors.primary,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
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
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.center,
      height: 42,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: .25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
    ),
  );
}
