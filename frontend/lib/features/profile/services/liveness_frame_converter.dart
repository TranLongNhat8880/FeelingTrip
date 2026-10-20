import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class ConvertedCameraFrame {
  const ConvertedCameraFrame(this.image, this.uprightSize);
  final InputImage image;
  final Size uprightSize;
}

/// Converts CameraX YUV planes (including row/pixel padding) to ML Kit NV21.
class LivenessFrameConverter {
  static ConvertedCameraFrame? convert(
    CameraImage frame,
    CameraDescription camera,
    DeviceOrientation orientation,
  ) {
    final android = defaultTargetPlatform == TargetPlatform.android;
    final degrees = switch (orientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final rotationDegrees = android
        ? (camera.lensDirection == CameraLensDirection.front
                  ? camera.sensorOrientation + degrees
                  : camera.sensorOrientation - degrees + 360) %
              360
        : camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(rotationDegrees);
    if (rotation == null || frame.width <= 0 || frame.height <= 0) return null;
    Uint8List? bytes;
    InputImageFormat format;
    var bytesPerRow = frame.width;
    if (android) {
      if (frame.width.isOdd || frame.height.isOdd) return null;
      format = InputImageFormat.nv21;
      if (frame.planes.length == 3 &&
          (frame.format.group == ImageFormatGroup.yuv420 ||
              frame.format.group == ImageFormatGroup.nv21)) {
        bytes = _yuvToNv21(frame);
      } else if (frame.planes.length == 1 &&
          frame.format.group == ImageFormatGroup.nv21) {
        final plane = frame.planes.single;
        final expected = frame.width * frame.height * 3 ~/ 2;
        if (plane.bytes.length == expected) bytes = plane.bytes;
      }
    } else {
      if (frame.format.group != ImageFormatGroup.bgra8888 ||
          frame.planes.length != 1) {
        return null;
      }
      final plane = frame.planes.single;
      if (plane.bytesPerRow < frame.width * 4 ||
          plane.bytes.length < plane.bytesPerRow * frame.height) {
        return null;
      }
      format = InputImageFormat.bgra8888;
      bytes = plane.bytes;
      bytesPerRow = plane.bytesPerRow;
    }
    if (bytes == null) return null;
    final rawSize = Size(frame.width.toDouble(), frame.height.toDouble());
    final rotated =
        android && (rotationDegrees == 90 || rotationDegrees == 270);
    return ConvertedCameraFrame(
      InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: rawSize,
          rotation: rotation,
          format: format,
          bytesPerRow: bytesPerRow,
        ),
      ),
      rotated ? Size(rawSize.height, rawSize.width) : rawSize,
    );
  }

  static Uint8List? _yuvToNv21(CameraImage image) {
    final y = image.planes[0], u = image.planes[1], v = image.planes[2];
    final width = image.width, height = image.height;
    bool fits(Plane plane, int w, int h) {
      final pixel = plane.bytesPerPixel ?? 1;
      return pixel > 0 &&
          plane.bytesPerRow >= (w - 1) * pixel + 1 &&
          (h - 1) * plane.bytesPerRow + (w - 1) * pixel < plane.bytes.length;
    }

    if (!fits(y, width, height) ||
        !fits(u, width ~/ 2, height ~/ 2) ||
        !fits(v, width ~/ 2, height ~/ 2)) {
      return null;
    }
    final output = Uint8List(width * height * 3 ~/ 2);
    var offset = 0;
    for (var row = 0; row < height; row++) {
      if ((y.bytesPerPixel ?? 1) == 1) {
        output.setRange(offset, offset + width, y.bytes, row * y.bytesPerRow);
        offset += width;
      } else {
        for (var column = 0; column < width; column++) {
          output[offset++] =
              y.bytes[row * y.bytesPerRow + column * y.bytesPerPixel!];
        }
      }
    }
    for (var row = 0; row < height ~/ 2; row++) {
      for (var column = 0; column < width ~/ 2; column++) {
        output[offset++] =
            v.bytes[row * v.bytesPerRow + column * (v.bytesPerPixel ?? 1)];
        output[offset++] =
            u.bytes[row * u.bytesPerRow + column * (u.bytesPerPixel ?? 1)];
      }
    }
    return output;
  }
}
