import 'package:flutter/material.dart';
import '../../../../core/utils/app_utils.dart';
import '../../../../shared/ui_kit.dart';
import '../../models/companion_post_model.dart';

class CompanionItineraryPreview extends StatelessWidget {
  const CompanionItineraryPreview({super.key, required this.days});
  final List<CompanionItineraryDay> days;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Lịch trình dự kiến',
          subtitle:
              'Xem điểm đến và giờ hoạt động trước khi gửi yêu cầu. Lịch trình có thể được nhóm điều chỉnh.',
        ),
        const SizedBox(height: 12),
        if (days.isEmpty)
          const AppInlineNotice(
            message:
                'Trưởng nhóm chưa thêm lịch trình. Hãy hỏi thêm kế hoạch trước khi quyết định tham gia.',
          ),
        for (final day in days)
          ExpansionTile(
            key: PageStorageKey('companion-day-${day.dayNumber}'),
            initiallyExpanded: day == days.first,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text('Ngày ${day.dayNumber} · ${day.title}'),
            subtitle: day.date == null
                ? null
                : Text(AppUtils.formatDate(day.date!)),
            children: [
              if (day.items.isEmpty)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Chưa thêm hoạt động cho ngày này.'),
                ),
              for (final item in day.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (item.startTime.isNotEmpty || item.endTime.isNotEmpty)
                        Text('${item.startTime} – ${item.endTime}'),
                      if (item.address?.isNotEmpty == true) Text(item.address!),
                      if (item.estimatedCost > 0)
                        Text(
                          'Dự kiến ${AppUtils.formatCurrency(item.estimatedCost)} cho cả nhóm',
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}
