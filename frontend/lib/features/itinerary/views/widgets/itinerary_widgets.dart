import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/ui_kit.dart';
import '../../models/itinerary_model.dart';

class ItineraryItemCard extends StatelessWidget {
  const ItineraryItemCard({
    super.key,
    required this.item,
    required this.position,
    required this.canEdit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onSmartSwap,
  });

  final ItineraryItem item;
  final int position;
  final bool canEdit;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onSmartSwap;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: item.isCompleted
                ? AppColors.success
                : AppColors.primary,
            foregroundColor: Colors.white,
            child: item.isCompleted
                ? const Icon(Icons.check_rounded, size: 18)
                : Text('${position + 1}'),
          ),
          Container(width: 2, height: 118, color: AppColors.primaryBorder),
        ],
      ),
      const SizedBox(width: 12),
      Expanded(
        child: AppCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          position == 0 ? 'Điểm bắt đầu' : 'Điểm tiếp theo',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.customName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                decoration: item.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (canEdit)
                    PopupMenuButton<String>(
                      tooltip: 'Tùy chọn điểm dừng',
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onEdit();
                          case 'swap':
                            onSmartSwap?.call();
                          case 'delete':
                            onDelete();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Chỉnh sửa'),
                        ),
                        if (onSmartSwap != null)
                          const PopupMenuItem(
                            value: 'swap',
                            child: Text('Đổi địa điểm thông minh'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Xóa điểm dừng'),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(
                    icon: Icons.schedule_rounded,
                    text: '${item.startTime} – ${item.endTime}',
                  ),
                  _Pill(
                    icon: Icons.category_outlined,
                    text: categoryLabel(item.category),
                  ),
                  if (item.estimatedCost > 0)
                    _Pill(
                      icon: Icons.payments_outlined,
                      text: AppUtils.formatCurrency(item.estimatedCost),
                    ),
                ],
              ),
              if (item.customAddress != null) ...[
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.customAddress!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              if (item.note != null) ...[
                const SizedBox(height: 8),
                Text(item.note!, style: Theme.of(context).textTheme.bodySmall),
              ],
              if (canEdit) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: onToggle,
                        icon: Icon(
                          item.isCompleted
                              ? Icons.undo_rounded
                              : Icons.check_circle_outline_rounded,
                        ),
                        label: Text(
                          item.isCompleted ? 'Chưa xong' : 'Hoàn thành',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đưa lên trước',
                      onPressed: onMoveUp,
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: 'Đưa xuống sau',
                      onPressed: onMoveDown,
                      icon: const Icon(Icons.arrow_downward_rounded),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
