import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class AdminSearchToolbar extends StatelessWidget {
  const AdminSearchToolbar({
    super.key,
    required this.searching,
    required this.controller,
    required this.hint,
    required this.filter,
    required this.onOpen,
    required this.onClose,
    required this.onSubmit,
  });

  final bool searching;
  final TextEditingController controller;
  final String hint;
  final Widget filter;
  final VoidCallback onOpen, onClose, onSubmit;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: Row(
      children: searching
          ? [
              Expanded(
                child: TextField(
                  autofocus: true,
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        controller.clear();
                        onSubmit();
                      },
                    ),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              TextButton(onPressed: onClose, child: const Text('Hủy')),
            ]
          : [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: filter),
              ),
              IconButton(
                tooltip: 'Tìm kiếm',
                onPressed: onOpen,
                icon: const Icon(Icons.search, color: AppColors.textPrimary),
              ),
            ],
    ),
  );
}
