import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';
import '../repositories/mock_trip_repository.dart';

// ================================================================================
// VIEWMODEL: Trip
// ================================================================================

class TripViewModel extends ChangeNotifier {
  final TripRepository _repo = MockTripRepository();

  List<TripModel> _trips = [];
  TripModel? _selectedTrip;
  bool _isLoading = false;
  String? _errorMessage;

  List<TripModel> get trips => _trips;
  TripModel? get selectedTrip => _selectedTrip;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Lấy danh sách chuyến đi
  Future<void> loadTrips() async {
    _isLoading = true;
    notifyListeners();

    try {
      _trips = await _repo.getMyTrips();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Lấy chi tiết chuyến đi
  Future<void> loadTripDetail(int id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedTrip = await _repo.getTripById(id);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Tạo chuyến đi mới
  Future<bool> createTrip(TripModel trip) async {
    _isLoading = true;
    notifyListeners();

    try {
      final newTrip = await _repo.createTrip(trip);
      _trips.add(newTrip);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
