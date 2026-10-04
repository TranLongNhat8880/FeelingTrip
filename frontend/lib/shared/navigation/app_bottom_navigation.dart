import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../widgets/app_status_badge.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.icon,
    this.unreadCount = 0,
  });
  final String label;
  final IconData icon;
  final int unreadCount;
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(items.length >= 2),
       assert(selectedIndex >= 0 && selectedIndex < items.length);
  final List<AppNavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(12) > 18;
          final tiles = [
            for (var i = 0; i < items.length; i++)
              _Destination(
                item: items[i],
                selected: i == selectedIndex,
                onTap: () => onSelected(i),
              ),
          ];
          return largeText || constraints.maxWidth < items.length * 64
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final tile in tiles)
                        SizedBox(width: 110, child: tile),
                    ],
                  ),
                )
              : Row(
                  children: [for (final tile in tiles) Expanded(child: tile)],
                );
        },
      ),
    ),
  );
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final AppNavigationItem item;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UnreadBadge(
                  count: item.unreadCount,
                  child: Icon(item.icon, size: 22, color: color),
                ),
                const SizedBox(height: 5),
                Text(
                  item.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
