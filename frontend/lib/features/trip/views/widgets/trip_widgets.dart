import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/ui_kit.dart';
import '../../models/trip_model.dart';

String tripStatusLabel(String status) => switch (status) {
  'UPCOMING' => 'Sắp diễn ra',
  'ONGOING' => 'Đang diễn ra',
  'COMPLETED' => 'Đã hoàn thành',
  'CANCELLED' => 'Đã hủy',
  _ => status,
};

AppStatusTone tripStatusTone(String status) => switch (status) {
  'UPCOMING' => AppStatusTone.info,
  'ONGOING' => AppStatusTone.success,
  'COMPLETED' => AppStatusTone.neutral,
  'CANCELLED' => AppStatusTone.error,
  _ => AppStatusTone.neutral,
};

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, required this.onTap});
  final TripModel trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    onTap: onTap,
    softShadow: true,
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            AppImage(
              url: trip.coverImageUrl,
              radius: 0,
              aspectRatio: 2.15,
              semanticLabel: 'Ảnh chuyến đi ${trip.name}',
            ),
            Positioned(
              top: 12,
              left: 12,
              child: AppStatusBadge(
                label: tripStatusLabel(trip.status),
                tone: tripStatusTone(trip.status),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: AppStatusBadge(
                label: trip.isLeader ? 'Trưởng nhóm' : 'Thành viên',
                tone: trip.isLeader
                    ? AppStatusTone.warning
                    : AppStatusTone.neutral,
                icon: trip.isLeader
                    ? Icons.workspace_premium_outlined
                    : Icons.person_outline,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _IconText(
                icon: Icons.location_on_outlined,
                text: trip.destination,
              ),
              const SizedBox(height: 6),
              _IconText(
                icon: Icons.calendar_month_outlined,
                text:
                    '${AppUtils.formatDate(trip.startDate)} – ${AppUtils.formatDate(trip.endDate)} · ${trip.totalDays} ngày',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      icon: Icons.group_outlined,
                      value: '${trip.memberCount}',
                      label: 'thành viên',
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      icon: Icons.account_balance_wallet_outlined,
                      value: AppUtils.formatCurrency(trip.estimatedBudget),
                      label: 'ngân sách',
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
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

class TripMemberTile extends StatelessWidget {
  const TripMemberTile({
    super.key,
    required this.member,
    this.onRemove,
    this.onTransfer,
  });
  final TripMember member;
  final VoidCallback? onRemove;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: AvatarPlaceholder(
      name: member.displayName,
      imageUrl: member.avatarUrl,
      radius: 22,
    ),
    title: Text(member.displayName),
    subtitle: Text(member.isLeader ? 'Trưởng nhóm' : 'Thành viên'),
    trailing: member.isLeader || (onRemove == null && onTransfer == null)
        ? AppStatusBadge(
            label: member.isLeader ? 'Leader' : 'Member',
            tone: member.isLeader
                ? AppStatusTone.warning
                : AppStatusTone.neutral,
          )
        : PopupMenuButton<String>(
            tooltip: 'Quản lý thành viên',
            onSelected: (value) {
              if (value == 'transfer') onTransfer?.call();
              if (value == 'remove') onRemove?.call();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'transfer',
                child: Text('Chuyển quyền trưởng nhóm'),
              ),
              PopupMenuItem(
                value: 'remove',
                child: Text('Loại khỏi chuyến đi'),
              ),
            ],
          ),
  );
}

class _IconText extends StatelessWidget {
  const _IconText({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: AppColors.textSecondary),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 6),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    ],
  );
}
