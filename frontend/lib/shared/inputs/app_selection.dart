import '../../core/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    this.onChanged,
    this.hint = 'Tìm kiếm',
    this.isLoading = false,
    this.enabled = true,
    this.onSubmitted,
    this.onClear,
    this.borderRadius,
  });
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String hint;
  final bool isLoading;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final double? borderRadius;

  InputBorder? _border(Color color) => borderRadius == null
      ? null
      : OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius!),
          borderSide: BorderSide(color: color),
        );
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary),
            disabledBorder: _border(AppColors.divider),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    icon: const Icon(Icons.close),
                    onPressed: enabled
                        ? () {
                            controller.clear();
                            onChanged?.call('');
                            onClear?.call();
                          }
                        : null,
                  ),
          ),
        ),
      );
}

class AppSelectionField extends StatelessWidget {
  const AppSelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.errorText,
    this.enabled = true,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;
  final String? errorText;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppSizes.inputRadius),
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          errorText: errorText,
          prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        child: Text(value),
      ),
    ),
  );
}

class AppChoiceChips<T> extends StatelessWidget {
  const AppChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });
  final Map<T, String> options;
  final Set<T> selected;
  final ValueChanged<T> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final option in options.entries)
        FilterChip(
          label: Text(option.value),
          selected: selected.contains(option.key),
          onSelected: enabled ? (_) => onChanged(option.key) : null,
          labelStyle: TextStyle(
            color: selected.contains(option.key)
                ? AppColors.primary
                : AppColors.textPrimary,
          ),
        ),
    ],
  );
}

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.enabled = true,
    this.isDense = true,
  });
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool enabled;
  final bool isDense;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    isExpanded: true,
    isDense: isDense,
    items: items,
    onChanged: enabled ? onChanged : null,
    decoration: InputDecoration(labelText: label, enabled: enabled),
    icon: const Icon(Icons.keyboard_arrow_down_rounded),
  );
}

class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    this.onDeleted,
    this.icon,
  });
  final String label;
  final VoidCallback? onDeleted;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => InputChip(
    label: Text(label),
    avatar: icon == null
        ? null
        : Icon(icon, size: 16, color: AppColors.primary),
    onDeleted: onDeleted,
    deleteButtonTooltipMessage: 'Bỏ bộ lọc',
    backgroundColor: AppColors.primarySurface,
  );
}

class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);
}

class AppPickers {
  AppPickers._();
  static Future<DateTime?> date(
    BuildContext context, {
    DateTime? initial,
    required DateTime first,
    required DateTime last,
  }) {
    final start = DateUtils.dateOnly(first);
    final end = DateUtils.dateOnly(last);
    final candidate = DateUtils.dateOnly(initial ?? DateTime.now());
    return showDatePicker(
      context: context,
      initialDate: candidate.isBefore(start)
          ? start
          : candidate.isAfter(end)
          ? end
          : candidate,
      firstDate: start,
      lastDate: end,
      helpText: 'Chọn ngày',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
  }

  static Future<DateTimeRange?> dateRange(
    BuildContext context, {
    DateTimeRange? initial,
    required DateTime first,
    required DateTime last,
  }) => showDateRangePicker(
    context: context,
    initialDateRange: initial,
    firstDate: DateUtils.dateOnly(first),
    lastDate: DateUtils.dateOnly(last),
    helpText: 'Chọn khoảng ngày',
    cancelText: 'Hủy',
    saveText: 'Chọn',
  );
  static Future<TimeOfDay?> time(BuildContext context, {TimeOfDay? initial}) =>
      showTimePicker(
        context: context,
        initialTime: initial ?? TimeOfDay.now(),
        helpText: 'Chọn giờ',
        cancelText: 'Hủy',
        confirmText: 'Chọn',
      );
}
