import 'package:flutter/material.dart';
import 'package:feeling_trip/core/constants/app_colors.dart';
import 'package:feeling_trip/core/constants/app_sizes.dart';

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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.sheetRadius),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        16,
        AppSizes.screenPadding,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bộ lọc', style: text.titleLarge),
              TextButton(onPressed: _reset, child: const Text('Đặt lại')),
            ],
          ),
          const SizedBox(height: 20),

          // ── Sắp xếp ───────────────────────────────────────────────────
          Text('Sắp xếp theo', style: text.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _Chip(
                label: 'Mới nhất',
                selected: _sortBy == 'newest',
                onTap: () => setState(() => _sortBy = 'newest'),
              ),
              _Chip(
                label: 'Cũ nhất',
                selected: _sortBy == 'oldest',
                onTap: () => setState(() => _sortBy = 'oldest'),
              ),
              _Chip(
                label: 'Uy tín cao',
                selected: _sortBy == 'rating',
                onTap: () => setState(() => _sortBy = 'rating'),
              ),
              _Chip(
                label: 'Sắp khởi hành',
                selected: _sortBy == 'departure_date',
                onTap: () => setState(() => _sortBy = 'departure_date'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Trạng thái ────────────────────────────────────────────────
          Text('Trạng thái', style: text.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _Chip(
                label: 'Đang mở',
                selected: _status == 'OPEN',
                onTap: () => setState(() => _status = 'OPEN'),
              ),
              _Chip(
                label: 'Đã đầy',
                selected: _status == 'FULL',
                onTap: () => setState(() => _status = 'FULL'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Giới tính ─────────────────────────────────────────────────
          Text('Giới tính ưu tiên', style: text.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _Chip(
                label: 'Tất cả',
                selected: _gender.isEmpty,
                onTap: () => setState(() => _gender = ''),
              ),
              _Chip(
                label: 'Nam',
                selected: _gender == 'MALE',
                onTap: () => setState(() => _gender = 'MALE'),
              ),
              _Chip(
                label: 'Nữ',
                selected: _gender == 'FEMALE',
                onTap: () => setState(() => _gender = 'FEMALE'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Nút áp dụng ───────────────────────────────────────────────
          SizedBox(
            height: AppSizes.buttonHeight,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                ),
              ),
              child: const Text(
                'Áp dụng bộ lọc',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: AppSizes.fontControl,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.inputSurface,
          borderRadius: BorderRadius.circular(AppSizes.radiusRound),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: AppSizes.fontBody,
          ),
        ),
      ),
    );
  }
}
