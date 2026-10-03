import '../../core/constants/app_sizes.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    this.url,
    this.aspectRatio = 16 / 9,
    this.radius = AppSizes.cardRadius,
    this.semanticLabel = 'Hình ảnh',
  });
  final String? url;
  final double aspectRatio;
  final double radius;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.primarySurface,
      child: const Center(
        child: Icon(
          Icons.landscape_outlined,
          color: AppColors.primary,
          size: 40,
        ),
      ),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: url == null || url!.isEmpty
              ? placeholder
              : Image.network(
                  url!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : placeholder,
                ),
        ),
      ),
    );
  }
}

/// Selection/upload are supplied by the feature, keeping shared UI platform-independent.
class ImagePickerField extends StatelessWidget {
  const ImagePickerField({
    super.key,
    required this.label,
    required this.onPick,
    this.preview,
    this.enabled = true,
  });
  final String label;
  final VoidCallback onPick;
  final Widget? preview;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (preview != null) ...[preview!, const SizedBox(height: 12)],
      OutlinedButton.icon(
        onPressed: enabled ? onPick : null,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text(label),
      ),
    ],
  );
}

class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    super.key,
    required this.name,
    this.progress,
    this.error,
    this.onRemove,
    this.onRetry,
  });
  final String name;
  final double? progress;
  final String? error;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(Icons.attach_file),
          const SizedBox(width: 8),
          Expanded(child: Text(name)),
          if (onRemove != null)
            IconButton(
              tooltip: 'Xóa tệp đã chọn',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      if (progress != null)
        LinearProgressIndicator(value: progress!.clamp(0, 1)),
      if (error != null) ...[
        Text(error!, style: const TextStyle(color: AppColors.error)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Thử tải lại')),
      ],
    ],
  );
}
