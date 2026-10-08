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
  const TripDetailScreen({super.key, required this.tripId, this.repository});
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
      success
          ? next == 'COMPLETED'
                ? 'Đã hoàn thành chuyến đi. Thông báo đã được gửi đến các thành viên.'
                : 'Đã bắt đầu chuyến đi. Thông báo đã được gửi đến các thành viên.'
          : _viewModel.errorMessage ?? 'Không cập nhật được trạng thái chuyến đi.',
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
      message: 'Bạn sẽ trở thành thành viên thường sau khi chuyển quyền. Trưởng nhóm mới phải là thành viên đã hoàn thành xác minh CCCD (eKYC).',
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
