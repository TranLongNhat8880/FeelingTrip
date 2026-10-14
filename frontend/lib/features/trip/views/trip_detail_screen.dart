import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../companion/repositories/companion_trip_repository.dart';
import '../../itinerary/views/itinerary_screen.dart';
import '../../review/models/review_model.dart';
import '../../review/viewmodels/review_viewmodel.dart';
import '../../review/views/report_screen.dart';
import '../../review/views/review_form_screen.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../viewmodels/trip_viewmodel.dart';
import 'trip_form_screen.dart';
import 'widgets/trip_widgets.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId, this.repository});
  final String tripId;
  final TripRepository? repository;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final TripViewModel _viewModel;
  String _section = 'overview';
  bool _hasCompanionPost = false;
  bool _checkingPost = false;
  bool _postCheckFailed = false;
  bool _hasReviewedTrip = false;
  final Set<String> _reviewedMemberIds = {};

  @override
  void initState() {
    super.initState();
    _viewModel = TripViewModel(repository: widget.repository)
      ..addListener(_onChanged)
      ..loadTrip(widget.tripId);
    _checkCompanionPost();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _edit(TripModel trip) async {
    final result = await Navigator.push<TripModel>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            TripFormScreen(repository: widget.repository, trip: trip),
      ),
    );
    if (result != null) await _viewModel.loadTrip(widget.tripId);
  }

  Future<void> _transition(TripModel trip) async {
    final next = trip.status == 'UPCOMING' ? 'ONGOING' : 'COMPLETED';
    final confirmed = await AppConfirmDialog.show(
      context,
      title: next == 'ONGOING' ? 'Bắt đầu chuyến đi?' : 'Hoàn thành chuyến đi?',
      message: next == 'ONGOING'
          ? 'Trạng thái sẽ chuyển sang đang diễn ra.'
          : 'Sau khi hoàn thành, chuyến đi và lịch trình sẽ chỉ còn chế độ xem.',
      confirmLabel: next == 'ONGOING' ? 'Bắt đầu' : 'Hoàn thành',
    );
    if (!confirmed) return;
    final success = await _viewModel.transitionStatus(next);
    if (!mounted) return;
    AppFeedback.show(
      context,
      success
          ? next == 'COMPLETED'
                ? 'Đã hoàn thành chuyến đi. Thông báo đã được gửi đến các thành viên.'
                : 'Đã bắt đầu chuyến đi. Thông báo đã được gửi đến các thành viên.'
          : _viewModel.errorMessage ??
                'Không cập nhật được trạng thái chuyến đi.',
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
    if (success && next == 'COMPLETED') {
      final shouldReview = await AppConfirmDialog.show(
        context,
        title: 'Chúc mừng hoàn thành chuyến đi! 🎉',
        message:
            'Cảm ơn bạn và cả đoàn đã đồng hành cùng nhau trong chuyến đi "${trip.name}". Bạn có muốn dành ít phút để đánh giá trải nghiệm chuyến đi ngay bây giờ không?',
        confirmLabel: 'Đánh giá ngay',
      );
      if (shouldReview && mounted) {
        final currentTrip = _viewModel.selectedTrip ?? trip;
        await _reviewTrip(currentTrip);
      }
    }
  }

  Future<void> _cancel() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Hủy chuyến đi?',
      message:
          'Các thành viên sẽ nhận được thông báo. Thao tác này không thể hoàn tác.',
      confirmLabel: 'Hủy chuyến',
      destructive: true,
    );
    if (!confirmed) return;
    final success = await _viewModel.cancelTrip();
    if (!mounted) return;
    AppFeedback.show(
      context,
      success ? 'Chuyến đi đã được hủy.' : _viewModel.errorMessage!,
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  Future<void> _leave() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Rời chuyến đi?',
      message: 'Bạn chỉ có thể rời nhóm khi không còn công nợ đang mở.',
      confirmLabel: 'Rời nhóm',
      destructive: true,
    );
    if (!confirmed) return;
    final success = await _viewModel.leaveTrip();
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
    } else {
      AppFeedback.show(
        context,
        _viewModel.errorMessage!,
        tone: AppStatusTone.error,
      );
    }
  }

  Future<void> _remove(TripMember member) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Loại ${member.displayName}?',
      message: 'Thành viên chỉ bị loại khi không còn công nợ đang mở.',
      confirmLabel: 'Loại thành viên',
      destructive: true,
    );
    if (!confirmed) return;
    final success = await _viewModel.kickMember(member.userId);
    if (!mounted) return;
    AppFeedback.show(
      context,
      success ? 'Đã loại thành viên khỏi chuyến đi.' : _viewModel.errorMessage!,
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  Future<void> _checkCompanionPost() async {
    if (_checkingPost) return;
    setState(() => _checkingPost = true);
    try {
      final exists = await CompanionTripRepository().hasPostForTrip(
        widget.tripId,
      );
      if (mounted) {
        setState(() {
          _hasCompanionPost = exists;
          _postCheckFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _postCheckFailed = true);
    } finally {
      if (mounted) setState(() => _checkingPost = false);
    }
  }

  Future<void> _openCompanionPost(TripModel trip) async {
    if (AuthScope.of(context).user?.hasVerifiedEkyc != true) {
      await AppMessageDialog.show(
        context,
        title: 'Cần xác minh hồ sơ',
        message:
            'Bạn cần hoàn thành eKYC trước khi đăng bài tìm bạn đồng hành.',
        tone: AppStatusTone.warning,
      );
      return;
    }
    if (!mounted) return;
    if (!trip.isPublic) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'Chuyển sang công khai?',
        message:
            'Chuyến đi này hiện đang là Nhóm riêng tư. Để đăng bài tìm bạn đồng hành từ cộng đồng, chuyến đi sẽ được chuyển sang chế độ Công khai. Bạn có muốn tiếp tục?',
        confirmLabel: 'Đồng ý & Đăng bài',
      );
      if (!confirmed) return;
    }
    if (!mounted) return;
    await _checkCompanionPost();
    if (!mounted || _hasCompanionPost || _postCheckFailed) return;
    await Navigator.pushNamed(
      context,
      AppRoutes.createCompanionPost,
      arguments: {
        'tripId': trip.id,
        'tripName': trip.name,
        'tripDestination': trip.destination,
      },
    );
    if (mounted) {
      await _checkCompanionPost();
      await _viewModel.loadTrip(widget.tripId);
    }
  }

  Future<void> _transfer(TripMember member) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Chuyển quyền cho ${member.displayName}?',
      message:
          'Bạn sẽ trở thành thành viên thường sau khi chuyển quyền. Trưởng nhóm mới phải là thành viên đã hoàn thành xác minh CCCD (eKYC).',
      confirmLabel: 'Chuyển quyền',
    );
    if (!confirmed) return;
    final success = await _viewModel.transferLeader(member.userId);
    if (!mounted) return;
    AppFeedback.show(
      context,
      success ? 'Đã chuyển quyền trưởng nhóm.' : _viewModel.errorMessage!,
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  Future<void> _reviewTrip(TripModel trip) async {
    final review = await Navigator.push<ReviewModel>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewFormScreen(tripId: trip.id, tripName: trip.name),
      ),
    );

    if (!mounted || review == null) return;
    setState(() => _hasReviewedTrip = true);
    AppFeedback.show(
      context,
      'Đã gửi đánh giá chuyến đi.',
      tone: AppStatusTone.success,
    );
  }

  Future<void> _reviewMember(TripModel trip, TripMember member) async {
    final review = await Navigator.push<ReviewModel>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewFormScreen(
          tripId: trip.id,
          tripName: trip.name,
          revieweeId: member.userId,
          revieweeName: member.displayName,
        ),
      ),
    );

    if (!mounted || review == null) return;
    setState(() => _reviewedMemberIds.add(member.userId));
    AppFeedback.show(
      context,
      'Đã đánh giá ${member.displayName}.',
      tone: AppStatusTone.success,
    );
  }

  Future<void> _reportMember(TripModel trip, TripMember member) async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          reportedUserId: member.userId,
          reportedUserName: member.displayName,
          reportedTripId: trip.id,
          reportedTripName: trip.name,
        ),
      ),
    );

    if (!mounted || submitted != true) return;
    AppFeedback.show(
      context,
      'Báo cáo đã được gửi tới quản trị viên.',
      tone: AppStatusTone.success,
    );
  }

  Future<void> _reportTrip(TripModel trip) async {
    final submitted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ReportScreen(reportedTripId: trip.id, reportedTripName: trip.name),
      ),
    );

    if (!mounted || submitted != true) return;
    AppFeedback.show(
      context,
      'Báo cáo chuyến đi đã được gửi tới quản trị viên.',
      tone: AppStatusTone.success,
    );
  }

  Future<void> _blockMember(TripMember member) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Chặn ${member.displayName}?',
      message:
          'Người dùng này sẽ được thêm vào danh sách chặn của bạn. Bạn có thể bỏ chặn trong hồ sơ cá nhân.',
      confirmLabel: 'Chặn người dùng',
      destructive: true,
    );

    if (!confirmed) return;

    final viewModel = ReviewViewModel();
    final success = await viewModel.blockUser(member.userId);
    final errorMessage = viewModel.errorMessage;
    viewModel.dispose();

    if (!mounted) return;
    AppFeedback.show(
      context,
      success
          ? 'Đã chặn ${member.displayName}.'
          : errorMessage ?? 'Không thể chặn người dùng.',
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = _viewModel.selectedTrip;
    return AppScaffold(
      title: trip?.name ?? 'Chi tiết chuyến đi',
      actions: [
        if (trip?.isEditable == true)
          IconButton(
            tooltip: 'Chỉnh sửa chuyến đi',
            onPressed: () => _edit(trip!),
            icon: const Icon(Icons.edit_outlined),
          ),
        if (trip != null)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Tùy chọn khác',
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  _edit(trip);
                  break;
                case 'cancel':
                  _cancel();
                  break;
                case 'leave':
                  _leave();
                  break;
                case 'report':
                  _reportTrip(trip);
                  break;
              }
            },
            itemBuilder: (context) => [
              if (trip.isEditable)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Chỉnh sửa thông tin'),
                    ],
                  ),
                ),
              if (trip.isLeader &&
                  !['COMPLETED', 'CANCELLED'].contains(trip.status))
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 20, color: AppColors.error),
                      SizedBox(width: 10),
                      Text(
                        'Hủy chuyến đi',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              if (!trip.isLeader &&
                  ['UPCOMING', 'ONGOING'].contains(trip.status))
                const PopupMenuItem(
                  value: 'leave',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app_rounded, size: 20, color: AppColors.error),
                      SizedBox(width: 10),
                      Text(
                        'Rời chuyến đi',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              if (!trip.isLeader)
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.report_outlined, size: 20),
                      SizedBox(width: 10),
                      Text('Báo cáo chuyến đi'),
                    ],
                  ),
                ),
            ],
          ),
      ],
      scrollable: true,
      body: _body(trip),
    );
  }

  Widget _body(TripModel? trip) {
    if (_viewModel.isLoading && trip == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 160),
        child: LoadingIndicator(message: 'Đang tải chuyến đi...'),
      );
    }
    if (trip == null) {
      return ErrorState(
        message: _viewModel.errorMessage ?? 'Không tìm thấy chuyến đi.',
        onRetry: () => _viewModel.loadTrip(widget.tripId),
      );
    }
    final canTransition =
        trip.isLeader && ['UPCOMING', 'ONGOING'].contains(trip.status);
    final currentUserId = AuthScope.of(context).user?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            AppImage(
              url: trip.coverImageUrl,
              aspectRatio: 1.75,
              semanticLabel: 'Ảnh chuyến đi ${trip.name}',
            ),
            Positioned(
              top: 14,
              left: 14,
              child: AppStatusBadge(
                label: tripStatusLabel(trip.status),
                tone: tripStatusTone(trip.status),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(trip.name, style: Theme.of(context).textTheme.headlineSmall),

        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppStatusBadge(
              label: trip.isLeader ? 'Bạn là trưởng nhóm' : 'Bạn là thành viên',
              tone: AppStatusTone.info,
            ),
            AppStatusBadge(
              label: '${trip.memberCount} thành viên · ${trip.totalDays} ngày',
              tone: AppStatusTone.neutral,
            ),
          ],
        ),
        const SizedBox(height: 20),
        AppChoiceChips<String>(
          options: const {
            'overview': 'Tổng quan',
            'members': 'Thành viên',
          },
          selected: {_section == 'members' ? 'members' : 'overview'},
          onChanged: (value) => setState(() => _section = value),
        ),
        const SizedBox(height: 16),
        if (_viewModel.errorMessage != null)
          AppInlineNotice(
            message: _viewModel.errorMessage!,
            tone: AppStatusTone.error,
          ),
        if (_section != 'members') ...[
          const SizedBox(height: 6),
          Text(
            trip.description?.isNotEmpty == true
                ? trip.description!
                : 'Chuyến đi chưa có mô tả.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (canTransition) ...[
            AppCard(
              color: trip.status == 'UPCOMING'
                  ? AppColors.primarySurface
                  : AppColors.successSurface,
              outlined: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (trip.status == 'UPCOMING'
                                  ? AppColors.primary
                                  : AppColors.success)
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          trip.status == 'UPCOMING'
                              ? Icons.play_arrow_rounded
                              : Icons.flag_rounded,
                          color: trip.status == 'UPCOMING'
                              ? AppColors.primary
                              : AppColors.success,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.status == 'UPCOMING'
                                  ? 'Sẵn sàng khởi hành'
                                  : 'Chuyến đi đang diễn ra',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: trip.status == 'UPCOMING'
                                        ? AppColors.primary
                                        : AppColors.success,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              trip.status == 'UPCOMING'
                                  ? 'Bấm để chuyển trạng thái sang đang diễn ra.'
                                  : 'Đánh dấu hoàn thành khi chuyến đi kết thúc.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CustomButton(
                    text: trip.status == 'UPCOMING'
                        ? 'Bắt đầu chuyến đi'
                        : 'Hoàn thành chuyến đi',
                    icon: trip.status == 'UPCOMING'
                        ? Icons.play_arrow_rounded
                        : Icons.flag_outlined,
                    onPressed: _viewModel.isSubmitting
                        ? null
                        : () => _transition(trip),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (['COMPLETED', 'CANCELLED'].contains(trip.status)) ...[
            AppInlineNotice(
              message: trip.status == 'COMPLETED'
                  ? 'Chuyến đi đã kết thúc. Bạn có thể xem lại lịch trình và đánh giá.'
                  : 'Chuyến đi đã hủy. Thông tin được lưu lại để tra cứu.',
            ),
            const SizedBox(height: 14),
          ],
          AppCard(
            outlined: true,
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Điểm đến',
                  value: trip.destination,
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: 'Thời gian',
                  value:
                      '${AppUtils.formatDate(trip.startDate)} – ${AppUtils.formatDate(trip.endDate)}',
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.timelapse_outlined,
                  label: 'Thời lượng',
                  value: '${trip.totalDays} ngày',
                ),
                const Divider(),
                InfoRow(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Ngân sách',
                  value: AppUtils.formatCurrency(trip.estimatedBudget),
                ),
                const Divider(),
                InfoRow(
                  icon: trip.isPublic ? Icons.public : Icons.lock_outline,
                  label: 'Quyền riêng tư',
                  value: trip.isPublic ? 'Công khai' : 'Riêng tư',
                ),
              ],
            ),
          ),
          if (trip.isClone) ...[
            const SizedBox(height: 12),
            const AppInlineNotice(
              message: 'Chuyến đi này được tạo từ một lịch trình cộng đồng.',
            ),
          ],
          const SizedBox(height: 14),
          CustomButton(
            text: trip.isEditable ? 'Lập và xem lịch trình' : 'Xem lịch trình',
            icon: Icons.route_outlined,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ItineraryScreen(
                  tripId: trip.id,
                  destination: trip.destination,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'Chi phí và thanh toán',
            icon: Icons.account_balance_wallet_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.expenses,
              arguments: {'tripId': trip.id},
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Địa điểm & bản đồ',
                  icon: Icons.explore_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.places),
                ),
              ),
              if (trip.isLeader &&
                  trip.isPublic &&
                  !_hasCompanionPost &&
                  !['COMPLETED', 'CANCELLED'].contains(trip.status)) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    text: _postCheckFailed
                        ? 'Kiểm tra lại bài tuyển'
                        : (trip.isPublic
                            ? 'Tìm bạn đồng hành'
                            : 'Công khai & Tìm bạn'),
                    icon: Icons.group_add_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _checkingPost
                        ? null
                        : () => _openCompanionPost(trip),
                  ),
                ),
              ],
              if (trip.isLeader &&
                  _hasCompanionPost &&
                  !['COMPLETED', 'CANCELLED'].contains(trip.status)) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: CustomButton(
                    text: 'Duyệt ghép đoàn',
                    icon: Icons.people_outline,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.companionRequests,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (trip.status == 'COMPLETED') ...[
            const SizedBox(height: 10),
            CustomButton(
              text: _hasReviewedTrip
                  ? 'Đã gửi đánh giá chuyến đi'
                  : 'Đánh giá chuyến đi',
              icon: _hasReviewedTrip
                  ? Icons.check_circle_outline
                  : Icons.star_outline_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: _hasReviewedTrip ? null : () => _reviewTrip(trip),
            ),
            Builder(
              builder: (context) {
                final otherMembers = trip.members
                    .where((m) => m.userId != currentUserId)
                    .toList();
                if (otherMembers.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    const SectionHeader(
                      title: 'Đánh giá bạn đồng hành',
                      subtitle:
                          'Chia sẻ trải nghiệm đồng hành cùng các thành viên trong chuyến đi.',
                    ),
                    const SizedBox(height: 8),
                    AppCard(
                      outlined: true,
                      child: Column(
                        children: [
                          for (var i = 0; i < otherMembers.length; i++) ...[
                            Builder(
                              builder: (context) {
                                final member = otherMembers[i];
                                final isReviewed =
                                    _reviewedMemberIds.contains(member.userId);
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: AvatarPlaceholder(
                                    name: member.displayName,
                                    imageUrl: member.avatarUrl,
                                    radius: 20,
                                  ),
                                  title: Text(member.displayName),
                                  subtitle: Text(
                                    member.isLeader ? 'Trưởng nhóm' : 'Thành viên',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                  trailing: isReviewed
                                      ? const AppStatusBadge(
                                          label: 'Đã đánh giá',
                                          tone: AppStatusTone.success,
                                        )
                                      : TextButton.icon(
                                          onPressed: () =>
                                              _reviewMember(trip, member),
                                          icon: const Icon(
                                            Icons.star_outline_rounded,
                                            size: 18,
                                          ),
                                          label: const Text('Đánh giá'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                          ),
                                        ),
                                );
                              },
                            ),
                            if (i < otherMembers.length - 1) const Divider(),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          if (!trip.isLeader) ...[
            const SizedBox(height: 10),
            CustomButton(
              text: 'Báo cáo chuyến đi',
              icon: Icons.report_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => _reportTrip(trip),
            ),
          ],
          if (trip.isLeader &&
              !['COMPLETED', 'CANCELLED'].contains(trip.status)) ...[
            const SizedBox(height: 16),
            CustomButton(
              text: 'Hủy chuyến đi',
              icon: Icons.cancel_outlined,
              variant: AppButtonVariant.destructive,
              onPressed: _viewModel.isSubmitting ? null : _cancel,
            ),
          ] else if (!trip.isLeader &&
              ['UPCOMING', 'ONGOING'].contains(trip.status)) ...[
            const SizedBox(height: 16),
            CustomButton(
              text: 'Rời chuyến đi',
              icon: Icons.exit_to_app_rounded,
              variant: AppButtonVariant.destructive,
              onPressed: _viewModel.isSubmitting ? null : _leave,
            ),
          ],
        ],
        if (_section == 'members') ...[
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Thành viên (${trip.members.length})',
            subtitle: trip.isLeader
                ? 'Bạn có thể quản lý thành viên của nhóm.'
                : 'Danh sách người đang tham gia chuyến đi.',
          ),
          const SizedBox(height: 8),
          AppCard(
            outlined: true,
            child: Column(
              children: [
                for (var index = 0; index < trip.members.length; index++) ...[
                  TripMemberTile(
                    member: trip.members[index],
                    onReview:
                        trip.status == 'COMPLETED' &&
                            trip.members[index].userId != currentUserId &&
                            !_reviewedMemberIds.contains(trip.members[index].userId)
                        ? () => _reviewMember(trip, trip.members[index])
                        : null,
                    onReport: trip.members[index].userId != currentUserId
                        ? () => _reportMember(trip, trip.members[index])
                        : null,
                    onBlock: trip.members[index].userId != currentUserId
                        ? () => _blockMember(trip.members[index])
                        : null,
                    onRemove:
                        trip.isLeader &&
                            !['COMPLETED', 'CANCELLED'].contains(trip.status) &&
                            !trip.members[index].isLeader
                        ? () => _remove(trip.members[index])
                        : null,
                    onTransfer: trip.isEditable && !trip.members[index].isLeader
                        ? () => _transfer(trip.members[index])
                        : null,
                  ),
                  if (index < trip.members.length - 1) const Divider(),
                ],
              ],
            ),
          ),
          if (trip.isLeader &&
              !trip.isPublic &&
              ['UPCOMING', 'ONGOING'].contains(trip.status)) ...[
            const SizedBox(height: 14),
            CustomButton(
              text: 'Quản lý lời mời',
              icon: Icons.person_add_alt_1_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => _showInvitations(trip),
            ),
            const SizedBox(height: 10),
            CustomButton(
              text: 'Quản lý mã mời',
              icon: Icons.key_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => _showInviteCode(trip),
            ),
          ],
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _showInviteCode(TripModel trip) async {
    await AppBottomSheet.show<void>(
      context,
      title: 'Mã mời tham gia',
      child: _InviteCodeContent(viewModel: _viewModel, trip: trip),
    );
  }

  Future<void> _showInvitations(TripModel trip) async {
    await AppBottomSheet.show<void>(
      context,
      title: 'Quản lý lời mời',
      child: _TripInvitationManagementContent(
        viewModel: _viewModel,
        trip: trip,
      ),
    );
  }
}

class _TripInvitationManagementContent extends StatefulWidget {
  const _TripInvitationManagementContent({
    required this.viewModel,
    required this.trip,
  });

  final TripViewModel viewModel;
  final TripModel trip;

  @override
  State<_TripInvitationManagementContent> createState() =>
      _TripInvitationManagementContentState();
}

class _TripInvitationManagementContentState
    extends State<_TripInvitationManagementContent> {
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  int _expiresInHours = 72;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onChanged);
    widget.viewModel.loadTripInvitations(widget.trip.id);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onChanged);
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_formKey.currentState?.validate() != true) return;
    final success = await widget.viewModel.sendTripInvitation(
      _userIdController.text,
      expiresInHours: _expiresInHours,
    );
    if (!mounted) return;
    if (success) {
      _userIdController.clear();
      AppFeedback.show(
        context,
        'Đã gửi lời mời tham gia chuyến đi.',
        tone: AppStatusTone.success,
      );
    } else {
      AppFeedback.show(
        context,
        widget.viewModel.errorMessage ?? 'Không gửi được lời mời.',
        tone: AppStatusTone.error,
      );
    }
  }

  Future<void> _revoke(TripInvitation invitation) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Thu hồi lời mời?',
      message:
          'Lời mời gửi tới ${invitation.inviteeName ?? 'người dùng này'} sẽ không còn hiệu lực.',
      confirmLabel: 'Thu hồi',
      destructive: true,
    );
    if (!confirmed) return;
    final success = await widget.viewModel.revokeTripInvitation(invitation.id);
    if (!mounted) return;
    AppFeedback.show(
      context,
      success
          ? 'Đã thu hồi lời mời.'
          : widget.viewModel.errorMessage ?? 'Không thu hồi được lời mời.',
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final invitations = widget.viewModel.tripInvitations;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppInlineNotice(
            message:
                'Gửi lời mời trực tiếp bằng mã người dùng. Người nhận có thể chấp nhận hoặc từ chối trong mục Lời mời của tôi.',
          ),
          const SizedBox(height: 18),
          CustomTextField(
            label: 'Mã người dùng',
            hint: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
            controller: _userIdController,
            prefixIcon: Icons.person_search_outlined,
            helperText: 'Nhập UUID được chia sẻ từ hồ sơ người nhận.',
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _send(),
            validator: (value) {
              final normalized = value?.trim() ?? '';
              if (normalized.isEmpty) return 'Vui lòng nhập mã người dùng.';
              if (!_uuidPattern.hasMatch(normalized)) {
                return 'Mã người dùng không đúng định dạng UUID.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Text(
            'Thời hạn lời mời',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [24, 72, 168])
                ChoiceChip(
                  label: Text(
                    option == 168 ? '7 ngày' : '${option ~/ 24} ngày',
                  ),
                  selected: _expiresInHours == option,
                  onSelected: widget.viewModel.isSubmitting
                      ? null
                      : (_) => setState(() => _expiresInHours = option),
                ),
            ],
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: 'Gửi lời mời',
            icon: Icons.send_outlined,
            isLoading: widget.viewModel.isSubmitting,
            onPressed: widget.viewModel.isSubmitting ? null : _send,
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Đang chờ phản hồi (${invitations.length})',
            subtitle: 'Bạn có thể thu hồi các lời mời chưa được phản hồi.',
          ),
          const SizedBox(height: 10),
          if (widget.viewModel.isLoadingTripInvitations)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: LoadingIndicator(message: 'Đang tải lời mời...'),
            )
          else if (widget.viewModel.errorMessage != null && invitations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: ErrorState(
                message: widget.viewModel.errorMessage!,
                onRetry: () =>
                    widget.viewModel.loadTripInvitations(widget.trip.id),
              ),
            )
          else if (invitations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: EmptyStateWidget(
                icon: Icons.mark_email_unread_outlined,
                title: 'Chưa có lời mời đang chờ',
                message: 'Lời mời mới sẽ xuất hiện tại đây sau khi gửi.',
              ),
            )
          else
            for (var index = 0; index < invitations.length; index++) ...[
              _TripInvitationTile(
                invitation: invitations[index],
                enabled: !widget.viewModel.isSubmitting,
                onRevoke: () => _revoke(invitations[index]),
              ),
              if (index < invitations.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _TripInvitationTile extends StatelessWidget {
  const _TripInvitationTile({
    required this.invitation,
    required this.enabled,
    required this.onRevoke,
  });

  final TripInvitation invitation;
  final bool enabled;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) => AppCard(
    outlined: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: AppColors.primarySurface,
          child: Text(
            (invitation.inviteeName?.trim().isNotEmpty == true
                    ? invitation.inviteeName!.trim()[0]
                    : '?')
                .toUpperCase(),
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invitation.inviteeName ?? 'Người được mời',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (invitation.expiresAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Hết hạn: ${AppUtils.formatDateTime(invitation.expiresAt!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 7),
              const AppStatusBadge(
                label: 'Đang chờ',
                tone: AppStatusTone.warning,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Thu hồi lời mời',
          onPressed: enabled ? onRevoke : null,
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.error,
        ),
      ],
    ),
  );
}

class _InviteCodeContent extends StatefulWidget {
  const _InviteCodeContent({required this.viewModel, required this.trip});
  final TripViewModel viewModel;
  final TripModel trip;

  @override
  State<_InviteCodeContent> createState() => _InviteCodeContentState();
}

class _InviteCodeContentState extends State<_InviteCodeContent> {
  String? _code;
  String? _status;

  @override
  void initState() {
    super.initState();
    _code = widget.trip.inviteCode;
    _status = widget.trip.inviteCodeStatus;
  }

  Future<void> _generate() async {
    final code = await widget.viewModel.generateInviteCode();
    if (!mounted) return;
    if (code != null) {
      setState(() {
        _code = code;
        _status = 'ACTIVE';
      });
    } else {
      AppFeedback.show(
        context,
        widget.viewModel.errorMessage ?? 'Không tạo được mã mời.',
        tone: AppStatusTone.error,
      );
    }
  }

  Future<void> _revoke() async {
    final success = await widget.viewModel.revokeInviteCode();
    if (!mounted) return;
    if (success) {
      setState(() => _status = 'REVOKED');
    } else {
      AppFeedback.show(
        context,
        widget.viewModel.errorMessage!,
        tone: AppStatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _code != null && _status == 'ACTIVE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppInlineNotice(
          message:
              'Mỗi mã chỉ dùng được một lần. Sau khi có người tham gia, hãy tạo mã mới.',
        ),
        const SizedBox(height: 18),
        AppCard(
          color: AppColors.primarySurface,
          child: Column(
            children: [
              Text(
                active ? _code! : 'Chưa có mã đang hoạt động',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: active ? 5 : 0,
                ),
              ),
              if (_status != null) ...[
                const SizedBox(height: 8),
                AppStatusBadge(
                  label: switch (_status) {
                    'ACTIVE' => 'Đang hoạt động',
                    'USED' => 'Đã sử dụng',
                    'REVOKED' => 'Đã thu hồi',
                    _ => 'Chưa tạo',
                  },
                  tone: active ? AppStatusTone.success : AppStatusTone.neutral,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (active) ...[
          CustomButton(
            text: 'Sao chép mã',
            icon: Icons.copy_rounded,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _code!));
              if (context.mounted) {
                AppFeedback.show(
                  context,
                  'Đã sao chép mã mời.',
                  tone: AppStatusTone.success,
                );
              }
            },
          ),
          const SizedBox(height: 10),
          CustomButton(
            text: 'Thu hồi mã',
            variant: AppButtonVariant.secondary,
            onPressed: widget.viewModel.isSubmitting ? null : _revoke,
          ),
        ] else
          CustomButton(
            text: 'Tạo mã mời mới',
            icon: Icons.refresh_rounded,
            isLoading: widget.viewModel.isSubmitting,
            onPressed: widget.viewModel.isSubmitting ? null : _generate,
          ),
      ],
    );
  }
}
