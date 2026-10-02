import 'dart:ui';
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
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: AppColors.glassDark,
            borderRadius: BorderRadius.circular(36),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Always keep labels. At large text sizes, scrolling is safer than hiding destinations.
                  final largeText =
                      MediaQuery.textScalerOf(context).scale(14) > 20;
                  final tiles = <Widget>[
                    for (var index = 0; index < items.length; index++)
                      _Destination(
                        item: items[index],
                        selected: index == selectedIndex,
                        onTap: () => onSelected(index),
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
                          children: [
                            for (final tile in tiles) Expanded(child: tile),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
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
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: Material(
      color: selected ? AppColors.lime : Colors.transparent,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UnreadBadge(
                count: item.unreadCount,
                child: Icon(
                  item.icon,
                  size: 20,
                  color: selected ? AppColors.action : Colors.white70,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? AppColors.action : Colors.white70,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
