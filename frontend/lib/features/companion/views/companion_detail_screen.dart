import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../models/companion_post_model.dart';
import '../viewmodels/companion_detail_viewmodel.dart';
import 'widgets/join_request_sheet.dart';

// ================================================================================
// SCREEN: Companion Detail
// ================================================================================
// Chi tiết bài đăng + thông tin nhóm + nút gửi yêu cầu tham gia.
// ================================================================================

class CompanionDetailScreen extends StatefulWidget {
  const CompanionDetailScreen({super.key, required this.postId});
  final String postId;

  @override
  State<CompanionDetailScreen> createState() => _CompanionDetailScreenState();
}

class _CompanionDetailScreenState extends State<CompanionDetailScreen> {
  late final CompanionDetailViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = CompanionDetailViewModel();
    _vm.addListener(_onVmChanged);
    _vm.load(widget.postId);
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  void _openJoinSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => JoinRequestSheet(
        postTitle: _vm.post?.title ?? '',
        isSubmitting: _vm.isSubmitting,
        onSubmit: (introduction) async {
          final ok = await _vm.sendJoinRequest(
            postId: widget.postId,
            introduction: introduction,
          );
          if (!mounted) return;
          if (ok) {
            if (sheetContext.mounted) Navigator.pop(sheetContext);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Đã gửi yêu cầu tham gia!'),
                backgroundColor: AppColors.success,
              ),
            );
          } else if (_vm.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_vm.errorMessage!),
                backgroundColor: AppColors.error,
              ),
            );
            _vm.clearMessages();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _vm.post;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: post == null
            ? const Text('Chi tiết bài đăng')
            : Row(
                children: [
                  AvatarPlaceholder(
                    name: post.creator.displayName,
                    imageUrl: post.creator.avatarUrl,
                    radius: 16,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      post.creator.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (post.creator.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: post == null ? null : _buildBottomBar(post),
      body: _vm.isLoading
          ? const Center(child: LoadingIndicator())
          : post == null
          ? ErrorState(
              message: _vm.errorMessage ?? 'Không tìm thấy bài đăng.',
              onRetry: () => _vm.load(widget.postId),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.documentMaxWidth,
                ),
                child: _buildContent(post),
              ),
            ),
    );
  }

  Widget _buildContent(CompanionPost post) {
    final text = Theme.of(context).textTheme;
    final trip = post.trip;
    final date = trip.startDate == null
        ? 'Chưa có lịch'
        : '${DateFormat('dd/MM/yyyy').format(trip.startDate!)}${trip.endDate == null ? '' : ' – ${DateFormat('dd/MM/yyyy').format(trip.endDate!)}'}';
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (trip.coverImageUrl != null)
          Image.network(
            trip.coverImageUrl!,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 200,
              color: AppColors.inputSurface,
              child: const Icon(
                Icons.landscape_outlined,
                size: 40,
                color: AppColors.textHint,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _info(
                Icons.location_on_outlined,
                'Điểm đến',
                trip.destination ?? 'Chưa có điểm đến',
              ),
              const Divider(height: 24, color: AppColors.divider),
              _info(
                Icons.calendar_today_outlined,
                'Thời gian',
                '$date${trip.durationDays == null ? '' : ' (${trip.durationDays} ngày)'}',
              ),
              const Divider(height: 24, color: AppColors.divider),
              _info(
                Icons.account_balance_wallet_outlined,
                'Chi phí dự kiến',
                trip.estimatedBudget == null
                    ? 'Chưa có dự kiến'
                    : '${NumberFormat('#,###', 'vi_VN').format(trip.estimatedBudget)} đ',
              ),
              const Divider(height: 24, color: AppColors.divider),
              Text('Nội dung', style: text.titleSmall),
              const SizedBox(height: 10),
              Text(
                post.title ?? 'Bài tìm bạn đồng hành',
                style: text.titleMedium,
              ),
              if (post.content?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Text(post.content!, style: text.bodyMedium),
              ],
              if (post.genderPreference != 'ANY' ||
                  post.minAge != null ||
                  post.maxAge != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Yêu cầu: ${post.genderPreference == 'MALE'
                      ? 'Nam'
                      : post.genderPreference == 'FEMALE'
                      ? 'Nữ'
                      : 'Bất kỳ giới tính'}'
                  '${post.minAge == null && post.maxAge == null ? '' : ' · Tuổi ${post.minAge ?? 18}–${post.maxAge ?? 'không giới hạn'}'}',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                post.isClosed
                    ? 'Bài đăng đã đóng'
                    : post.isFull
                    ? 'Nhóm đã đủ thành viên'
                    : 'Còn ${post.slotsLeft} chỗ',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.tags.map((tag) => '#$tag').join('  '),
                  style: text.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const Divider(height: 28, color: AppColors.divider),
              Text(
                'Thành viên · ${post.currentMembersCount}/${post.targetMembersCount}',
                style: text.titleSmall,
              ),
              const SizedBox(height: 12),
              if (trip.members.isEmpty)
                Text('Chưa có thông tin thành viên.', style: text.bodySmall)
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final member in trip.members)
                      SizedBox(
                        width: 82,
                        child: Column(
                          children: [
                            AvatarPlaceholder(
                              name: member.displayName ?? 'Thành viên',
                              imageUrl: member.avatarUrl,
                              radius: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              member.displayName ?? 'Thành viên',
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              style: text.labelSmall,
                            ),
                            if (member.role == 'LEADER')
                              Text(
                                'Trưởng nhóm',
                                style: text.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _info(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 21, color: AppColors.textSecondary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 3),
            Text(value, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    ],
  );

  Widget? _buildBottomBar(CompanionPost post) {
    final user = AuthScope.of(context).user;
    if (post.isClosed ||
        post.isFull ||
        post.creator.id == user?.id ||
        post.creator.id == 'current-user' ||
        post.trip.members.any((member) => member.userId == user?.id)) {
      return null;
    }
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: CustomButton(
          text: _vm.hasSentRequest ? 'Đã gửi yêu cầu' : 'Gửi yêu cầu tham gia',
          isLoading: _vm.isSubmitting,
          onPressed: _vm.hasSentRequest ? null : _openJoinSheet,
        ),
      ),
    );
  }
}
