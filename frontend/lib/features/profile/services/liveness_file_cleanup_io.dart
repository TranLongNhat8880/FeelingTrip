import 'dart:io';

// Only called for files created by this screen's camera controller.
Future<void> deleteLivenessVideo(String path) async {
  try {
    await File(path).delete();
  } catch (_) {}
}
