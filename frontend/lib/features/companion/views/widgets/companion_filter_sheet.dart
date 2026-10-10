import 'package:flutter/material.dart';
import 'package:feeling_trip/shared/ui_kit.dart';

// ================================================================================
// WIDGET: CompanionFilterSheet
// ================================================================================
// Bottom sheet để lọc feed (sort, status, gender).
// ================================================================================

class CompanionFilterSheet extends StatefulWidget {
  const CompanionFilterSheet({
    super.key,
    required this.currentSortBy,
    required this.currentStatus,
    required this.currentGender,
    required this.onApply,
  });

  final String currentSortBy;
  final String currentStatus;
  final String currentGender;
  final void Function({
    String? sortBy,
    String? status,
    String? genderPreference,
  })
  onApply;

  @override
  State<CompanionFilterSheet> createState() => _CompanionFilterSheetState();
}

class _CompanionFilterSheetState extends State<CompanionFilterSheet> {
  late String _sortBy;
  late String _status;
  late String _gender;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.currentSortBy;
    _status = widget.currentStatus;
    _gender = widget.currentGender;
  }

  void _apply() {
    widget.onApply(sortBy: _sortBy, status: _status, genderPreference: _gender);
    Navigator.pop(context);
  }

  void _reset() {
    setState(() {
      _sortBy = 'newest';
      _status = 'OPEN';
      _gender = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppBottomSheet(
      title: 'Bộ lọc',
      bottomAction: CustomButton(text: 'Áp dụng bộ lọc', onPressed: _apply),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Chọn cách hiển thị chuyến đi.',
                  style: text.bodyMedium,
                ),
              ),
              CustomButton(
                text: 'Đặt lại',
                variant: AppButtonVariant.text,
                fullWidth: false,
                onPressed: _reset,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Sắp xếp theo', style: text.titleSmall),
          const SizedBox(height: 10),
          AppChoiceChips<String>(
            options: const {
              'newest': 'Mới nhất',
              'oldest': 'Cũ nhất',
              'rating': 'Uy tín cao',
              'departure_date': 'Sắp khởi hành',
            },
            selected: {_sortBy},
            onChanged: (value) => setState(() => _sortBy = value),
          ),
          const SizedBox(height: 20),
          Text('Trạng thái', style: text.titleSmall),
          const SizedBox(height: 10),
          AppChoiceChips<String>(
            options: const {'OPEN': 'Đang mở', 'FULL': 'Đã đầy'},
            selected: {_status},
            onChanged: (value) => setState(() => _status = value),
          ),
          const SizedBox(height: 20),
          Text('Giới tính ưu tiên', style: text.titleSmall),
          const SizedBox(height: 10),
          AppChoiceChips<String>(
            options: const {'': 'Tất cả', 'MALE': 'Nam', 'FEMALE': 'Nữ'},
            selected: {_gender},
            onChanged: (value) => setState(() => _gender = value),
          ),
        ],
      ),
    );
  }
}
