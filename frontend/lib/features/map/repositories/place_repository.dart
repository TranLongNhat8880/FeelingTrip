import '../models/place_distance_model.dart';
import '../models/place_form_data.dart';
import '../models/place_model.dart';

// ============================================================================
// REPOSITORY CONTRACT: Places
//
// ViewModel chỉ phụ thuộc interface này, không phụ thuộc trực tiếp API.
// Sau này có thể thay ApiPlaceRepository bằng MockPlaceRepository mà
// không cần sửa giao diện.
// ============================================================================

abstract class PlaceRepository {
  /// Tìm kiếm, lọc và phân trang kho địa điểm công khai.
  Future<PlacePage> searchPlaces({
    String? keyword,
    String? destination,
    String? category,
    int? priceLevel,
    String sortBy = 'newest',
    int page = 1,
    int limit = 20,
  });

  /// Lấy chi tiết một địa điểm đang hoạt động.
  Future<PlaceModel> getPlaceById(String placeId);

  /// Tính khoảng cách và thời gian ước lượng giữa hai tọa độ.
  Future<PlaceDistanceResult> calculateDistance({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    String travelMode = 'driving',
  });

  /// Admin xem toàn bộ kho địa điểm, gồm cả địa điểm đã ẩn.
  Future<PlacePage> getManagePlaces({
    String? keyword,
    String? destination,
    String? category,
    int? priceLevel,
    bool? isActive,
    String sortBy = 'newest',
    int page = 1,
    int limit = 20,
  });

  /// Admin ẩn hoặc khôi phục một địa điểm.
  Future<PlaceModel> updatePlaceStatus({
    required String placeId,
    required bool isActive,
  });

  /// Admin thêm địa điểm mới bằng multipart/form-data.
  Future<PlaceModel> createPlace({
    required PlaceFormData data,
    List<int>? imageBytes,
    String? imageFileName,
  });

  /// Admin cập nhật thông tin và/hoặc ảnh địa điểm.
  Future<PlaceModel> updatePlace({
    required String placeId,
    required PlaceFormData data,
    List<int>? imageBytes,
    String? imageFileName,
  });
}
