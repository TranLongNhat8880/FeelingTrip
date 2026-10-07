import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/ui_kit.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../itinerary/views/itinerary_screen.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../viewmodels/trip_viewmodel.dart';
import 'trip_form_screen.dart';
import 'widgets/trip_widgets.dart';

class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({
    super.key,
    required this.tripId,
    this.repository,
  });
  final String tripId;
  final TripRepository? repository;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late final TripViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = TripViewModel(repository: widget.repository)
      ..addListener(_onChanged)
      ..loadTrip(widget.tripId);
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
      success ? 'Đã cập nhật trạng thái chuyến đi.' : _viewModel.errorMessage!,
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
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

  Future<void> _openCompanionPost(TripModel trip) async {
    if (AuthScope.of(context).user?.hasVerifiedEkyc != true) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cần xác minh hồ sơ'),
          content: const Text(
            'Bạn cần hoàn thành eKYC trước khi đăng bài tìm bạn đồng hành.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      AppRoutes.createCompanionPost,
      arguments: {
        'tripId': trip.id,
        'tripName': trip.name,
        'tripDestination': trip.destination,
      },
    );
  }

  Future<void> _transfer(TripMember member) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Chuyển quyền cho ${member.displayName}?',
      message: 'Bạn sẽ trở thành thành viên thường sau khi chuyển quyền.',
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
        const SizedBox(height: 6),
        Text(
          trip.description?.isNotEmpty == true
              ? trip.description!
              : 'Chuyến đi chưa có mô tả.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 18),
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
          text: 'Xem và lập lịch trình',
          icon: Icons.route_outlined,
          variant: AppButtonVariant.secondary,
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
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: 'Địa điểm & bản đồ',
                icon: Icons.explore_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => Navigator.pushNamed(context, AppRoutes.places),
              ),
            ),
            if (trip.isLeader &&
                !['COMPLETED', 'CANCELLED'].contains(trip.status)) ...[
              const SizedBox(width: 10),
              Expanded(
                child: CustomButton(
                  text: 'Tìm bạn đồng hành',
                  icon: Icons.group_add_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => _openCompanionPost(trip),
                ),
              ),
            ],
          ],
        ),
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
                  onRemove: trip.isLeader && !trip.members[index].isLeader
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
            text: 'Quản lý mã mời',
            icon: Icons.key_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => _showInviteCode(trip),
          ),
        ],
        if (canTransition) ...[
          const SizedBox(height: 12),
          CustomButton(
            text: trip.status == 'UPCOMING'
                ? 'Bắt đầu chuyến đi'
                : 'Hoàn thành chuyến đi',
            icon: trip.status == 'UPCOMING'
                ? Icons.play_arrow_rounded
                : Icons.flag_outlined,
            onPressed: _viewModel.isSubmitting ? null : () => _transition(trip),
          ),
        ],
        const SizedBox(height: 12),
        if (trip.isLeader && !['COMPLETED', 'CANCELLED'].contains(trip.status))
          CustomButton(
            text: 'Hủy chuyến đi',
            variant: AppButtonVariant.destructive,
            onPressed: _viewModel.isSubmitting ? null : _cancel,
          )
        else if (!trip.isLeader &&
            ['UPCOMING', 'ONGOING'].contains(trip.status))
          CustomButton(
            text: 'Rời chuyến đi',
            variant: AppButtonVariant.destructive,
            onPressed: _viewModel.isSubmitting ? null : _leave,
          ),
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
              'Mỗi mã chỉ dùng được một lần. Sau khi có người tham gia, hãy sinh mã mới.',
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
            text: 'Sinh mã mời mới',
            icon: Icons.refresh_rounded,
            isLoading: widget.viewModel.isSubmitting,
            onPressed: widget.viewModel.isSubmitting ? null : _generate,
          ),
      ],
    );
  }
}
