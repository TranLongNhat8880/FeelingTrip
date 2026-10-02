import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'avatar_placeholder.dart';

class AppAvatarData {
  const AppAvatarData({required this.name, this.imageUrl});
  final String name;
  final String? imageUrl;
}

class AvatarGroup extends StatelessWidget {
  const AvatarGroup({
    super.key,
    required this.people,
    this.maxVisible = 4,
    this.radius = 18,
  }) : assert(maxVisible > 0),
       assert(radius > 0);
  final List<AppAvatarData> people;
  final int maxVisible;
  final double radius;
  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    final shown = people.take(maxVisible).toList();
    final extra = people.length - shown.length;
    final count = shown.length + (extra > 0 ? 1 : 0);
    return Semantics(
      label: '${people.length} thành viên',
      child: SizedBox(
        width: radius * 2 + (count - 1) * radius * 1.5,
        height: radius * 2,
        child: Stack(
          children: [
            for (var i = 0; i < count; i++)
              Positioned(
                left: i * radius * 1.5,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.fromBorderSide(
                      BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                  child: i < shown.length
                      ? AvatarPlaceholder(
                          name: shown[i].name,
                          imageUrl: shown[i].imageUrl,
                          radius: radius - 2,
                        )
                      : CircleAvatar(
                          radius: radius - 2,
                          backgroundColor: AppColors.primarySurface,
                          child: Text(
                            '+$extra',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
