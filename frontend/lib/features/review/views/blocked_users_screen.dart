import 'package:flutter/material.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
import '../models/review_model.dart';
import '../viewmodels/review_viewmodel.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final ReviewViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ReviewViewModel()..loadBlockedUsers();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _unblock(BlockedUserModel user) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Bỏ chặn ${user.displayName}?',
      message: 'Người dùng này có thể tương tác lại với bạn trên hệ thống.',
      confirmLabel: 'Bỏ chặn',
    );

    if (!confirmed) return;
    final success = await _viewModel.unblockUser(user.id);

    if (!mounted) return;
    AppFeedback.show(
      context,
      success
          ? 'Đã bỏ chặn ${user.displayName}.'
          : _viewModel.errorMessage ?? 'Không thể bỏ chặn người dùng.',
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, _) => AppScaffold(
        title: 'Người dùng đã chặn',
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _viewModel.isLoadingBlockedUsers
                ? null
                : _viewModel.loadBlockedUsers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoadingBlockedUsers && _viewModel.blockedUsers.isEmpty) {
      return const LoadingIndicator(message: 'Đang tải danh sách chặn...');
    }

    if (_viewModel.errorMessage != null && _viewModel.blockedUsers.isEmpty) {
      return ErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadBlockedUsers,
      );
    }

    if (_viewModel.blockedUsers.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.person_off_outlined,
        title: 'Chưa chặn người dùng nào',
        message: 'Những tài khoản bạn chặn sẽ xuất hiện tại đây.',
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.loadBlockedUsers,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceM),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _viewModel.blockedUsers.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.spaceM),
        itemBuilder: (context, index) {
          final user = _viewModel.blockedUsers[index];
          final isUpdating = _viewModel.updatingBlockedUserId == user.id;

          return AppCard(
            outlined: true,
            child: Row(
              children: [
                AvatarPlaceholder(
                  name: user.displayName,
                  imageUrl: user.avatarUrl,
                  radius: 26,
                ),
                const SizedBox(width: AppSizes.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                      if (user.blockedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Đã chặn ${AppUtils.formatDateTime(user.blockedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                CustomButton(
                  text: isUpdating ? 'Đang xử lý...' : 'Bỏ chặn',
                  onPressed: isUpdating ? null : () => _unblock(user),
                  variant: AppButtonVariant.text,
                  fullWidth: false,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
