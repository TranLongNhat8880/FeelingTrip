import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../shared/gallery/ui_kit_gallery_screen.dart';
import '../features/auth/views/login_screen.dart';
import '../features/trip/views/trip_list_screen.dart';

// import '../features/auth/views/register_screen.dart';
// import '../features/trip/views/trip_detail_screen.dart';
// import '../features/trip/views/create_trip_screen.dart';
// import '../features/profile/views/profile_screen.dart';

// ================================================================================
// QUẢN LÝ ROUTES TẬP TRUNG
// ================================================================================
// Mọi tên route và mapping đều nằm ở đây.
// Khi thêm màn hình mới:
//   1. Thêm tên route static const
//   2. Thêm mapping trong Map<String, WidgetBuilder> routes
//   3. Import screen ở đầu file
// ================================================================================

class AppRoutes {
  // Tên route (dùng trong Navigator)
  static const String login = '/login';
  static const String register = '/register';
  static const String tripList = '/trips';
  static const String tripDetail = '/trips/detail';
  static const String createTrip = '/trips/create';
  static const String profile = '/profile';
  static const String uiKit = '/ui-kit';

  // Mapping route → screen
  static Map<String, WidgetBuilder> get routes => {
    login: (context) => const LoginScreen(),
    tripList: (context) => const TripListScreen(),
    if (kDebugMode) uiKit: (context) => const UiKitGalleryScreen(),
    // register: (context) => const RegisterScreen(),
    // tripList: (context) => const TripListScreen(),
    // tripDetail: (context) => const TripDetailScreen(),
    // createTrip: (context) => const CreateTripScreen(),
    // profile: (context) => const ProfileScreen(),
  };
}
