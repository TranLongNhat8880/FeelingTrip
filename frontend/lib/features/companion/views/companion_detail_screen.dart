import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../models/companion_post_model.dart';
import '../viewmodels/companion_detail_viewmodel.dart';
import '../repositories/companion_repository.dart';
import 'widgets/join_request_sheet.dart';
import 'widgets/companion_itinerary_preview.dart';
import 'create_companion_post_screen.dart';
import '../../review/views/report_screen.dart';
import '../repositories/api_companion_repository.dart';
import '../repositories/mock_companion_repository.dart';
import '../../../core/constants/api_endpoints.dart';

// =========================================================================// SCREEN: Companion Detail
// =========================================================================// Chi tiết bài đăng + thông tin nhóm + nút gửi yêu cầu tham gia.
// =========================================================================
class CompanionDetailScreen extends StatefulWidget {
  const CompanionDetailScreen({
    super.key,
    required this.postId,
    this.repository,
  });
  final String postId;
  final CompanionRepository? repository;

  @override
  State<CompanionDetailScreen> createState() => _CompanionDetailScreenState();
}

class _CompanionDetailScreenState extends State<CompanionDetailScreen> {
  late final CompanionDetailViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = CompanionDetailViewModel(repository: widget.repository);
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

  bool _isLeader(CompanionPost post) {
    final id = AuthScope.of(context).user?.id;
    if (ApiEndpoints.useMockData && post.creator.id == 'current-user') {
      return true;
    }
    if (post.trip.members.any((m) => m.role == 'LEADER')) {
      return post.trip.members.any((m) => m.userId == id && m.role == 'LEADER');
    }
    return post.creator.id == id || post.creator.id == 'current-user';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancelRequest() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Huỷ yêu cầu tham gia?',
      message: 'Bạn có thể gửi lại nếu bài đăng vẫn nhận thành viên.',
      confirmLabel: 'Huỷ yêu cầu',
    );
    if (!confirmed || !mounted) return;
    if (!await _vm.cancelRequest() && mounted) {
      _showError(_vm.errorMessage ?? 'Không huỷ được yêu cầu');
    }
  }

  Future<void> _action(String action, CompanionPost post) async {
    if (action == 'report') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportScreen(
            reportedTripId: post.trip.id,
            reportedTripName: post.trip.name ?? post.title,
          ),
        ),
      );
      return;
    }
    if (action == 'edit') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateCompanionPostScreen(
            post: post,
            repository: widget.repository,
            tripId: post.trip.id,
            tripName: post.trip.name,
            tripDestination: post.trip.destination,
          ),
        ),
      );
      if (mounted) await _vm.load(widget.postId);
      return;
    }
    if (action == 'close') {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Đóng bài tuyển?',
        message:
            'Bài sẽ rời bảng tin và không nhận thêm yêu cầu. Thành viên chuyến đi được giữ nguyên.',
        confirmLabel: 'Đóng bài',
      );
      if (!confirmed || !mounted) return;
      try {
        final repo =
            widget.repository ??
            (ApiEndpoints.useMockData
                ? MockCompanionRepository()
                : ApiCompanionRepository());
        await repo.closePost(post.id);
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _openJoinSheet() {
    if (AuthScope.of(context).user?.hasVerifiedEkyc != true ||
        _vm.hasSentRequest) {
      return;
    }
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
    return AppScaffold(
      title: 'Chi tiết bài đăng',
      titleWidget: post == null ? null : _author(post),
      actions: [
        if (post != null && (!_isLeader(post) || !post.isClosed))
          PopupMenuButton<String>(
            tooltip: 'Thao tác bài đăng',
            onSelected: (value) => _action(value, post),
            itemBuilder: (_) => [
              if (_isLeader(post) && !post.isClosed) ...[
                const PopupMenuItem(value: 'edit', child: Text('Sửa bài đăng')),
                const PopupMenuItem(
                  value: 'close',
                  child: Text('Đóng bài tuyển'),
                ),
              ] else if (!_isLeader(post))
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Báo cáo bài đăng'),
                ),
            ],
          ),
      ],
      padding: EdgeInsets.zero,
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

  Widget _author(CompanionPost post) => Row(
    children: [
      AvatarPlaceholder(
        name: post.creator.displayName,
        imageUrl: post.creator.avatarUrl,
        radius: 18,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    post.creator.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (post.creator.isVerified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.verified_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            Text(
              DateFormat('HH:mm · dd/MM').format(post.createdAt),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildContent(CompanionPost post) {
    final text = Theme.of(context).textTheme;
    final trip = post.trip;
    final date = trip.startDate == null
        ? 'Chưa có lịch'
        : '${DateFormat('dd/MM/yyyy').format(trip.startDate!)}${trip.endDate == null ? '' : ' – ${DateFormat('dd/MM/yyyy').format(trip.endDate!)}'}';
    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (trip.coverImageUrl?.isNotEmpty == true)
            Align(
              alignment: Alignment.center,
              child: Image.network(
                trip.coverImageUrl!,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        height: 180,
                        child: Center(
                          child: Icon(
                            Icons.image_outlined,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 120,
                  child: Center(
                    child: Icon(
                      Icons.landscape_outlined,
                      size: 40,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _info(
                  Icons.location_on_outlined,
                  AppColors.inputSurface,
                  AppColors.primary,
                  'Điểm đến',
                  trip.destination ?? 'Chưa có điểm đến',
                ),
                const SizedBox(height: 14),
                _info(
                  Icons.calendar_today_outlined,
                  AppColors.inputSurface,
                  AppColors.primary,
                  'Thời gian',
                  '$date${trip.durationDays == null ? '' : ' (${trip.durationDays} ngày)'}',
                ),
                const SizedBox(height: 14),
                _info(
                  Icons.account_balance_wallet_outlined,
                  AppColors.inputSurface,
                  AppColors.primary,
                  'Ngân sách chung của chuyến đi',
                  trip.estimatedBudget == null
                      ? 'Chưa có dự kiến'
                      : '${NumberFormat('#,###', 'vi_VN').format(trip.estimatedBudget)} đ',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Divider(height: 1),
                ),
                Text(
                  'Nội dung',
                  style: text.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  post.displayTitle,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                if (post.content?.isNotEmpty == true) ...[
                  const SizedBox(height: 14),
                  Text(
                    post.content!,
                    style: text.bodyLarge?.copyWith(
                      height: 1.6,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppStatusBadge(
                    label: post.isClosed
                        ? 'Bài đăng đã đóng'
                        : post.isFull
                        ? 'Nhóm đã đủ thành viên'
                        : 'Còn ${post.slotsLeft} chỗ',
                    tone: post.isClosed
                        ? AppStatusTone.error
                        : post.isFull
                        ? AppStatusTone.warning
                        : AppStatusTone.success,
                  ),
                ),
                if (post.genderPreference != 'ANY' ||
                    post.minAge != null ||
                    post.maxAge != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Yêu cầu: ${post.genderPreference == 'MALE'
                        ? 'Nam'
                        : post.genderPreference == 'FEMALE'
                        ? 'Nữ'
                        : 'Bất kỳ giới tính'}'
                    '${post.minAge == null && post.maxAge == null ? '' : ' · Tuổi ${post.minAge ?? 16}–${post.maxAge ?? 'không giới hạn'}'}',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    post.tags.map((tag) => '#$tag').join('  '),
                    style: text.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Divider(height: 1),
                ),
                CompanionItineraryPreview(days: trip.itinerary, framed: false),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Divider(height: 1),
                ),
                Text(
                  'Thành viên · ${post.currentMembersCount}/${post.targetMembersCount}',
                  style: text.titleMedium,
                ),
                const SizedBox(height: 14),
                if (trip.members.isEmpty)
                  Text(
                    'Chưa có thông tin thành viên',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                else
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      for (final member in trip.members)
                        SizedBox(
                          width: 76,
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
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: text.bodySmall,
                              ),
                              if (member.role == 'LEADER')
                                Text(
                                  'Trưởng nhóm',
                                  style: text.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget? _buildBottomBar(CompanionPost post) {
    final user = AuthScope.of(context).user;
    if (post.creator.id == user?.id || post.creator.id == 'current-user') {
      return null;
    }
    final isMember = post.trip.members.any(
      (member) => member.userId == user?.id,
    );
    final verified = user?.hasVerifiedEkyc == true;
    final finished = ['COMPLETED', 'CANCELLED'].contains(post.trip.status);
    final label = isMember
        ? 'Đã tham gia'
        : _vm.requestStatus == 'PENDING'
        ? 'Đã gửi yêu cầu'
        : _vm.requestStatus == 'ACCEPTED'
        ? 'Yêu cầu đã được chấp nhận'
        : _vm.requestStatus == 'REJECTED'
        ? 'Yêu cầu đã bị từ chối'
        : post.isClosed
        ? 'Bài đăng đã đóng'
        : finished
        ? 'Chuyến đi đã kết thúc hoặc đã huỷ'
        : post.isFull
        ? 'Đoàn đã đủ thành viên'
        : !verified
        ? 'Cần xác minh eKYC để tham gia'
        : 'Gửi yêu cầu tham gia';
    final canJoin =
        verified &&
        !isMember &&
        !_vm.hasSentRequest &&
        !post.isClosed &&
        !finished &&
        !post.isFull;
    if (_vm.requestStatus == 'PENDING') {
      return AppActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Đã gửi yêu cầu'),
            const SizedBox(height: 8),
            CustomButton(
              text: 'Huỷ yêu cầu',
              variant: AppButtonVariant.secondary,
              isLoading: _vm.isSubmitting,
              onPressed: _vm.isSubmitting ? null : _cancelRequest,
            ),
          ],
        ),
      );
    }
    return AppActionBar(
      child: CustomButton(
        text: label,
        isLoading: _vm.isSubmitting,
        onPressed: canJoin && !_vm.isLoading ? _openJoinSheet : null,
      ),
    );
  }
}
