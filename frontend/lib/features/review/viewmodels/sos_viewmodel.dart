import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/review_model.dart';
import '../models/sos_model.dart';
import '../repositories/api_review_repository.dart';
import '../repositories/review_repository.dart';
import '../repositories/sos_repository.dart';

Future<SosLocation> readSosLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const FormatException(
      'Dịch vụ vị trí đang tắt. Hãy bật vị trí hoặc gọi người thân trực tiếp.',
    );
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever ||
      permission == LocationPermission.unableToDetermine) {
    throw const FormatException(
      'Chưa được cấp quyền vị trí. Kiểm tra quyền ứng dụng/trình duyệt; bạn vẫn có thể gọi điện.',
    );
  }
  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 20),
    ),
  );
  return SosLocation(
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
    capturedAt: position.timestamp,
  );
}

class SosViewModel extends ChangeNotifier {
  SosViewModel({
    required this.tripId,
    SosRepository? repository,
    ReviewRepository? contactsRepository,
    Future<SosLocation> Function()? locate,
  }) : _repository = repository ?? ApiSosRepository(),
       _contactsRepository = contactsRepository ?? ApiReviewRepository(),
       _locate = locate ?? readSosLocation;
  final String tripId;
  final SosRepository _repository;
  final ReviewRepository _contactsRepository;
  final Future<SosLocation> Function() _locate;
  List<EmergencyContactModel> contacts = [];
  SosAlert? alert;
  SosLocation? location;
  String? error, contactsError;
  bool loading = false, locating = false, saving = false, statusLoaded = false;
  bool _disposed = false;
  bool get busy => loading || locating || saving;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_disposed || busy) return;
    loading = true;
    error = null;
    contactsError = null;
    statusLoaded = false;
    _notify();
    // Contact retrieval failure must not disable calling a number already loaded.
    await Future.wait([
      () async {
        try {
          alert = await _repository
              .getActive(tripId)
              .timeout(const Duration(seconds: 20));
          statusLoaded = true;
        } catch (_) {
          error =
              'Chưa tải được trạng thái SOS. Thử tải lại trước khi tạo để tránh ghi trùng.';
        }
      }(),
      () async {
        try {
          contacts = await _contactsRepository.getEmergencyContacts().timeout(
            const Duration(seconds: 20),
          );
        } catch (_) {
          contactsError =
              'Chưa tải được danh bạ khẩn cấp. Hãy tải lại hoặc gọi bằng điện thoại trực tiếp.';
        }
      }(),
    ]);
    loading = false;
    _notify();
  }

  Future<void> locate() async {
    if (_disposed || locating || saving) return;
    locating = true;
    location = null;
    if (statusLoaded) error = null;
    _notify();
    try {
      final result = await _locate().timeout(const Duration(seconds: 25));
      if (!result.isFresh) {
        throw const FormatException(
          'Vị trí đã cũ hoặc không hợp lệ. Hãy lấy lại vị trí.',
        );
      }
      if (!_disposed) location = result;
    } catch (e) {
      error = e is FormatException
          ? e.message
          : 'Không lấy được vị trí hiện tại. Thử lại hoặc gọi người thân trực tiếp.';
    } finally {
      locating = false;
      _notify();
    }
  }

  Future<bool> create(String message) async {
    if (_disposed || busy || !statusLoaded || alert?.isActive == true) {
      return false;
    }
    if (location?.isFresh != true) {
      error = 'Hãy lấy lại vị trí hiện tại trước khi ghi nhận SOS.';
      _notify();
      return false;
    }
    if (message.trim().length > 500) {
      error = 'Nội dung tối đa 500 ký tự.';
      _notify();
      return false;
    }
    saving = true;
    error = null;
    _notify();
    try {
      alert = await _repository
          .create(tripId: tripId, location: location!, message: message.trim())
          .timeout(const Duration(seconds: 20));
      return !_disposed;
    } catch (_) {
      // A failed acknowledgement can still mean the server saved the alert.
      statusLoaded = false;
      try {
        alert = await _repository
            .getActive(tripId)
            .timeout(const Duration(seconds: 20));
        statusLoaded = true;
        if (alert?.isActive == true) return !_disposed;
      } catch (_) {}
      error =
          'Chưa xác nhận lưu SOS. Tải lại trạng thái; bạn vẫn có thể gọi/soạn SMS cho người thân.';
      return false;
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<void> finish(String status) async {
    if (_disposed || busy || alert?.isActive != true) return;
    saving = true;
    error = null;
    _notify();
    try {
      alert = await _repository
          .finish(alert!.id, status)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      error =
          'Chưa xác nhận kết thúc SOS. Hãy tải lại trạng thái trước khi thao tác tiếp.';
      statusLoaded = false;
    } finally {
      saving = false;
      _notify();
    }
  }

  String shareText(String tripName, String message) =>
      'SOS - Tôi cần hỗ trợ! Chuyến đi: $tripName.\n${message.trim()}\n'
      '${location?.isFresh == true ? 'Vị trí lúc ${location!.capturedAt.toLocal().toIso8601String()}: ${location!.mapUrl}' : 'Chưa có vị trí hiện tại. Vui lòng liên hệ với tôi.'}';

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
