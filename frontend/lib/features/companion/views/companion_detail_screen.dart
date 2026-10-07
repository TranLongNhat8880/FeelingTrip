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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF09143B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: .04),
        leading: IconButton(
          tooltip: 'Quay lại',
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF09143B)),
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
                    radius: 17,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      post.creator.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF09143B),
                          ),
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
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (trip.coverImageUrl != null)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Image.network(
              trip.coverImageUrl!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 180,
                color: AppColors.primarySurface,
                child: const Icon(
                  Icons.landscape_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── CARD 1: Highlight Trip Info (Điểm đến, Thời gian, Chi phí) ──
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _info(
                      Icons.location_on_rounded,
                      const Color(0xFFE0F2FE),
                      AppColors.primary,
                      'Điểm đến',
                      trip.destination ?? 'Chưa có điểm đến',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                    _info(
                      Icons.calendar_today_rounded,
                      const Color(0xFFCCFBF1),
                      const Color(0xFF0D9488),
                      'Thời gian',
                      '$date${trip.durationDays == null ? '' : ' (${trip.durationDays} ngày)'}',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppColors.divider),
                    ),
                    _info(
                      Icons.account_balance_wallet_rounded,
                      const Color(0xFFFEF3C7),
                      const Color(0xFFD97706),
                      'Chi phí dự kiến',
                      trip.estimatedBudget == null
                          ? 'Chưa có dự kiến'
                          : '${NumberFormat('#,###', 'vi_VN').format(trip.estimatedBudget)} đ',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── CARD 2: Content (Nội dung) ────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nội dung',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF09143B),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      post.title ?? 'Bài tìm bạn đồng hành',
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF09143B),
                      ),
                    ),
                    if (post.content?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Text(
                        post.content!,
                        style: text.bodyMedium?.copyWith(
                          color: const Color(0xFF334155),
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: post.isClosed
                                ? AppColors.errorSurface
                                : post.isFull
                                ? AppColors.warningSurface
                                : const Color(0xFFEDF7ED),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            post.isClosed
                                ? 'Bài đăng đã đóng'
                                : post.isFull
                                ? 'Nhóm đã đủ thành viên'
                                : 'Còn ${post.slotsLeft} chỗ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: post.isClosed
                                  ? AppColors.error
                                  : post.isFull
                                  ? AppColors.warning
                                  : const Color(0xFF008B57),
                            ),
                          ),
                        ),
                        if (post.genderPreference != 'ANY' ||
                            post.minAge != null ||
                            post.maxAge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              'Yêu cầu: ${post.genderPreference == 'MALE'
                                  ? 'Nam'
                                  : post.genderPreference == 'FEMALE'
                                  ? 'Nữ'
                                  : 'Bất kỳ giới tính'}'
                              '${post.minAge == null && post.maxAge == null ? '' : ' · Tuổi ${post.minAge ?? 18}–${post.maxAge ?? 'không giới hạn'}'}',
                              style: text.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (post.tags.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: post.tags
                            .map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── CARD 3: Members (Thành viên) ──────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thành viên · ${post.currentMembersCount}/${post.targetMembersCount}',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF09143B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (trip.members.isEmpty)
                      Text('Chưa có thông tin thành viên.', style: text.bodySmall)
                    else
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          for (final member in trip.members)
                            SizedBox(
                              width: 80,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: text.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (member.role == 'LEADER') ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Trưởng nhóm',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _info(
    IconData icon,
    Color bgIcon,
    Color iconColor,
    String label,
    String value,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bgIcon,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF09143B),
                  ),
            ),
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
    return Container(
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
          child: CustomButton(
            text: _vm.hasSentRequest ? 'Đã gửi yêu cầu' : 'Gửi yêu cầu tham gia',
            isLoading: _vm.isSubmitting,
            onPressed: _vm.hasSentRequest ? null : _openJoinSheet,
          ),
        ),
      ),
    );
  }
}
