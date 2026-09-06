import '../models/trip_model.dart';

// ================================================================================
// REPOSITORY ABSTRACT: Trip
// ================================================================================
// Hợp đồng cho mọi nguồn dữ liệu Trip.
// Mỗi thành viên code feature trip chỉ cần implement các hàm này.
// ================================================================================

abstract class TripRepository {
  /// Lấy danh sách chuyến đi của user hiện tại
  Future<List<TripModel>> getMyTrips();

  /// Lấy chi tiết 1 chuyến đi
  Future<TripModel> getTripById(int id);

  /// Tạo chuyến đi mới
  Future<TripModel> createTrip(TripModel trip);

  /// Cập nhật chuyến đi
  Future<TripModel> updateTrip(int id, TripModel trip);

  /// Xóa/hủy chuyến đi
  Future<void> deleteTrip(int id);
}
