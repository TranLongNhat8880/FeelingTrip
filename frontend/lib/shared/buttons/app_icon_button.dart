import 'package:flutter/material.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.backgroundColor = Colors.white,
    this.foregroundColor,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color? foregroundColor;
  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: const Size(48, 48),
      side: const BorderSide(color: Color(0xFFDEE4EF)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
