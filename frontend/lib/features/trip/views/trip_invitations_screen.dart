import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_utils.dart';
import '../../../shared/ui_kit.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../viewmodels/trip_viewmodel.dart';

class TripInvitationsScreen extends StatefulWidget {
  const TripInvitationsScreen({super.key, this.repository});
  final TripRepository? repository;

  @override
  State<TripInvitationsScreen> createState() => _TripInvitationsScreenState();
}

class _TripInvitationsScreenState extends State<TripInvitationsScreen> {
  late final TripViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = TripViewModel(repository: widget.repository)
      ..addListener(_onChanged)
      ..loadMyInvitations();
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

  Future<void> _respond(TripInvitation invitation, bool accept) async {
    final success = await _viewModel.respondInvitation(
      invitation.id,
      accept: accept,
    );
    if (!mounted) return;
    AppFeedback.show(
      context,
      success
          ? accept
                ? 'Đã tham gia chuyến đi.'
                : 'Đã từ chối lời mời.'
          : _viewModel.errorMessage!,
      tone: success ? AppStatusTone.success : AppStatusTone.error,
    );
  }

  @override
  Widget build(BuildContext context) =>
      AppScaffold(title: 'Lời mời của tôi', body: _content());

  Widget _content() {
    if (_viewModel.isLoading && _viewModel.invitations.isEmpty) {
      return const Center(
        child: LoadingIndicator(message: 'Đang tải lời mời...'),
      );
    }
    if (_viewModel.errorMessage != null && _viewModel.invitations.isEmpty) {
      return ErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadMyInvitations,
      );
    }
    if (_viewModel.invitations.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.mark_email_read_outlined,
        title: 'Không có lời mời đang chờ',
        message: 'Lời mời mới từ các trưởng nhóm sẽ xuất hiện tại đây.',
      );
    }
    return RefreshIndicator(
      onRefresh: _viewModel.loadMyInvitations,
      child: ListView.separated(
        itemCount: _viewModel.invitations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, index) {
          final item = _viewModel.invitations[index];
          return AppCard(
            outlined: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.luggage_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.tripName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.destination,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('${item.inviterName} mời bạn tham gia chuyến đi này.'),
                if (item.expiresAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Hết hạn: ${AppUtils.formatDateTime(item.expiresAt!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Từ chối',
                        variant: AppButtonVariant.secondary,
                        onPressed: _viewModel.isSubmitting
                            ? null
                            : () => _respond(item, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomButton(
                        text: 'Chấp nhận',
                        onPressed: _viewModel.isSubmitting
                            ? null
                            : () => _respond(item, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
